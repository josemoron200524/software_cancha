from datetime import date, time
from typing import Literal
from pydantic import BaseModel, Field, model_validator

EstadoReserva = Literal[
    "pendiente", "confirmada", "cancelada", "atendida", "no_asistio"
]


class ReservaCreate(BaseModel):
    id_cancha: int = Field(..., gt=0)
    id_servicio: int = Field(..., gt=0)
    id_cliente: int | None = Field(
        default=None,
        gt=0,
        description="Obligatorio para recepcionista/admin; se ignora si reserva un cliente desde el portal.",
    )
    fecha_reserva: date
    hora_inicio: time
    hora_fin: time | None = Field(
        default=None,
        description="Opcional: si se omite, se calcula automáticamente según la duración del servicio.",
    )
    observaciones: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def validar_horas(self):
        if self.hora_fin is not None and self.hora_fin <= self.hora_inicio:
            raise ValueError("La hora de fin debe ser posterior a la hora de inicio.")
        return self


class ReservaReprogramar(BaseModel):
    id_cancha: int = Field(..., gt=0)
    id_servicio: int = Field(..., gt=0)
    fecha_reserva: date
    hora_inicio: time
    hora_fin: time | None = None
    observaciones: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def validar_horas(self):
        if self.hora_fin is not None and self.hora_fin <= self.hora_inicio:
            raise ValueError("La hora de fin debe ser posterior a la hora de inicio.")
        return self


class ReservaEstadoUpdate(BaseModel):
    estado: EstadoReserva
    motivo_cancelacion: str | None = Field(default=None, max_length=500)