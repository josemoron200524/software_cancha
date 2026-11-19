from datetime import date
from fastapi import APIRouter, Depends, status
from app.core.security import get_current_user, require_roles
from app.schemas.finanzas_schema import (
    ConfiguracionUpdate,
    MetodoPago,
    PagoCreate,
)
from app.services.finanzas_service import FinanzasService

router = APIRouter()
finanzas_service = FinanzasService()


# ======================== PAGOS ========================
@router.get("/pagos", tags=["Pagos"])
def listar_pagos(
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    metodo_pago: MetodoPago | None = None,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return finanzas_service.listar_pagos(
        fecha_desde=fecha_desde,
        fecha_hasta=fecha_hasta,
        metodo_pago=metodo_pago,
    )


@router.get("/pagos/reserva/{id_reserva}", tags=["Pagos"])
def listar_pagos_por_reserva(
    id_reserva: int,
    usuario: dict = Depends(get_current_user),
):
    return finanzas_service.listar_pagos_por_reserva(id_reserva, usuario)


@router.post("/pagos", status_code=status.HTTP_201_CREATED, tags=["Pagos"])
def registrar_pago(
    datos: PagoCreate,
    usuario: dict = Depends(require_roles("administrador", "recepcionista")),
):
    return finanzas_service.registrar_pago(datos, usuario)


# ======================== CONFIGURACIÓN ========================
@router.get("/configuracion", tags=["Configuración"])
def listar_configuraciones(usuario: dict = Depends(get_current_user)):
    return finanzas_service.listar_configuraciones()


@router.put("/configuracion/{clave}", tags=["Configuración"])
def actualizar_configuracion(
    clave: str,
    datos: ConfiguracionUpdate,
    usuario: dict = Depends(require_roles("administrador")),
):
    return finanzas_service.actualizar_configuracion(clave, datos, usuario)


# ======================== REPORTES Y KPIs ========================
@router.get("/reportes/resumen", tags=["Reportes y KPIs"])
def reporte_resumen(
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    usuario: dict = Depends(require_roles("administrador")),
):
    return finanzas_service.obtener_reporte_resumen(fecha_desde, fecha_hasta)


@router.get("/reportes/canchas", tags=["Reportes y KPIs"])
def reporte_por_cancha(
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    usuario: dict = Depends(require_roles("administrador")),
):
    return finanzas_service.obtener_reporte_canchas(fecha_desde, fecha_hasta)


@router.get("/reportes/servicios", tags=["Reportes y KPIs"])
def reporte_por_servicio(
    fecha_desde: date | None = None,
    fecha_hasta: date | None = None,
    usuario: dict = Depends(require_roles("administrador")),
):
    return finanzas_service.obtener_reporte_servicios(fecha_desde, fecha_hasta)