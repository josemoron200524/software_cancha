from fastapi import APIRouter, Depends, status
from app.core.security import require_roles
from app.schemas.persona_schema import (
    ClienteCreate,
    ClienteHabilitarPortal,
    ClienteUpdate,
    EmpleadoCreate,
    EmpleadoUpdate,
)
from app.services.persona_service import PersonaService

router = APIRouter()
persona_service = PersonaService()


# ======================== CLIENTES ========================
@router.get("/clientes", tags=["Clientes"])
def listar_clientes(
    buscar: str | None = None,
    solo_activos: bool = True,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return persona_service.listar_clientes(buscar=buscar, solo_activos=solo_activos)


@router.get("/clientes/{id_cliente}", tags=["Clientes"])
def obtener_cliente(
    id_cliente: int,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return persona_service.obtener_cliente(id_cliente)


@router.post("/clientes", status_code=status.HTTP_201_CREATED, tags=["Clientes"])
def crear_cliente(
    datos: ClienteCreate,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return persona_service.crear_cliente(datos, usuario["id_usuario"])


@router.put("/clientes/{id_cliente}", tags=["Clientes"])
def actualizar_cliente(
    id_cliente: int,
    datos: ClienteUpdate,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return persona_service.actualizar_cliente(id_cliente, datos, usuario["id_usuario"])


@router.post(
    "/clientes/{id_cliente}/habilitar-portal",
    status_code=status.HTTP_201_CREATED,
    tags=["Clientes"],
)
def habilitar_portal_cliente(
    id_cliente: int,
    datos: ClienteHabilitarPortal,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return persona_service.habilitar_portal_cliente(
        id_cliente, datos, usuario["id_usuario"]
    )


@router.delete("/clientes/{id_cliente}", tags=["Clientes"])
def desactivar_cliente(
    id_cliente: int,
    usuario: dict = Depends(require_roles("administrador")),
):
    return persona_service.desactivar_cliente(id_cliente, usuario["id_usuario"])


# ======================== EMPLEADOS ========================
@router.get("/empleados", tags=["Empleados"])
def listar_empleados(
    solo_activos: bool = True,
    usuario: dict = Depends(require_roles("administrador")),
):
    return persona_service.listar_empleados(solo_activos=solo_activos)


@router.get("/empleados/{id_empleado}", tags=["Empleados"])
def obtener_empleado(
    id_empleado: int,
    usuario: dict = Depends(require_roles("administrador")),
):
    return persona_service.obtener_empleado(id_empleado)


@router.post("/empleados", status_code=status.HTTP_201_CREATED, tags=["Empleados"])
def crear_empleado(
    datos: EmpleadoCreate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return persona_service.crear_empleado(datos, usuario["id_usuario"])


@router.put("/empleados/{id_empleado}", tags=["Empleados"])
def actualizar_empleado(
    id_empleado: int,
    datos: EmpleadoUpdate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return persona_service.actualizar_empleado(id_empleado, datos, usuario["id_usuario"])


@router.delete("/empleados/{id_empleado}", tags=["Empleados"])
def desactivar_empleado(
    id_empleado: int,
    usuario: dict = Depends(require_roles("administrador")),
):
    return persona_service.desactivar_empleado(id_empleado, usuario["id_usuario"])