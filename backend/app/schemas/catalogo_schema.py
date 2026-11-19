from datetime import time
from typing import Literal
from pydantic import BaseModel, Field, model_validator


# --- CANCHAS ---
class CanchaCreate(BaseModel):
    nombre: str = Field(..., min_length=3, max_length=80)
    tipo_superficie: str = Field(..., min_length=3, max_length=50)
    capacidad_jugadores: int = Field(..., gt=0, le=50)
    precio_hora: float = Field(..., ge=0)
    estado: Literal["disponible", "mantenimiento", "inactiva"] = "disponible"
    descripcion: str | None = Field(default=None, max_length=500)


class CanchaUpdate(BaseModel):
    nombre: str = Field(..., min_length=3, max_length=80)
    tipo_superficie: str = Field(..., min_length=3, max_length=50)
    capacidad_jugadores: int = Field(..., gt=0, le=50)
    precio_hora: float = Field(..., ge=0)
    estado: Literal["disponible", "mantenimiento", "inactiva"]
    descripcion: str | None = Field(default=None, max_length=500)


# --- SERVICIOS ---
class ServicioCreate(BaseModel):
    nombre: str = Field(..., min_length=3, max_length=100)
    descripcion: str | None = Field(default=None, max_length=500)
    duracion_minutos: int = Field(..., gt=0, le=480)
    precio_adicional: float = Field(default=0.0, ge=0)


class ServicioUpdate(BaseModel):
    nombre: str = Field(..., min_length=3, max_length=100)
    descripcion: str | None = Field(default=None, max_length=500)
    duracion_minutos: int = Field(..., gt=0, le=480)
    precio_adicional: float = Field(..., ge=0)
    activo: bool = True


# --- HORARIOS DE DISPONIBILIDAD ---
class HorarioCreate(BaseModel):
    id_cancha: int = Field(..., gt=0)
    dia_semana: int = Field(..., ge=1, le=7, description="1=Lunes ... 7=Domingo")
    hora_apertura: time
    hora_cierre: time
    activo: bool = True

    @model_validator(mode="after")
    def validar_rango_horas(self):
        if self.hora_cierre <= self.hora_apertura:
            raise ValueError("La hora de cierre debe ser posterior a la hora de apertura.")
        return self


class HorarioUpdate(BaseModel):
    hora_apertura: time
    hora_cierre: time
    activo: bool = True

    @model_validator(mode="after")
    def validar_rango_horas(self):
        if self.hora_cierre <= self.hora_apertura:
            raise ValueError("La hora de cierre debe ser posterior a la hora de apertura.")
        return self