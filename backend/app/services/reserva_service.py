from datetime import date, datetime, time, timedelta
from typing import Callable
from fastapi import HTTPException, status
from app.repositories.reserva_repository import ReservaRepository
from app.schemas.reserva_schema import (
    ReservaCreate,
    ReservaEstadoUpdate,
    ReservaReprogramar,
)

TRANSICIONES_ESTADO = {
    "pendiente": {"confirmada", "cancelada"},
    "confirmada": {"atendida", "no_asistio", "cancelada"},
    "cancelada": set(),
    "atendida": set(),
    "no_asistio": set(),
}


class ReservaService:
    def __init__(
        self,
        repo: ReservaRepository | None = None,
        ahora_fn: Callable[[], datetime] = datetime.now,
    ):
        self.repo = repo or ReservaRepository()
        self._ahora = ahora_fn

    # ======================== HELPERS INTERNOS ========================
    def _obtener_plazo_minimo_horas(self) -> float:
        valor = self.repo.obtener_configuracion("plazo_minimo_cancelacion_horas")
        try:
            return float(valor) if valor is not None else 2.0
        except ValueError:
            return 2.0

    def _validar_plazo_anticipacion_cliente(
        self, reserva: dict, accion: str
    ) -> None:
        inicio_reserva = datetime.combine(
            reserva["fecha_reserva"], reserva["hora_inicio"]
        )
        plazo_horas = self._obtener_plazo_minimo_horas()
        horas_restantes = (inicio_reserva - self._ahora()).total_seconds() / 3600

        if horas_restantes < plazo_horas:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"No es posible {accion} la reserva con menos de "
                    f"{plazo_horas:g} horas de anticipación."
                ),
            )

    def _validar_datos_horario_y_calcular(
        self,
        id_cancha: int,
        id_servicio: int,
        fecha_reserva: date,
        hora_inicio: time,
        hora_fin_solicitada: time | None,
        excluir_id_reserva: int | None = None,
    ) -> tuple[time, float]:
        cancha = self.repo.obtener_cancha(id_cancha)
        if not cancha:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró la cancha con ID {id_cancha}.",
            )
        if cancha["estado"] != "disponible":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"La cancha '{cancha['nombre']}' no está disponible (estado: {cancha['estado']}).",
            )

        servicio = self.repo.obtener_servicio(id_servicio)
        if not servicio:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el servicio con ID {id_servicio}.",
            )
        if not servicio["activo"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El servicio '{servicio['nombre']}' se encuentra inactivo.",
            )

        inicio_dt = datetime.combine(fecha_reserva, hora_inicio)
        if inicio_dt < self._ahora():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pueden registrar reservas en fechas u horas pasadas.",
            )

        if hora_fin_solicitada is not None:
            fin_dt = datetime.combine(fecha_reserva, hora_fin_solicitada)
            hora_fin = hora_fin_solicitada
        else:
            fin_dt = inicio_dt + timedelta(minutes=int(servicio["duracion_minutos"]))
            if fin_dt.date() != fecha_reserva:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="La reserva excede el límite de medianoche.",
                )
            hora_fin = fin_dt.time()

        dia_semana = fecha_reserva.isoweekday()
        horario = self.repo.obtener_horario_cancha_dia(id_cancha, dia_semana)
        if not horario or not horario["activo"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cancha no tiene horario de atención activo para ese día.",
            )

        if hora_inicio < horario["hora_apertura"] or hora_fin > horario["hora_cierre"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"El horario solicitado está fuera de atención "
                    f"({horario['hora_apertura'].strftime('%H:%M')} a "
                    f"{horario['hora_cierre'].strftime('%H:%M')})."
                ),
            )

        if self.repo.existe_choque_horario(
            id_cancha=id_cancha,
            fecha_reserva=fecha_reserva,
            hora_inicio=hora_inicio,
            hora_fin=hora_fin,
            excluir_id_reserva=excluir_id_reserva,
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Choque de horario: la cancha ya tiene una reserva activa en ese rango.",
            )

        duracion_horas = (fin_dt - inicio_dt).total_seconds() / 3600
        monto_total = round(
            float(cancha["precio_hora"]) * duracion_horas
            + float(servicio["precio_adicional"]),
            2,
        )
        return hora_fin, monto_total

    # ======================== DISPONIBILIDAD ========================
    def consultar_disponibilidad(self, id_cancha: int, fecha_reserva: date) -> dict:
        cancha = self.repo.obtener_cancha(id_cancha)
        if not cancha:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró la cancha con ID {id_cancha}.",
            )

        dia_semana = fecha_reserva.isoweekday()
        horario = self.repo.obtener_horario_cancha_dia(id_cancha, dia_semana)

        if cancha["estado"] != "disponible" or not horario or not horario["activo"]:
            return {
                "id_cancha": cancha["id_cancha"],
                "cancha_nombre": cancha["nombre"],
                "estado_cancha": cancha["estado"],
                "fecha_reserva": fecha_reserva,
                "dia_semana": dia_semana,
                "disponible": False,
                "horario_atencion": None,
                "bloques_ocupados": [],
                "bloques_disponibles": [],
            }

        ocupados = self.repo.listar_bloques_ocupados(id_cancha, fecha_reserva)
        disponibles = []
        cursor = horario["hora_apertura"]

        for bloque in ocupados:
            if bloque["hora_inicio"] > cursor:
                disponibles.append(
                    {"hora_inicio": cursor, "hora_fin": bloque["hora_inicio"]}
                )
            if bloque["hora_fin"] > cursor:
                cursor = bloque["hora_fin"]

        if cursor < horario["hora_cierre"]:
            disponibles.append(
                {"hora_inicio": cursor, "hora_fin": horario["hora_cierre"]}
            )

        return {
            "id_cancha": cancha["id_cancha"],
            "cancha_nombre": cancha["nombre"],
            "estado_cancha": cancha["estado"],
            "fecha_reserva": fecha_reserva,
            "dia_semana": dia_semana,
            "disponible": len(disponibles) > 0,
            "horario_atencion": {
                "hora_apertura": horario["hora_apertura"],
                "hora_cierre": horario["hora_cierre"],
            },
            "bloques_ocupados": ocupados,
            "bloques_disponibles": disponibles,
        }

    # ======================== GESTIÓN DE RESERVAS ========================
    def listar_reservas(
        self,
        usuario_actual: dict,
        fecha_desde: date | None = None,
        fecha_hasta: date | None = None,
        id_cancha: int | None = None,
        estado: str | None = None,
        id_cliente: int | None = None,
    ) -> list[dict]:
        filtro_cliente = id_cliente
        if usuario_actual["rol"] == "cliente":
            cliente = self.repo.obtener_cliente_por_usuario(
                usuario_actual["id_usuario"]
            )
            if not cliente:
                return []
            filtro_cliente = cliente["id_cliente"]

        return self.repo.listar_reservas(
            fecha_desde=fecha_desde,
            fecha_hasta=fecha_hasta,
            id_cancha=id_cancha,
            estado=estado,
            id_cliente=filtro_cliente,
        )

    def obtener_reserva(self, id_reserva: int, usuario_actual: dict) -> dict:
        reserva = self.repo.obtener_reserva_por_id(id_reserva)
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
                    detail="No tienes permiso para acceder a esta reserva.",
                )

        return reserva

    def crear_reserva(self, datos: ReservaCreate, usuario_actual: dict) -> dict:
        id_empleado = None

        if usuario_actual["rol"] == "cliente":
            cliente = self.repo.obtener_cliente_por_usuario(
                usuario_actual["id_usuario"]
            )
            if not cliente or not cliente["activo"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No se encontró un perfil de cliente activo para tu usuario.",
                )
            id_cliente = cliente["id_cliente"]
        else:
            if not datos.id_cliente:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Debes indicar el id_cliente al registrar una reserva desde recepción.",
                )
            cliente = self.repo.obtener_cliente_por_id(datos.id_cliente)
            if not cliente or not cliente["activo"]:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"No se encontró un cliente activo con ID {datos.id_cliente}.",
                )
            id_cliente = cliente["id_cliente"]
            empleado = self.repo.obtener_empleado_por_usuario(
                usuario_actual["id_usuario"]
            )
            if empleado:
                id_empleado = empleado["id_empleado"]

        hora_fin, monto_total = self._validar_datos_horario_y_calcular(
            id_cancha=datos.id_cancha,
            id_servicio=datos.id_servicio,
            fecha_reserva=datos.fecha_reserva,
            hora_inicio=datos.hora_inicio,
            hora_fin_solicitada=datos.hora_fin,
        )

        anio = datos.fecha_reserva.year
        correlativo = self.repo.obtener_siguiente_correlativo(anio)
        codigo_reserva = f"RES-{anio}-{correlativo:04d}"

        return self.repo.crear_reserva(
            {
                "codigo_reserva": codigo_reserva,
                "id_cliente": id_cliente,
                "id_cancha": datos.id_cancha,
                "id_servicio": datos.id_servicio,
                "id_empleado": id_empleado,
                "fecha_reserva": datos.fecha_reserva,
                "hora_inicio": datos.hora_inicio,
                "hora_fin": hora_fin,
                "monto_total": monto_total,
                "observaciones": datos.observaciones,
                "creado_por": usuario_actual["id_usuario"],
            }
        )

    def reprogramar_reserva(
        self, id_reserva: int, datos: ReservaReprogramar, usuario_actual: dict
    ) -> dict:
        reserva = self.obtener_reserva(id_reserva, usuario_actual)

        if reserva["estado"] not in ("pendiente", "confirmada"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"No se puede reprogramar una reserva en estado '{reserva['estado']}'.",
            )

        if usuario_actual["rol"] == "cliente":
            self._validar_plazo_anticipacion_cliente(reserva, "reprogramar")

        hora_fin, monto_total = self._validar_datos_horario_y_calcular(
            id_cancha=datos.id_cancha,
            id_servicio=datos.id_servicio,
            fecha_reserva=datos.fecha_reserva,
            hora_inicio=datos.hora_inicio,
            hora_fin_solicitada=datos.hora_fin,
            excluir_id_reserva=id_reserva,
        )

        return self.repo.reprogramar_reserva(
            id_reserva,
            {
                "id_cancha": datos.id_cancha,
                "id_servicio": datos.id_servicio,
                "fecha_reserva": datos.fecha_reserva,
                "hora_inicio": datos.hora_inicio,
                "hora_fin": hora_fin,
                "monto_total": monto_total,
                "observaciones": (
                    datos.observaciones
                    if datos.observaciones is not None
                    else reserva["observaciones"]
                ),
                "modificado_por": usuario_actual["id_usuario"],
            },
        )

    def cambiar_estado_reserva(
        self, id_reserva: int, datos: ReservaEstadoUpdate, usuario_actual: dict
    ) -> dict:
        reserva = self.obtener_reserva(id_reserva, usuario_actual)
        estado_actual = reserva["estado"]
        nuevo_estado = datos.estado

        if usuario_actual["rol"] == "cliente":
            if nuevo_estado != "cancelada":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Como cliente solo puedes cancelar tus propias reservas.",
                )
            self._validar_plazo_anticipacion_cliente(reserva, "cancelar")

        if nuevo_estado not in TRANSICIONES_ESTADO.get(estado_actual, set()):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Transición no permitida: no se puede pasar de "
                    f"'{estado_actual}' a '{nuevo_estado}'."
                ),
            )

        motivo = datos.motivo_cancelacion.strip() if datos.motivo_cancelacion else None
        if nuevo_estado == "cancelada" and (not motivo or len(motivo) < 3):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Debes indicar un motivo de cancelación (mínimo 3 caracteres).",
            )

        return self.repo.actualizar_estado(
            id_reserva=id_reserva,
            nuevo_estado=nuevo_estado,
            motivo_cancelacion=motivo if nuevo_estado == "cancelada" else None,
            modificado_por=usuario_actual["id_usuario"],
        )