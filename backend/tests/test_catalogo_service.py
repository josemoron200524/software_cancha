from datetime import time
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from app.schemas.catalogo_schema import (
    CanchaCreate,
    CanchaUpdate,
    HorarioCreate,
    HorarioUpdate,
    ServicioCreate,
    ServicioUpdate,
)
from app.services.catalogo_service import CatalogoService


class FakeCatalogoRepository:
    def __init__(self):
        self.canchas = {
            1: {
                "id_cancha": 1,
                "nombre": "Cancha 1 - Fútbol 5",
                "tipo_superficie": "Césped sintético",
                "capacidad_jugadores": 10,
                "precio_hora": 120.0,
                "estado": "disponible",
                "descripcion": "Techada",
            }
        }
        self.servicios = {
            1: {
                "id_servicio": 1,
                "nombre": "Alquiler Diurno (1 hora)",
                "descripcion": "Sin luz",
                "duracion_minutos": 60,
                "precio_adicional": 0.0,
                "activo": True,
            }
        }
        self.horarios = {
            1: {
                "id_horario": 1,
                "id_cancha": 1,
                "dia_semana": 1,
                "hora_apertura": time(8, 0),
                "hora_cierre": time(23, 0),
                "activo": True,
            }
        }
        self.next_cancha_id = 2
        self.next_servicio_id = 2
        self.next_horario_id = 2

    # --- CANCHAS ---
    def listar_canchas(self, solo_disponibles: bool = False):
        lista = list(self.canchas.values())
        if solo_disponibles:
            return [c for c in lista if c["estado"] == "disponible"]
        return lista

    def obtener_cancha_por_id(self, id_cancha: int):
        return self.canchas.get(id_cancha)

    def obtener_cancha_por_nombre(self, nombre: str):
        for c in self.canchas.values():
            if c["nombre"].lower() == nombre.lower():
                return c
        return None

    def crear_cancha(self, datos: dict, creado_por: int):
        nueva = {"id_cancha": self.next_cancha_id, **datos, "creado_por": creado_por}
        self.canchas[self.next_cancha_id] = nueva
        self.next_cancha_id += 1
        return nueva

    def actualizar_cancha(self, id_cancha: int, datos: dict, modificado_por: int):
        self.canchas[id_cancha].update({**datos, "modificado_por": modificado_por})
        return self.canchas[id_cancha]

    def desactivar_cancha(self, id_cancha: int, modificado_por: int):
        self.canchas[id_cancha]["estado"] = "inactiva"
        self.canchas[id_cancha]["modificado_por"] = modificado_por
        return self.canchas[id_cancha]

    # --- SERVICIOS ---
    def listar_servicios(self, solo_activos: bool = True):
        lista = list(self.servicios.values())
        if solo_activos:
            return [s for s in lista if s["activo"]]
        return lista

    def obtener_servicio_por_id(self, id_servicio: int):
        return self.servicios.get(id_servicio)

    def obtener_servicio_por_nombre(self, nombre: str):
        for s in self.servicios.values():
            if s["nombre"].lower() == nombre.lower():
                return s
        return None

    def crear_servicio(self, datos: dict, creado_por: int):
        nuevo = {
            "id_servicio": self.next_servicio_id,
            **datos,
            "activo": True,
            "creado_por": creado_por,
        }
        self.servicios[self.next_servicio_id] = nuevo
        self.next_servicio_id += 1
        return nuevo

    def actualizar_servicio(self, id_servicio: int, datos: dict, modificado_por: int):
        self.servicios[id_servicio].update({**datos, "modificado_por": modificado_por})
        return self.servicios[id_servicio]

    def desactivar_servicio(self, id_servicio: int, modificado_por: int):
        self.servicios[id_servicio]["activo"] = False
        self.servicios[id_servicio]["modificado_por"] = modificado_por
        return self.servicios[id_servicio]

    # --- HORARIOS ---
    def listar_horarios_por_cancha(self, id_cancha: int):
        return [h for h in self.horarios.values() if h["id_cancha"] == id_cancha]

    def obtener_horario_por_id(self, id_horario: int):
        return self.horarios.get(id_horario)

    def obtener_horario_cancha_dia(self, id_cancha: int, dia_semana: int):
        for h in self.horarios.values():
            if h["id_cancha"] == id_cancha and h["dia_semana"] == dia_semana:
                return h
        return None

    def crear_horario(self, datos: dict, creado_por: int):
        nuevo = {"id_horario": self.next_horario_id, **datos, "creado_por": creado_por}
        self.horarios[self.next_horario_id] = nuevo
        self.next_horario_id += 1
        return nuevo

    def actualizar_horario(self, id_horario: int, datos: dict, modificado_por: int):
        self.horarios[id_horario].update({**datos, "modificado_por": modificado_por})
        return self.horarios[id_horario]

    def eliminar_horario(self, id_horario: int):
        return self.horarios.pop(id_horario, None) is not None


# ===================== PRUEBAS DE CANCHAS =====================
def test_crear_y_listar_canchas():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    datos = CanchaCreate(
        nombre="  Cancha 2 - Futsal  ",
        tipo_superficie="Polifuncional",
        capacidad_jugadores=10,
        precio_hora=100.0,
    )
    creada = servicio.crear_cancha(datos, id_usuario=1)

    assert creada["nombre"] == "Cancha 2 - Futsal"
    assert len(servicio.listar_canchas()) == 2


def test_crear_cancha_nombre_duplicado_lanza_409():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    datos = CanchaCreate(
        nombre="cancha 1 - fútbol 5",
        tipo_superficie="Césped",
        capacidad_jugadores=10,
        precio_hora=120.0,
    )
    with pytest.raises(HTTPException) as exc:
        servicio.crear_cancha(datos, id_usuario=1)
    assert exc.value.status_code == 409


def test_obtener_cancha_inexistente_lanza_404():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    with pytest.raises(HTTPException) as exc:
        servicio.obtener_cancha(999)
    assert exc.value.status_code == 404


def test_actualizar_cancha_y_desactivar():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    datos_update = CanchaUpdate(
        nombre="Cancha 1 Renovada",
        tipo_superficie="Sintético Pro",
        capacidad_jugadores=12,
        precio_hora=150.0,
        estado="mantenimiento",
    )
    actualizada = servicio.actualizar_cancha(1, datos_update, id_usuario=1)
    assert actualizada["estado"] == "mantenimiento"

    resultado = servicio.desactivar_cancha(1, id_usuario=1)
    assert resultado["cancha"]["estado"] == "inactiva"
    assert len(servicio.listar_canchas(solo_disponibles=True)) == 0


def test_actualizar_cancha_con_nombre_de_otra_lanza_409():
    repo = FakeCatalogoRepository()
    servicio = CatalogoService(repo=repo)
    servicio.crear_cancha(
        CanchaCreate(
            nombre="Cancha 2",
            tipo_superficie="Césped",
            capacidad_jugadores=10,
            precio_hora=100.0,
        ),
        id_usuario=1,
    )

    with pytest.raises(HTTPException) as exc:
        servicio.actualizar_cancha(
            2,
            CanchaUpdate(
                nombre="Cancha 1 - Fútbol 5",
                tipo_superficie="Césped",
                capacidad_jugadores=10,
                precio_hora=100.0,
                estado="disponible",
            ),
            id_usuario=1,
        )
    assert exc.value.status_code == 409


# ===================== PRUEBAS DE SERVICIOS =====================
def test_crud_completo_servicios():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    creado = servicio.crear_servicio(
        ServicioCreate(
            nombre="Alquiler Nocturno",
            duracion_minutos=60,
            precio_adicional=30.0,
        ),
        id_usuario=1,
    )
    assert creado["id_servicio"] == 2

    actualizado = servicio.actualizar_servicio(
        2,
        ServicioUpdate(
            nombre="Alquiler Nocturno VIP",
            duracion_minutos=90,
            precio_adicional=50.0,
            activo=True,
        ),
        id_usuario=1,
    )
    assert actualizado["duracion_minutos"] == 90

    desactivado = servicio.desactivar_servicio(2, id_usuario=1)
    assert desactivado["servicio"]["activo"] is False
    assert len(servicio.listar_servicios(solo_activos=True)) == 1


def test_servicio_duplicado_e_inexistente():
    servicio = CatalogoService(repo=FakeCatalogoRepository())

    with pytest.raises(HTTPException) as exc_dup:
        servicio.crear_servicio(
            ServicioCreate(
                nombre="Alquiler Diurno (1 hora)",
                duracion_minutos=60,
                precio_adicional=0.0,
            ),
            id_usuario=1,
        )
    assert exc_dup.value.status_code == 409

    with pytest.raises(HTTPException) as exc_404:
        servicio.obtener_servicio(999)
    assert exc_404.value.status_code == 404


def test_actualizar_servicio_con_nombre_duplicado_lanza_409():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    servicio.crear_servicio(
        ServicioCreate(nombre="Servicio Extra", duracion_minutos=60, precio_adicional=10.0),
        id_usuario=1,
    )
    with pytest.raises(HTTPException) as exc:
        servicio.actualizar_servicio(
            2,
            ServicioUpdate(
                nombre="Alquiler Diurno (1 hora)",
                duracion_minutos=60,
                precio_adicional=10.0,
                activo=True,
            ),
            id_usuario=1,
        )
    assert exc.value.status_code == 409


# ===================== PRUEBAS DE HORARIOS =====================
def test_crud_horarios_cancha():
    servicio = CatalogoService(repo=FakeCatalogoRepository())
    creado = servicio.crear_horario(
        HorarioCreate(
            id_cancha=1,
            dia_semana=2,
            hora_apertura=time(9, 0),
            hora_cierre=time(22, 0),
        ),
        id_usuario=1,
    )
    assert creado["dia_semana"] == 2
    assert len(servicio.listar_horarios_cancha(1)) == 2

    actualizado = servicio.actualizar_horario(
        2,
        HorarioUpdate(hora_apertura=time(10, 0), hora_cierre=time(21, 0), activo=True),
        id_usuario=1,
    )
    assert actualizado["hora_apertura"] == time(10, 0)

    eliminado = servicio.eliminar_horario(2)
    assert "eliminado" in eliminado["mensaje"].lower()


def test_horario_duplicado_e_inexistente():
    servicio = CatalogoService(repo=FakeCatalogoRepository())

    with pytest.raises(HTTPException) as exc_dup:
        servicio.crear_horario(
            HorarioCreate(
                id_cancha=1,
                dia_semana=1,
                hora_apertura=time(8, 0),
                hora_cierre=time(22, 0),
            ),
            id_usuario=1,
        )
    assert exc_dup.value.status_code == 409

    with pytest.raises(HTTPException) as exc_upd:
        servicio.actualizar_horario(
            999,
            HorarioUpdate(hora_apertura=time(8, 0), hora_cierre=time(20, 0)),
            id_usuario=1,
        )
    assert exc_upd.value.status_code == 404

    with pytest.raises(HTTPException) as exc_del:
        servicio.eliminar_horario(999)
    assert exc_del.value.status_code == 404


# ===================== PRUEBAS DE SCHEMAS =====================
def test_schemas_rechazan_horarios_y_precios_invalidos():
    with pytest.raises(ValidationError):
        HorarioCreate(
            id_cancha=1,
            dia_semana=3,
            hora_apertura=time(22, 0),
            hora_cierre=time(20, 0),
        )

    with pytest.raises(ValidationError):
        HorarioUpdate(hora_apertura=time(18, 0), hora_cierre=time(18, 0))

    with pytest.raises(ValidationError):
        CanchaCreate(
            nombre="Cancha Mala",
            tipo_superficie="Tierra",
            capacidad_jugadores=0,
            precio_hora=-10.0,
        )