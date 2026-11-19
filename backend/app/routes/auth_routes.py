from fastapi import APIRouter, Depends, status
from app.core.security import get_current_user, require_roles
from app.schemas.auth_schema import (
    LoginRequest,
    LoginResponse,
    RegistroClienteRequest,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Autenticación y Roles"])
auth_service = AuthService()


@router.post("/login", response_model=LoginResponse)
def login(datos: LoginRequest):
    return auth_service.iniciar_sesion(datos.correo, datos.password)


@router.post("/register", status_code=status.HTTP_201_CREATED)
def registrar_cliente(datos: RegistroClienteRequest):
    return auth_service.registrar_cliente(datos)


@router.post("/logout")
def logout(usuario_actual: dict = Depends(get_current_user)):
    return auth_service.cerrar_sesion(usuario_actual["token"])


@router.get("/me")
def perfil_actual(usuario_actual: dict = Depends(get_current_user)):
    return {
        "id_usuario": usuario_actual["id_usuario"],
        "correo": usuario_actual["correo"],
        "rol": usuario_actual["rol"],
    }


@router.get("/verificar-admin")
def ruta_solo_admin(
    usuario_actual: dict = Depends(require_roles("administrador")),
):
    return {
        "mensaje": "Acceso autorizado solo para administradores.",
        "usuario": usuario_actual["correo"],
    }