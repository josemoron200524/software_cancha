from datetime import date, datetime, time
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from app.schemas.reserva_schema import (
    ReservaCreate,
    ReservaEstadoUpdate,
    ReservaReprogramar,
)
from app.services.reserva_service import ReservaService

AHORA_FIJO = datetime(2026, 11, 19, 10, 0)
MANANA = date(2026, 11, 20)


class FakeReservaRepository:
    def __init__(self):
        self.clientes = {
            1: {"id_cliente": 1, "id_usuario": 3, "nombres": "Luis", "activo": True},
            2: {"id_cliente": 2, "id_usuario": 4, "nombres": "Pedro", "activo": True},
            3: {"id_cliente": 3, "id_usuario": 5, "nombres": "Inactivo", "activo": False},
        }
        self.empleados = {
            2: {"id_empleado": 1, "id_usuario": 2, "nombres": "Carlos", "activo": True},
        }
        self.canchas = {
            1: {
                "id_cancha": 1,
                "nombre": "Cancha 1 - Fútbol 5",
                "precio_hora": 120.0,
                "estado": "disponible",
            },
            2: {
                "id_cancha": 2,
                "nombre": "Cancha 2 - Mantenimiento",
                "precio_hora": 180.0,
                "estado": "mantenimiento",
            },
        }
        self.servicios = {
            1: {
                "id_servicio": 1,
                "nombre": "Alquiler Diurno (1h)",
                "duracion_minutos": 60,
                "precio_adicional": 0.0,
                "activo": True,
            },
            2: {
                "id_servicio": 2,
                "nombre": "Alquiler Nocturno (1h)",
                "duracion_minutos": 60,
                "precio_adicional": 30.0,
                "activo": True,
            },
            3: {
                "id_servicio": 3,
                "nombre": "Paquete 2 horas",
                "duracion_minutos": 120,
                "precio_adicional": 40.0,
                "activo": True,
            },
            4: {
                "id_servicio": 4,
                "nombre": "Servicio Inactivo",
                "duracion_minutos": 60,
                "precio_adicional": 0.0,
                "activo": False,
            },
        }
        self.horarios = {
            (1, dia): {
                "id_cancha": 1,
                "dia_semana": dia,
                "hora_apertura": time(8, 0),
                "hora_cierre": time(23, 0),
                "activo": True,
            }
            for dia in range(1, 7)  # Lunes a Sábado activos; Domingo (7) sin horario
        }
        self.config = {"plazo_minimo_cancelacion_horas": "2"}
        self.reservas: dict[int, dict] = {}
        self.next_id = 1

    def obtener_cliente_por_usuario(self, id_usuario: int):
        for c in self.clientes.values():
            if c["id_usuario"] == id_usuario:
                return c
        return None

    def obtener_cliente_por_id(self, id_cliente: int):
        return self.clientes.get(id_cliente)

    def obtener_empleado_por_usuario(self, id_usuario: int):
        return self.empleados.get(id_usuario)

    def obtener_cancha(self, id_cancha: int):
        return self.canchas.get(id_cancha)

    def obtener_servicio(self, id_servicio: int):
        return self.servicios.get(id_servicio)

    def obtener_horario_cancha_dia(self, id_cancha: int, dia_semana: int):
        return self.horarios.get((id_cancha, dia_semana))

    def obtener_configuracion(self, clave: str):
        return self.config.get(clave)

    def obtener_siguiente_correlativo(self, anio: int) -> int:
        return self.next_id

    def listar_bloques_ocupados(self, id_cancha: int, fecha_reserva: date):
        bloques = [
            {
                "id_reserva": r["id_reserva"],
                "codigo_reserva": r["codigo_reserva"],
                "hora_inicio": r["hora_inicio"],
                "hora_fin": r["hora_fin"],
                "estado": r["estado"],
            }
            for r in self.reservas.values()
            if r["id_cancha"] == id_cancha
            and r["fecha_reserva"] == fecha_reserva
            and r["estado"] in ("pendiente", "confirmada", "atendida")
        ]
        return sorted(bloques, key=lambda b: b["hora_inicio"])

    def existe_choque_horario(
        self,
        id_cancha: int,
        fecha_reserva: date,
        hora_inicio: time,
        hora_fin: time,
        excluir_id_reserva: int | None = None,
    ) -> bool:
        for r in self.reservas.values():
            if (
                r["id_cancha"] == id_cancha
                and r["fecha_reserva"] == fecha_reserva
                and r["estado"] in ("pendiente", "confirmada", "atendida")
                and r["id_reserva"] != excluir_id_reserva
                and hora_inicio < r["hora_fin"]
                and hora_fin > r["hora_inicio"]
            ):
                return True
        return False

    def listar_reservas(
        self,
        fecha_desde=None,
        fecha_hasta=None,
        id_cancha=None,
        estado=None,
        id_cliente=None,
    ):
        resultado = list(self.reservas.values())
        if fecha_desde:
            resultado = [r for r in resultado if r["fecha_reserva"] >= fecha_desde]
        if fecha_hasta:
            resultado = [r for r in resultado if r["fecha_reserva"] <= fecha_hasta]
        if id_cancha:
            resultado = [r for r in resultado if r["id_cancha"] == id_cancha]
        if estado:
            resultado = [r for r in resultado if r["estado"] == estado]
        if id_cliente:
            resultado = [r for r in resultado if r["id_cliente"] == id_cliente]
        return resultado

    def obtener_reserva_por_id(self, id_reserva: int):
        return self.reservas.get(id_reserva)

    def crear_reserva(self, datos: dict):
        nueva = {
            "id_reserva": self.next_id,
            "estado": "pendiente",
            "motivo_cancelacion": None,
            **datos,
        }
        self.reservas[self.next_id] = nueva
        self.next_id += 1
        return nueva

    def reprogramar_reserva(self, id_reserva: int, datos: dict):
        self.reservas[id_reserva].update(datos)
        return self.reservas[id_reserva]

    def actualizar_estado(
        self, id_reserva: int, nuevo_estado: str, motivo_cancelacion, modificado_por: int
    ):
        self.reservas[id_reserva]["estado"] = nuevo_estado
        if motivo_cancelacion is not None:
            self.reservas[id_reserva]["motivo_cancelacion"] = motivo_cancelacion
        self.reservas[id_reserva]["modificado_por"] = modificado_por
        return self.reservas[id_reserva]


def crear_servicio(repo: FakeReservaRepository | None = None, ahora: datetime = AHORA_FIJO):
    return ReservaService(repo=repo or FakeReservaRepository(), ahora_fn=lambda: ahora)


USUARIO_ADMIN = {"id_usuario": 1, "rol": "administrador"}
USUARIO_RECEP = {"id_usuario": 2, "rol": "recepcionista"}
USUARIO_CLIENTE = {"id_usuario": 3, "rol": "cliente"}
USUARIO_OTRO_CLIENTE = {"id_usuario": 4, "rol": "cliente"}


# ===================== DISPONIBILIDAD =====================
def test_disponibilidad_con_y_sin_bloques_ocupados():
    repo = FakeReservaRepository()
    servicio = crear_servicio(repo)

    libre = servicio.consultar_disponibilidad(1, MANANA)
    assert libre["disponible"] is True
    assert libre["bloques_disponibles"] == [
        {"hora_inicio": time(8, 0), "hora_fin": time(23, 0)}
    ]

    # Reservar 19:00-20:00 y 20:00-21:00
    servicio.crear_reserva(
        ReservaCreate(id_cancha=1, id_servicio=2, fecha_reserva=MANANA, hora_inicio=time(19, 0)),
        USUARIO_CLIENTE,
    )
    servicio.crear_reserva(
        ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(20, 0)),
        USUARIO_CLIENTE,
    )

    disp = servicio.consultar_disponibilidad(1, MANANA)
    assert len(disp["bloques_ocupados"]) == 2
    assert disp["bloques_disponibles"] == [
        {"hora_inicio": time(8, 0), "hora_fin": time(19, 0)},
        {"hora_inicio": time(21, 0), "hora_fin": time(23, 0)},
    ]


def test_disponibilidad_cancha_inexistente_o_no_disponible():
    servicio = crear_servicio()

    with pytest.raises(HTTPException) as exc:
        servicio.consultar_disponibilidad(999, MANANA)
    assert exc.value.status_code == 404

    mant = servicio.consultar_disponibilidad(2, MANANA)
    assert mant["disponible"] is False
    assert mant["bloques_disponibles"] == []

    # Domingo (2026-11-22) sin horario configurado
    domingo = servicio.consultar_disponibilidad(1, date(2026, 11, 22))
    assert domingo["disponible"] is False


# ===================== CREACIÓN Y VALIDACIONES =====================
def test_crear_reserva_cliente_y_recepcionista_calcula_monto():
    servicio = crear_servicio()

    res_cliente = servicio.crear_reserva(
        ReservaCreate(
            id_cancha=1,
            id_servicio=2,
            fecha_reserva=MANANA,
            hora_inicio=time(19, 0),
        ),
        USUARIO_CLIENTE,
    )
    assert res_cliente["codigo_reserva"] == "RES-2026-0001"
    assert res_cliente["hora_fin"] == time(20, 0)
    assert res_cliente["monto_total"] == 150.0
    assert res_cliente["id_empleado"] is None

    res_recep = servicio.crear_reserva(
        ReservaCreate(
            id_cancha=1,
            id_servicio=3,
            id_cliente=2,
            fecha_reserva=MANANA,
            hora_inicio=time(16, 0),
        ),
        USUARIO_RECEP,
    )
    assert res_recep["codigo_reserva"] == "RES-2026-0002"
    assert res_recep["hora_fin"] == time(18, 0)
    assert res_recep["monto_total"] == 280.0
    assert res_recep["id_empleado"] == 1


def test_crear_reserva_con_hora_fin_explicita_y_anti_choque_409():
    servicio = crear_servicio()

    creada = servicio.crear_reserva(
        ReservaCreate(
            id_cancha=1,
            id_servicio=1,
            fecha_reserva=MANANA,
            hora_inicio=time(14, 0),
            hora_fin=time(16, 0),
        ),
        USUARIO_CLIENTE,
    )
    assert creada["monto_total"] == 240.0

    # Solapamiento parcial (15:00-16:00) debe lanzar 409
    with pytest.raises(HTTPException) as exc:
        servicio.crear_reserva(
            ReservaCreate(
                id_cancha=1,
                id_servicio=1,
                fecha_reserva=MANANA,
                hora_inicio=time(15, 0),
            ),
            USUARIO_OTRO_CLIENTE,
        )
    assert exc.value.status_code == 409


def test_validaciones_creacion_errores_400_y_404():
    servicio = crear_servicio()

    # Recepcionista sin id_cliente -> 400
    with pytest.raises(HTTPException) as e1:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            USUARIO_RECEP,
        )
    assert e1.value.status_code == 400

    # Recepcionista con cliente inexistente -> 404
    with pytest.raises(HTTPException) as e2:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, id_cliente=999, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            USUARIO_RECEP,
        )
    assert e2.value.status_code == 404

    # Cliente inactivo -> 400
    with pytest.raises(HTTPException) as e3:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            {"id_usuario": 5, "rol": "cliente"},
        )
    assert e3.value.status_code == 400

    # Cancha inexistente (404) y en mantenimiento (400)
    with pytest.raises(HTTPException) as e4:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=99, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            USUARIO_CLIENTE,
        )
    assert e4.value.status_code == 404

    with pytest.raises(HTTPException) as e5:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=2, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            USUARIO_CLIENTE,
        )
    assert e5.value.status_code == 400

    # Servicio inexistente (404) e inactivo (400)
    with pytest.raises(HTTPException) as e6:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=99, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            USUARIO_CLIENTE,
        )
    assert e6.value.status_code == 404

    with pytest.raises(HTTPException) as e7:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=4, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
            USUARIO_CLIENTE,
        )
    assert e7.value.status_code == 400

    # Fecha pasada -> 400
    with pytest.raises(HTTPException) as e8:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=date(2026, 11, 18), hora_inicio=time(10, 0)),
            USUARIO_CLIENTE,
        )
    assert e8.value.status_code == 400

    # Excede medianoche -> 400
    with pytest.raises(HTTPException) as e9:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(23, 30)),
            USUARIO_CLIENTE,
        )
    assert e9.value.status_code == 400

    # Día sin horario activo (Domingo 2026-11-22) -> 400
    with pytest.raises(HTTPException) as e10:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=date(2026, 11, 22), hora_inicio=time(10, 0)),
            USUARIO_CLIENTE,
        )
    assert e10.value.status_code == 400

    # Fuera de horario de atención (07:00 antes de las 08:00) -> 400
    with pytest.raises(HTTPException) as e11:
        servicio.crear_reserva(
            ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(7, 0)),
            USUARIO_CLIENTE,
        )
    assert e11.value.status_code == 400


# ===================== LISTADO Y ACCESO POR ROL =====================
def test_listar_y_obtener_reservas_respetando_roles():
    servicio = crear_servicio()
    r1 = servicio.crear_reserva(
        ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(10, 0)),
        USUARIO_CLIENTE,
    )
    servicio.crear_reserva(
        ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(11, 0)),
        USUARIO_OTRO_CLIENTE,
    )

    assert len(servicio.listar_reservas(USUARIO_ADMIN)) == 2
    assert len(servicio.listar_reservas(USUARIO_CLIENTE)) == 1
    assert servicio.listar_reservas({"id_usuario": 999, "rol": "cliente"}) == []

    # Otro cliente no puede ver la reserva ajena (403)
    with pytest.raises(HTTPException) as exc_403:
        servicio.obtener_reserva(r1["id_reserva"], USUARIO_OTRO_CLIENTE)
    assert exc_403.value.status_code == 403

    with pytest.raises(HTTPException) as exc_404:
        servicio.obtener_reserva(999, USUARIO_ADMIN)
    assert exc_404.value.status_code == 404


# ===================== REPROGRAMACIÓN Y ESTADOS =====================
def test_reprogramar_reserva_exitosa_y_restricciones():
    repo = FakeReservaRepository()
    servicio = crear_servicio(repo)

    res = servicio.crear_reserva(
        ReservaCreate(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(18, 0)),
        USUARIO_CLIENTE,
    )

    reprogramada = servicio.reprogramar_reserva(
        res["id_reserva"],
        ReservaReprogramar(
            id_cancha=1,
            id_servicio=2,
            fecha_reserva=MANANA,
            hora_inicio=time(18, 30),
            observaciones="Cambio de horario",
        ),
        USUARIO_CLIENTE,
    )
    assert reprogramada["hora_inicio"] == time(18, 30)
    assert reprogramada["monto_total"] == 150.0

    # Cancelar y luego intentar reprogramar -> 400
    servicio.cambiar_estado_reserva(
        res["id_reserva"],
        ReservaEstadoUpdate(estado="cancelada", motivo_cancelacion="Lluvia fuerte"),
        USUARIO_CLIENTE,
    )
    with pytest.raises(HTTPException) as exc:
        servicio.reprogramar_reserva(
            res["id_reserva"],
            ReservaReprogramar(id_cancha=1, id_servicio=1, fecha_reserva=MANANA, hora_inicio=time(20, 0)),
            USUARIO_ADMIN,
        )
    assert exc.value.status_code == 400


def test_flujo_estados_y_regla_plazo_cancelacion():
    repo = FakeReservaRepository()
    servicio = crear_servicio(repo)

    res = servicio.crear_reserva(
        ReservaCreate(
            id_cancha=1,
            id_servicio=1,
            fecha_reserva=date(2026, 11, 19),
            hora_inicio=time(11, 0),  # Solo 1 hora después de AHORA_FIJO (10:00)
        ),
        USUARIO_CLIENTE,
    )

    # Cliente no puede cambiar a confirmada -> 403
    with pytest.raises(HTTPException) as exc_rol:
        servicio.cambiar_estado_reserva(
            res["id_reserva"],
            ReservaEstadoUpdate(estado="confirmada"),
            USUARIO_CLIENTE,
        )
    assert exc_rol.value.status_code == 403

    # Cliente no puede cancelar con menos de 2h de anticipación -> 400
    with pytest.raises(HTTPException) as exc_plazo:
        servicio.cambiar_estado_reserva(
            res["id_reserva"],
            ReservaEstadoUpdate(estado="cancelada", motivo_cancelacion="No llego"),
            USUARIO_CLIENTE,
        )
    assert exc_plazo.value.status_code == 400

    # Configuración inválida cae al default 2.0h sin romper
    repo.config["plazo_minimo_cancelacion_horas"] = "valor_invalido"
    with pytest.raises(HTTPException) as exc_default:
        servicio.cambiar_estado_reserva(
            res["id_reserva"],
            ReservaEstadoUpdate(estado="cancelada", motivo_cancelacion="No llego"),
            USUARIO_CLIENTE,
        )
    assert exc_default.value.status_code == 400

    # Recepcionista intenta pasar directo de pendiente a atendida -> 400
    with pytest.raises(HTTPException) as exc_trans:
        servicio.cambiar_estado_reserva(
            res["id_reserva"],
            ReservaEstadoUpdate(estado="atendida"),
            USUARIO_RECEP,
        )
    assert exc_trans.value.status_code == 400

    # Recepcionista intenta cancelar sin motivo -> 400
    with pytest.raises(HTTPException) as exc_motivo:
        servicio.cambiar_estado_reserva(
            res["id_reserva"],
            ReservaEstadoUpdate(estado="cancelada", motivo_cancelacion=" "),
            USUARIO_RECEP,
        )
    assert exc_motivo.value.status_code == 400

    # Transición válida: pendiente -> confirmada -> atendida
    conf = servicio.cambiar_estado_reserva(
        res["id_reserva"],
        ReservaEstadoUpdate(estado="confirmada"),
        USUARIO_RECEP,
    )
    assert conf["estado"] == "confirmada"

    atendida = servicio.cambiar_estado_reserva(
        res["id_reserva"],
        ReservaEstadoUpdate(estado="atendida"),
        USUARIO_RECEP,
    )
    assert atendida["estado"] == "atendida"


# ===================== SCHEMAS =====================
def test_schemas_reserva_rechazan_horas_invalidas():
    with pytest.raises(ValidationError):
        ReservaCreate(
            id_cancha=1,
            id_servicio=1,
            fecha_reserva=MANANA,
            hora_inicio=time(20, 0),
            hora_fin=time(19, 0),
        )

    with pytest.raises(ValidationError):
        ReservaReprogramar(
            id_cancha=1,
            id_servicio=1,
            fecha_reserva=MANANA,
            hora_inicio=time(18, 0),
            hora_fin=time(18, 0),
        )