from fastapi import HTTPException, status
from app.core.security import (
    create_access_token,
    hash_password,
    revoke_token,
    verify_password,
)
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.auth_schema import RegistroClienteRequest


class AuthService:
    def __init__(self, repo: UsuarioRepository | None = None):
        self.repo = repo or UsuarioRepository()

    def iniciar_sesion(self, correo: str, password: str) -> dict:
        usuario = self.repo.obtener_por_correo(correo)
        if not usuario or not verify_password(password, usuario["password_hash"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Correo o contraseña incorrectos.",
            )

        if not usuario["activo"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="La cuenta de usuario se encuentra inactiva.",
            )

        token = create_access_token(
            {
                "id_usuario": usuario["id_usuario"],
                "correo": usuario["correo"],
                "rol": usuario["rol"],
            }
        )

        return {
            "access_token": token,
            "token_type": "bearer",
            "usuario": {
                "id_usuario": usuario["id_usuario"],
                "correo": usuario["correo"],
                "rol": usuario["rol"],
            },
        }

    def registrar_cliente(self, datos: RegistroClienteRequest) -> dict:
        if self.repo.obtener_por_correo(datos.correo):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ya existe una cuenta registrada con ese correo.",
            )

        if self.repo.existe_ci_nit_cliente(datos.ci_nit):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ya existe un cliente registrado con ese CI/NIT.",
            )

        password_cifrado = hash_password(datos.password)
        return self.repo.crear_cliente_con_usuario(
            nombres=datos.nombres,
            apellidos=datos.apellidos,
            ci_nit=datos.ci_nit,
            telefono=datos.telefono,
            correo=datos.correo,
            password_hash=password_cifrado,
        )

    def cerrar_sesion(self, token: str) -> dict:
        revoke_token(token)
        return {"mensaje": "Sesión cerrada correctamente."}