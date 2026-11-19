from datetime import date
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from app.schemas.finanzas_schema import ConfiguracionUpdate, PagoCreate
from app.services.finanzas_service import FinanzasService


class FakeFinanzasRepository:
    def __init__(self):
        self.clientes = {
            3: {"id_cliente": 1},
            4: {"id_cliente": 2},
        }
        self.reservas = {
            1: {
                "id_reserva": 1,
                "codigo_reserva": "RES-2026-0001",
                "id_cliente": 1,
                "estado": "pendiente",
                "monto_total": 150.0,
            },
            2: {
                "id_reserva": 2,
                "codigo_reserva": "RES-2026-0002",
                "id_cliente": 2,
                "estado": "pendiente",
                "monto_total": 120.0,
            },
            3: {
                "id_reserva": 3,
                "codigo_reserva": "RES-2026-0003",
                "id_cliente": 1,
                "estado": "cancelada",
                "monto_total": 120.0,
            },
        }
        self.pagos: list[dict] = []
        self.next_pago_id = 1
        self.configuraciones = {
            "plazo_minimo_cancelacion_horas": {
                "id_config": 1,
                "clave": "plazo_minimo_cancelacion_horas",
                "valor": "2",
                "descripcion": "Horas mínimas para cancelar",
                "modificado_por": 1,
            },
            "porcentaje_anticipo_minimo": {
                "id_config": 2,
                "clave": "porcentaje_anticipo_minimo",
                "valor": "50",
                "descripcion": "Porcentaje mínimo de anticipo",
                "modificado_por": 1,
            },
        }
        self.resumen_vacio = False

    def obtener_reserva(self, id_reserva: int):
        return self.reservas.get(id_reserva)

    def obtener_cliente_por_usuario(self, id_usuario: int):
        return self.clientes.get(id_usuario)

    def listar_pagos(self, fecha_desde=None, fecha_hasta=None, metodo_pago=None):
        resultado = list(self.pagos)
        if metodo_pago:
            resultado = [p for p in resultado if p["metodo_pago"] == metodo_pago]
        return resultado

    def listar_pagos_por_reserva(self, id_reserva: int):
        return [p for p in self.pagos if p["id_reserva"] == id_reserva]

    def obtener_total_pagado_reserva(self, id_reserva: int) -> float:
        return round(
            sum(p["monto"] for p in self.pagos if p["id_reserva"] == id_reserva), 2
        )

    def registrar_pago(self, datos: dict, confirmar_reserva: bool = False):
        pago = {"id_pago": self.next_pago_id, **datos}
        self.next_pago_id += 1
        self.pagos.append(pago)
        if confirmar_reserva and self.reservas[datos["id_reserva"]]["estado"] == "pendiente":
            self.reservas[datos["id_reserva"]]["estado"] = "confirmada"
        return pago

    def listar_configuraciones(self):
        return list(self.configuraciones.values())

    def obtener_configuracion(self, clave: str):
        return self.configuraciones.get(clave)

    def actualizar_configuracion(
        self, clave: str, valor: str, descripcion: str | None, modificado_por: int
    ):
        self.configuraciones[clave]["valor"] = valor
        if descripcion is not None:
            self.configuraciones[clave]["descripcion"] = descripcion
        self.configuraciones[clave]["modificado_por"] = modificado_por
        return self.configuraciones[clave]

    def obtener_resumen_reservas(self, fecha_desde=None, fecha_hasta=None):
        if self.resumen_vacio:
            return {
                "total_reservas": 0,
                "pendientes": 0,
                "confirmadas": 0,
                "atendidas": 0,
                "canceladas": 0,
                "no_asistio": 0,
                "monto_proyectado": 0.0,
            }
        return {
            "total_reservas": 10,
            "pendientes": 2,
            "confirmadas": 2,
            "atendidas": 3,
            "canceladas": 2,
            "no_asistio": 1,
            "monto_proyectado": 950.0,
        }

    def obtener_ingresos_por_metodo(self, fecha_desde=None, fecha_hasta=None):
        if self.resumen_vacio:
            return []
        return [
            {"metodo_pago": "qr", "cantidad_pagos": 4, "total_recaudado": 420.0},
            {"metodo_pago": "efectivo", "cantidad_pagos": 2, "total_recaudado": 180.0},
        ]

    def obtener_reporte_por_cancha(self, fecha_desde=None, fecha_hasta=None):
        return [
            {
                "id_cancha": 1,
                "cancha_nombre": "Cancha 1 - Fútbol 5",
                "estado": "disponible",
                "total_reservas": 6,
                "atendidas": 3,
                "canceladas": 1,
                "monto_proyectado": 600.0,
            }
        ]

    def obtener_reporte_por_servicio(self, fecha_desde=None, fecha_hasta=None):
        return [
            {
                "id_servicio": 1,
                "servicio_nombre": "Alquiler Diurno (1 hora)",
                "activo": True,
                "total_reservas": 5,
                "atendidas": 2,
                "canceladas": 1,
                "monto_proyectado": 500.0,
            }
        ]


USUARIO_ADMIN = {"id_usuario": 1, "rol": "administrador"}
USUARIO_RECEP = {"id_usuario": 2, "rol": "recepcionista"}
USUARIO_CLIENTE = {"id_usuario": 3, "rol": "cliente"}
USUARIO_OTRO_CLIENTE = {"id_usuario": 4, "rol": "cliente"}


# ===================== PAGOS Y CONFIRMACIÓN AUTOMÁTICA =====================
def test_registrar_pagos_y_confirmacion_automatica_por_anticipo():
    repo = FakeFinanzasRepository()
    servicio = FinanzasService(repo=repo)

    # 1) Anticipo menor al 50% (30 de 150) -> sigue pendiente
    r1 = servicio.registrar_pago(
        PagoCreate(
            id_reserva=1,
            monto=30.0,
            tipo_pago="anticipo",
            metodo_pago="efectivo",
        ),
        USUARIO_RECEP,
    )
    assert r1["resumen_financiero"]["reserva_confirmada_automaticamente"] is False
    assert r1["resumen_financiero"]["estado_reserva_actual"] == "pendiente"
    assert r1["resumen_financiero"]["saldo_pendiente"] == 120.0

    # 2) Segundo anticipo completa 75 de 150 (50%) -> confirma automáticamente
    r2 = servicio.registrar_pago(
        PagoCreate(
            id_reserva=1,
            monto=45.0,
            tipo_pago="anticipo",
            metodo_pago="qr",
            referencia_comprobante="  QR-1001  ",
        ),
        USUARIO_RECEP,
    )
    assert r2["pago"]["referencia_comprobante"] == "QR-1001"
    assert r2["resumen_financiero"]["reserva_confirmada_automaticamente"] is True
    assert r2["resumen_financiero"]["estado_reserva_actual"] == "confirmada"
    assert r2["resumen_financiero"]["saldo_pendiente"] == 75.0

    # 3) Pago del saldo restante -> saldo en 0
    r3 = servicio.registrar_pago(
        PagoCreate(
            id_reserva=1,
            monto=75.0,
            tipo_pago="saldo",
            metodo_pago="transferencia",
        ),
        USUARIO_RECEP,
    )
    assert r3["resumen_financiero"]["saldo_pendiente"] == 0.0
    assert r3["resumen_financiero"]["reserva_confirmada_automaticamente"] is False

    # 4) Intentar pagar de nuevo una reserva saldada -> 400
    with pytest.raises(HTTPException) as exc:
        servicio.registrar_pago(
            PagoCreate(id_reserva=1, monto=10.0, tipo_pago="saldo", metodo_pago="efectivo"),
            USUARIO_RECEP,
        )
    assert exc.value.status_code == 400


def test_registrar_pago_total_validaciones_y_fallback_porcentaje():
    repo = FakeFinanzasRepository()
    servicio = FinanzasService(repo=repo)

    # Reserva inexistente -> 404
    with pytest.raises(HTTPException) as e404:
        servicio.registrar_pago(
            PagoCreate(id_reserva=999, monto=50.0, tipo_pago="anticipo", metodo_pago="qr"),
            USUARIO_RECEP,
        )
    assert e404.value.status_code == 404

    # Reserva cancelada -> 400
    with pytest.raises(HTTPException) as e_canc:
        servicio.registrar_pago(
            PagoCreate(id_reserva=3, monto=50.0, tipo_pago="anticipo", metodo_pago="qr"),
            USUARIO_RECEP,
        )
    assert e_canc.value.status_code == 400

    # Monto excede saldo pendiente -> 400
    with pytest.raises(HTTPException) as e_exc:
        servicio.registrar_pago(
            PagoCreate(id_reserva=2, monto=200.0, tipo_pago="total", metodo_pago="qr"),
            USUARIO_RECEP,
        )
    assert e_exc.value.status_code == 400

    # Tipo 'total' menor al saldo pendiente -> 400
    with pytest.raises(HTTPException) as e_tot:
        servicio.registrar_pago(
            PagoCreate(id_reserva=2, monto=60.0, tipo_pago="total", metodo_pago="qr"),
            USUARIO_RECEP,
        )
    assert e_tot.value.status_code == 400

    # Fallback cuando porcentaje no existe o es texto inválido
    repo.configuraciones["porcentaje_anticipo_minimo"]["valor"] = "invalido"
    assert servicio._obtener_porcentaje_anticipo_minimo() == 50.0
    del repo.configuraciones["porcentaje_anticipo_minimo"]
    assert servicio._obtener_porcentaje_anticipo_minimo() == 50.0

    # Pago total exacto -> confirma y deja saldo en 0
    resp = servicio.registrar_pago(
        PagoCreate(id_reserva=2, monto=120.0, tipo_pago="total", metodo_pago="tarjeta"),
        USUARIO_RECEP,
    )
    assert resp["resumen_financiero"]["saldo_pendiente"] == 0.0
    assert resp["resumen_financiero"]["estado_reserva_actual"] == "confirmada"


def test_listar_pagos_y_control_acceso_por_reserva():
    repo = FakeFinanzasRepository()
    servicio = FinanzasService(repo=repo)
    servicio.registrar_pago(
        PagoCreate(id_reserva=1, monto=75.0, tipo_pago="anticipo", metodo_pago="qr"),
        USUARIO_RECEP,
    )

    assert len(servicio.listar_pagos(metodo_pago="qr")) == 1
    assert len(servicio.listar_pagos(metodo_pago="efectivo")) == 0

    with pytest.raises(HTTPException) as exc_fechas:
        servicio.listar_pagos(fecha_desde=date(2026, 11, 25), fecha_hasta=date(2026, 11, 20))
    assert exc_fechas.value.status_code == 400

    # Cliente dueño ve sus pagos; otro cliente recibe 403; inexistente 404
    resumen_cliente = servicio.listar_pagos_por_reserva(1, USUARIO_CLIENTE)
    assert resumen_cliente["total_pagado"] == 75.0
    assert resumen_cliente["saldo_pendiente"] == 75.0

    resumen_admin = servicio.listar_pagos_por_reserva(1, USUARIO_ADMIN)
    assert len(resumen_admin["pagos"]) == 1

    with pytest.raises(HTTPException) as exc_403:
        servicio.listar_pagos_por_reserva(1, USUARIO_OTRO_CLIENTE)
    assert exc_403.value.status_code == 403

    with pytest.raises(HTTPException) as exc_404:
        servicio.listar_pagos_por_reserva(999, USUARIO_ADMIN)
    assert exc_404.value.status_code == 404


# ===================== CONFIGURACIÓN DE NEGOCIO =====================
def test_configuracion_listar_actualizar_y_validaciones():
    servicio = FinanzasService(repo=FakeFinanzasRepository())
    assert len(servicio.listar_configuraciones()) == 2

    # Clave inexistente -> 404
    with pytest.raises(HTTPException) as e404:
        servicio.actualizar_configuracion(
            "clave_desconocida", ConfiguracionUpdate(valor="10"), USUARIO_ADMIN
        )
    assert e404.value.status_code == 404

    # Plazo de cancelación inválido (texto y negativo)
    with pytest.raises(HTTPException) as e_plazo_txt:
        servicio.actualizar_configuracion(
            "plazo_minimo_cancelacion_horas", ConfiguracionUpdate(valor="abc"), USUARIO_ADMIN
        )
    assert e_plazo_txt.value.status_code == 400

    with pytest.raises(HTTPException) as e_plazo_neg:
        servicio.actualizar_configuracion(
            "plazo_minimo_cancelacion_horas", ConfiguracionUpdate(valor="-3"), USUARIO_ADMIN
        )
    assert e_plazo_neg.value.status_code == 400

    # Porcentaje de anticipo inválido (texto, negativo y > 100)
    with pytest.raises(HTTPException) as e_pct_txt:
        servicio.actualizar_configuracion(
            "porcentaje_anticipo_minimo", ConfiguracionUpdate(valor="xyz"), USUARIO_ADMIN
        )
    assert e_pct_txt.value.status_code == 400

    with pytest.raises(HTTPException) as e_pct_rango:
        servicio.actualizar_configuracion(
            "porcentaje_anticipo_minimo", ConfiguracionUpdate(valor="120"), USUARIO_ADMIN
        )
    assert e_pct_rango.value.status_code == 400

    # Actualizaciones válidas
    act_plazo = servicio.actualizar_configuracion(
        "plazo_minimo_cancelacion_horas",
        ConfiguracionUpdate(valor=" 4 ", descripcion="  Mínimo 4 horas antes  "),
        USUARIO_ADMIN,
    )
    assert act_plazo["valor"] == "4"
    assert act_plazo["descripcion"] == "Mínimo 4 horas antes"

    act_pct = servicio.actualizar_configuracion(
        "porcentaje_anticipo_minimo",
        ConfiguracionUpdate(valor="30"),
        USUARIO_ADMIN,
    )
    assert act_pct["valor"] == "30"


# ===================== REPORTES Y KPIs =====================
def test_reportes_resumen_canchas_y_servicios():
    repo = FakeFinanzasRepository()
    servicio = FinanzasService(repo=repo)

    resumen = servicio.obtener_reporte_resumen(date(2026, 11, 1), date(2026, 11, 30))
    assert resumen["reservas"]["total"] == 10
    assert resumen["kpis"]["tasa_cancelacion_porcentaje"] == 20.0
    assert resumen["kpis"]["tasa_asistencia_porcentaje"] == 75.0
    assert resumen["kpis"]["total_recaudado_pagos"] == 600.0

    # Periodo sin reservas (evita división por cero)
    repo.resumen_vacio = True
    vacio = servicio.obtener_reporte_resumen()
    assert vacio["kpis"]["tasa_cancelacion_porcentaje"] == 0.0
    assert vacio["kpis"]["tasa_asistencia_porcentaje"] == 0.0
    assert vacio["kpis"]["total_recaudado_pagos"] == 0.0

    assert len(servicio.obtener_reporte_canchas()) == 1
    assert len(servicio.obtener_reporte_servicios()) == 1

    # Fechas invertidas lanzan 400
    with pytest.raises(HTTPException) as e_cancha:
        servicio.obtener_reporte_canchas(date(2026, 12, 10), date(2026, 12, 1))
    assert e_cancha.value.status_code == 400

    with pytest.raises(HTTPException) as e_serv:
        servicio.obtener_reporte_servicios(date(2026, 12, 10), date(2026, 12, 1))
    assert e_serv.value.status_code == 400


# ===================== SCHEMAS =====================
def test_schemas_finanzas_rechazan_valores_invalidos():
    with pytest.raises(ValidationError):
        PagoCreate(id_reserva=1, monto=0, tipo_pago="anticipo", metodo_pago="qr")

    with pytest.raises(ValidationError):
        PagoCreate(id_reserva=1, monto=50.0, tipo_pago="otro", metodo_pago="qr")

    with pytest.raises(ValidationError):
        PagoCreate(id_reserva=1, monto=50.0, tipo_pago="anticipo", metodo_pago="cripto")

    with pytest.raises(ValidationError):
        ConfiguracionUpdate(valor="")