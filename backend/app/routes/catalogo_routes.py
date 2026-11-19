from fastapi import APIRouter, Depends, status
from app.core.security import require_roles
from app.schemas.catalogo_schema import (
    CanchaCreate,
    CanchaUpdate,
    HorarioCreate,
    HorarioUpdate,
    ServicioCreate,
    ServicioUpdate,
)
from app.services.catalogo_service import CatalogoService

router = APIRouter()
catalogo_service = CatalogoService()


# ======================== CANCHAS ========================
@router.get("/canchas", tags=["Canchas"])
def listar_canchas(solo_disponibles: bool = False):
    return catalogo_service.listar_canchas(solo_disponibles=solo_disponibles)


@router.get("/canchas/{id_cancha}", tags=["Canchas"])
def obtener_cancha(id_cancha: int):
    return catalogo_service.obtener_cancha(id_cancha)


@router.post("/canchas", status_code=status.HTTP_201_CREATED, tags=["Canchas"])
def crear_cancha(
    datos: CanchaCreate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.crear_cancha(datos, usuario["id_usuario"])


@router.put("/canchas/{id_cancha}", tags=["Canchas"])
def actualizar_cancha(
    id_cancha: int,
    datos: CanchaUpdate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.actualizar_cancha(id_cancha, datos, usuario["id_usuario"])


@router.delete("/canchas/{id_cancha}", tags=["Canchas"])
def desactivar_cancha(
    id_cancha: int,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.desactivar_cancha(id_cancha, usuario["id_usuario"])


# ======================= SERVICIOS =======================
@router.get("/servicios", tags=["Servicios"])
def listar_servicios(solo_activos: bool = True):
    return catalogo_service.listar_servicios(solo_activos=solo_activos)


@router.get("/servicios/{id_servicio}", tags=["Servicios"])
def obtener_servicio(id_servicio: int):
    return catalogo_service.obtener_servicio(id_servicio)


@router.post("/servicios", status_code=status.HTTP_201_CREATED, tags=["Servicios"])
def crear_servicio(
    datos: ServicioCreate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.crear_servicio(datos, usuario["id_usuario"])


@router.put("/servicios/{id_servicio}", tags=["Servicios"])
def actualizar_servicio(
    id_servicio: int,
    datos: ServicioUpdate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.actualizar_servicio(
        id_servicio, datos, usuario["id_usuario"]
    )


@router.delete("/servicios/{id_servicio}", tags=["Servicios"])
def desactivar_servicio(
    id_servicio: int,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.desactivar_servicio(id_servicio, usuario["id_usuario"])


# =============== HORARIOS DE DISPONIBILIDAD ===============
@router.get("/horarios/cancha/{id_cancha}", tags=["Horarios de Disponibilidad"])
def listar_horarios_cancha(id_cancha: int):
    return catalogo_service.listar_horarios_cancha(id_cancha)


@router.post(
    "/horarios",
    status_code=status.HTTP_201_CREATED,
    tags=["Horarios de Disponibilidad"],
)
def crear_horario(
    datos: HorarioCreate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.crear_horario(datos, usuario["id_usuario"])


@router.put("/horarios/{id_horario}", tags=["Horarios de Disponibilidad"])
def actualizar_horario(
    id_horario: int,
    datos: HorarioUpdate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.actualizar_horario(
        id_horario, datos, usuario["id_usuario"]
    )


@router.delete("/horarios/{id_horario}", tags=["Horarios de Disponibilidad"])
def eliminar_horario(
    id_horario: int,
    usuario: dict = Depends(require_roles("administrador")),
):
    return catalogo_service.eliminar_horario(id_horario)