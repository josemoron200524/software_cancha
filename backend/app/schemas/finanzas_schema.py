from typing import Literal
from pydantic import BaseModel, Field

TipoPago = Literal["anticipo", "saldo", "total"]
MetodoPago = Literal["efectivo", "qr", "transferencia", "tarjeta"]


class PagoCreate(BaseModel):
    id_reserva: int = Field(..., gt=0)
    monto: float = Field(..., gt=0)
    tipo_pago: TipoPago
    metodo_pago: MetodoPago
    referencia_comprobante: str | None = Field(default=None, max_length=80)


class ConfiguracionUpdate(BaseModel):
    valor: str = Field(..., min_length=1, max_length=100)
    descripcion: str | None = Field(default=None, max_length=200)