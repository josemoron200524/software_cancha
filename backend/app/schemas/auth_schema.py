from pydantic import BaseModel, Field, field_validator


class LoginRequest(BaseModel):
    correo: str = Field(..., min_length=5, max_length=120)
    password: str = Field(..., min_length=6, max_length=72)

    @field_validator("correo")
    @classmethod
    def validar_correo(cls, v: str) -> str:
        correo = v.strip().lower()
        if "@" not in correo or "." not in correo.split("@")[-1]:
            raise ValueError("El correo electrónico no tiene un formato válido.")
        return correo


class RegistroClienteRequest(BaseModel):
    nombres: str = Field(..., min_length=2, max_length=80)
    apellidos: str = Field(..., min_length=2, max_length=80)
    ci_nit: str = Field(..., min_length=4, max_length=25)
    telefono: str = Field(..., min_length=7, max_length=25)
    correo: str = Field(..., min_length=5, max_length=120)
    password: str = Field(..., min_length=6, max_length=72)

    @field_validator("correo")
    @classmethod
    def validar_correo(cls, v: str) -> str:
        correo = v.strip().lower()
        if "@" not in correo or "." not in correo.split("@")[-1]:
            raise ValueError("El correo electrónico no tiene un formato válido.")
        return correo


class UsuarioInfo(BaseModel):
    id_usuario: int
    correo: str
    rol: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioInfo