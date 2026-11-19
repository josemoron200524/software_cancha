from datetime import date
from fastapi import HTTPException, status
from app.repositories.finanzas_repository import FinanzasRepository
from app.schemas.finanzas_schema import ConfiguracionUpdate, PagoCreate


class FinanzasService:
    def __init__(self, repo: FinanzasRepository | None = None):
        self.repo = repo or FinanzasRepository()

    # ======================== HELPERS ========================
    def _validar_rango_fechas(
        self, fecha_desde: date | None, fecha_hasta: date | None
    ) -> None:
        if fecha_desde and fecha_hasta and fecha_desde > fecha_hasta:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La fecha_desde no puede ser posterior a fecha_hasta.",
            )

    def _obtener_porcentaje_anticipo_minimo(self) -> float:
        config = self.repo.obtener_configuracion("porcentaje_anticipo_minimo")
        if not config:
            return 50.0
        try:
            return float(config["valor"])
        except ValueError:
            return 50.0

    # ======================== PAGOS ========================
    def listar_pagos(
        self,
        fecha_desde: date | None = None,
        fecha_hasta: date | None = None,
        metodo_pago: str | None = None,
    ) -> list[dict]:
        self._validar_rango_fechas(fecha_desde, fecha_hasta)
        return self.repo.listar_pagos(
            fecha_desde=fecha_desde,
            fecha_hasta=fecha_hasta,
            metodo_pago=metodo_pago,
        )

    def listar_pagos_por_reserva(
        self, id_reserva: int, usuario_actual: dict
    ) -> dict:
        reserva = self.repo.obtener_reserva(id_reserva)
        if not reserva:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró la reserva con ID {id_reserva}.",
            )

        if usuario_actual["rol"] == "cliente":
            cliente = self.repo.obtener_cliente_por_usuario(
                usuario_actual["id_usuario"]
            )
            if not cliente or reserva["id_cliente"] != cliente["id_cliente"]:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="No tienes permiso para ver los pagos de esta reserva.",
                )

        pagos = self.repo.listar_pagos_por_reserva(id_reserva)
        monto_total = float(reserva["monto_total"])
        total_pagado = round(sum(float(p["monto"]) for p in pagos), 2)
        saldo_pendiente = round(max(monto_total - total_pagado, 0.0), 2)

        return {
            "id_reserva": reserva["id_reserva"],
            "codigo_reserva": reserva["codigo_reserva"],
            "estado_reserva": reserva["estado"],
            "monto_total": monto_total,
            "total_pagado": total_pagado,
            "saldo_pendiente": saldo_pendiente,
            "pagos": pagos,
        }

    def registrar_pago(self, datos: PagoCreate, usuario_actual: dict) -> dict:
        reserva = self.repo.obtener_reserva(datos.id_reserva)
        if not reserva:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró la reserva con ID {datos.id_reserva}.",
            )

        if reserva["estado"] in ("cancelada", "no_asistio"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No se pueden registrar pagos para una reserva en estado '{reserva['estado']}'.",
            )

        monto_total = float(reserva["monto_total"])
        total_pagado_previo = self.repo.obtener_total_pagado_reserva(datos.id_reserva)
        saldo_pendiente_previo = round(monto_total - total_pagado_previo, 2)

        if saldo_pendiente_previo <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La reserva ya se encuentra pagada en su totalidad.",
            )

        monto_pago = round(datos.monto, 2)
        if monto_pago > saldo_pendiente_previo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El monto ({monto_pago:.2f}) excede el saldo pendiente ({saldo_pendiente_previo:.2f}).",
            )

        if datos.tipo_pago == "total" and monto_pago < saldo_pendiente_previo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Para un pago de tipo 'total' debes cubrir el saldo completo "
                    f"({saldo_pendiente_previo:.2f})."
                ),
            )

        nuevo_total_pagado = round(total_pagado_previo + monto_pago, 2)
        porcentaje_minimo = self._obtener_porcentaje_anticipo_minimo()
        minimo_para_confirmar = round(monto_total * (porcentaje_minimo / 100.0), 2)
        confirmar_automaticamente = (
            reserva["estado"] == "pendiente"
            and nuevo_total_pagado >= minimo_para_confirmar
        )

        referencia = (
            datos.referencia_comprobante.strip()
            if datos.referencia_comprobante
            else None
        )
        pago_registrado = self.repo.registrar_pago(
            {
                "id_reserva": datos.id_reserva,
                "monto": monto_pago,
                "tipo_pago": datos.tipo_pago,
                "metodo_pago": datos.metodo_pago,
                "referencia_comprobante": referencia,
                "registrado_por": usuario_actual["id_usuario"],
            },
            confirmar_reserva=confirmar_automaticamente,
        )

        nuevo_saldo = round(max(monto_total - nuevo_total_pagado, 0.0), 2)
        estado_final = (
            "confirmada" if confirmar_automaticamente else reserva["estado"]
        )

        return {
            "pago": pago_registrado,
            "resumen_financiero": {
                "codigo_reserva": reserva["codigo_reserva"],
                "monto_total": monto_total,
                "total_pagado": nuevo_total_pagado,
                "saldo_pendiente": nuevo_saldo,
                "reserva_confirmada_automaticamente": confirmar_automaticamente,
                "estado_reserva_actual": estado_final,
            },
        }

    # ======================== CONFIGURACIÓN DE NEGOCIO ========================
    def listar_configuraciones(self) -> list[dict]:
        return self.repo.listar_configuraciones()

    def actualizar_configuracion(
        self, clave: str, datos: ConfiguracionUpdate, usuario_actual: dict
    ) -> dict:
        clave_limpia = clave.strip()
        existente = self.repo.obtener_configuracion(clave_limpia)
        if not existente:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el parámetro de configuración '{clave_limpia}'.",
            )

        valor_limpio = datos.valor.strip()
        if clave_limpia == "plazo_minimo_cancelacion_horas":
            try:
                horas = float(valor_limpio)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="El plazo mínimo de cancelación debe ser un número válido.",
                )
            if horas < 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="El plazo mínimo de cancelación no puede ser negativo.",
                )

        if clave_limpia == "porcentaje_anticipo_minimo":
            try:
                porcentaje = float(valor_limpio)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="El porcentaje de anticipo mínimo debe ser un número válido.",
                )
            if porcentaje < 0 or porcentaje > 100:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="El porcentaje de anticipo mínimo debe estar entre 0 y 100.",
                )

        descripcion = (
            datos.descripcion.strip() if datos.descripcion is not None else None
        )
        return self.repo.actualizar_configuracion(
            clave=clave_limpia,
            valor=valor_limpio,
            descripcion=descripcion,
            modificado_por=usuario_actual["id_usuario"],
        )

    # ======================== REPORTES Y KPIs ========================
    def obtener_reporte_resumen(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> dict:
        self._validar_rango_fechas(fecha_desde, fecha_hasta)

        resumen = self.repo.obtener_resumen_reservas(fecha_desde, fecha_hasta)
        ingresos_metodo = self.repo.obtener_ingresos_por_metodo(
            fecha_desde, fecha_hasta
        )

        total_reservas = int(resumen["total_reservas"])
        canceladas = int(resumen["canceladas"])
        atendidas = int(resumen["atendidas"])
        no_asistio = int(resumen["no_asistio"])

        tasa_cancelacion = (
            round((canceladas / total_reservas) * 100, 2)
            if total_reservas > 0
            else 0.0
        )
        cerradas_asistencia = atendidas + no_asistio
        tasa_asistencia = (
            round((atendidas / cerradas_asistencia) * 100, 2)
            if cerradas_asistencia > 0
            else 0.0
        )
        total_recaudado = round(
            sum(float(item["total_recaudado"]) for item in ingresos_metodo), 2
        )

        return {
            "periodo": {"fecha_desde": fecha_desde, "fecha_hasta": fecha_hasta},
            "reservas": {
                "total": total_reservas,
                "pendientes": int(resumen["pendientes"]),
                "confirmadas": int(resumen["confirmadas"]),
                "atendidas": atendidas,
                "canceladas": canceladas,
                "no_asistio": no_asistio,
            },
            "kpis": {
                "tasa_cancelacion_porcentaje": tasa_cancelacion,
                "tasa_asistencia_porcentaje": tasa_asistencia,
                "monto_proyectado_reservas": round(
                    float(resumen["monto_proyectado"]), 2
                ),
                "total_recaudado_pagos": total_recaudado,
            },
            "ingresos_por_metodo": ingresos_metodo,
        }

    def obtener_reporte_canchas(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> list[dict]:
        self._validar_rango_fechas(fecha_desde, fecha_hasta)
        return self.repo.obtener_reporte_por_cancha(fecha_desde, fecha_hasta)

    def obtener_reporte_servicios(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> list[dict]:
        self._validar_rango_fechas(fecha_desde, fecha_hasta)
        return self.repo.obtener_reporte_por_servicio(fecha_desde, fecha_hasta)