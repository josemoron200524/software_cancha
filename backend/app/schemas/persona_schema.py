from typing import Literal
from pydantic import BaseModel, Field, field_validator, model_validator


def _validar_formato_correo(correo: str) -> str:
    limpio = correo.strip().lower()
    if "@" not in limpio or "." not in limpio.split("@")[-1]:
        raise ValueError("El correo electrónico no tiene un formato válido.")
    return limpio


# ======================== CLIENTES ========================
class ClienteCreate(BaseModel):
    nombres: str = Field(..., min_length=2, max_length=80)
    apellidos: str = Field(..., min_length=2, max_length=80)
    ci_nit: str | None = Field(default=None, min_length=4, max_length=25)
    telefono: str = Field(..., min_length=7, max_length=25)
    correo: str | None = Field(default=None, min_length=5, max_length=120)
    password: str | None = Field(default=None, min_length=6, max_length=72)

    @model_validator(mode="after")
    def validar_credenciales_opcionales(self):
        if (self.correo and not self.password) or (self.password and not self.correo):
            raise ValueError(
                "Si deseas crear cuenta de acceso para el cliente, debes ingresar correo y contraseña."
            )
        if self.correo:
            self.correo = _validar_formato_correo(self.correo)
        return self


class ClienteUpdate(BaseModel):
    nombres: str = Field(..., min_length=2, max_length=80)
    apellidos: str = Field(..., min_length=2, max_length=80)
    ci_nit: str | None = Field(default=None, min_length=4, max_length=25)
    telefono: str = Field(..., min_length=7, max_length=25)
    activo: bool = True


# ======================== EMPLEADOS ========================
class EmpleadoCreate(BaseModel):
    nombres: str = Field(..., min_length=2, max_length=80)
    apellidos: str = Field(..., min_length=2, max_length=80)
    ci: str = Field(..., min_length=4, max_length=25)
    telefono: str = Field(..., min_length=7, max_length=25)
    cargo: str = Field(..., min_length=3, max_length=50)
    rol: Literal["administrador", "recepcionista"] = "recepcionista"
    correo: str = Field(..., min_length=5, max_length=120)
    password: str = Field(..., min_length=6, max_length=72)

    @field_validator("correo")
    @classmethod
    def validar_correo(cls, v: str) -> str:
        return _validar_formato_correo(v)


class EmpleadoUpdate(BaseModel):
    nombres: str = Field(..., min_length=2, max_length=80)
    apellidos: str = Field(..., min_length=2, max_length=80)
    ci: str = Field(..., min_length=4, max_length=25)
    telefono: str = Field(..., min_length=7, max_length=25)
    cargo: str = Field(..., min_length=3, max_length=50)
    rol: Literal["administrador", "recepcionista"]
    activo: bool = True