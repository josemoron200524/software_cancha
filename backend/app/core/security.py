from datetime import datetime, timedelta, timezone
import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.core.config import JWT_SECRET

ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = 8

# Almacena tokens cerrados (logout) para rechazarlos en el servidor
REVOKED_TOKENS: set[str] = set()

security_scheme = HTTPBearer()


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def create_access_token(data: dict) -> str:
    if not JWT_SECRET:
        raise ValueError("No se encontró JWT_SECRET en el archivo .env")
    payload = data.copy()
    expira = datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRE_HOURS)
    payload["exp"] = expira
    return jwt.encode(payload, JWT_SECRET, algorithm=ALGORITHM)


def revoke_token(token: str) -> None:
    REVOKED_TOKENS.add(token)


def decode_access_token(token: str) -> dict:
    if token in REVOKED_TOKENS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="La sesión ya fue cerrada. Inicia sesión nuevamente.",
        )
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="El token ha expirado. Inicia sesión nuevamente.",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticación inválido.",
        )


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
) -> dict:
    payload = decode_access_token(credentials.credentials)
    return {
        "id_usuario": payload.get("id_usuario"),
        "correo": payload.get("correo"),
        "rol": payload.get("rol"),
        "token": credentials.credentials,
    }


def require_roles(*roles_permitidos: str):
    def verificador_rol(usuario_actual: dict = Depends(get_current_user)) -> dict:
        if usuario_actual["rol"] not in roles_permitidos:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Acceso denegado. Se requiere rol: {', '.join(roles_permitidos)}.",
            )
        return usuario_actual

    return verificador_rol