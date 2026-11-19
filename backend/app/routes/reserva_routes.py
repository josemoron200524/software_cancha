from datetime import date
from fastapi import APIRouter, Depends, status
from app.core.security import get_current_user, require_roles
from app.schemas.reserva_schema import (
    EstadoReserva,
    ReservaCreate,
    ReservaEstadoUpdate,
    ReservaReprogramar,
)
from app.services.reserva_service import ReservaService

router = APIRouter(prefix="/reservas", tags=["Reservas"])
reserva_service = ReservaService()


@router.get("/disponibilidad")
def consultar_disponibilidad(id_cancha: int, fecha_reserva: date):
    return reserva_service.consultar_disponibilidad(id_cancha, fecha_reserva)


@router.get("/agenda/{fecha_reserva}")
def agenda_diaria(
    fecha_reserva: date,
    id_cancha: int | None = None,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return reserva_service.listar_reservas(
        usuario_actual=usuario,
        fecha_desde=fecha_reserva,
        fecha_hasta=fecha_reserva,
        id_cancha=id_cancha,
    )


@router.get("")
def listar_reservas(
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    id_cancha: int | None = None,
    estado: EstadoReserva | None = None,
    id_cliente: int | None = None,
    usuario: dict = Depends(get_current_user),
):
    return reserva_service.listar_reservas(
        usuario_actual=usuario,
        fecha_desde=fecha_desde,
        fecha_hasta=fecha_hasta,
        id_cancha=id_cancha,
        estado=estado,
        id_cliente=id_cliente,
    )


@router.post("", status_code=status.HTTP_201_CREATED)
def crear_reserva(
    datos: ReservaCreate,
    usuario: dict = Depends(
        require_roles("administrador", "recepcionista", "cliente")
    ),
):
    return reserva_service.crear_reserva(datos, usuario)


@router.get("/{id_reserva}")
def obtener_reserva(
    id_reserva: int,
    usuario: dict = Depends(get_current_user),
):
    return reserva_service.obtener_reserva(id_reserva, usuario)


@router.put("/{id_reserva}/reprogramar")
def reprogramar_reserva(
    id_reserva: int,
    datos: ReservaReprogramar,
    usuario: dict = Depends(
        require_roles("administrador", "recepcionista", "cliente")
    ),
):
    return reserva_service.reprogramar_reserva(id_reserva, datos, usuario)


@router.patch("/{id_reserva}/estado")
def cambiar_estado_reserva(
    id_reserva: int,
    datos: ReservaEstadoUpdate,
    usuario: dict = Depends(
        require_roles("administrador", "recepcionista", "cliente")
    ),
):
    return reserva_service.cambiar_estado_reserva(id_reserva, datos, usuario)