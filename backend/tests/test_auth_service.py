import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from app.core.security import REVOKED_TOKENS, decode_access_token, hash_password
from app.schemas.auth_schema import LoginRequest, RegistroClienteRequest
from app.services.auth_service import AuthService


class FakeUsuarioRepository:
    def __init__(self, usuarios=None, cis=None):
        self.usuarios = usuarios or {}
        self.cis = set(cis or [])

    def obtener_por_correo(self, correo: str):
        return self.usuarios.get(correo)

    def existe_ci_nit_cliente(self, ci_nit: str) -> bool:
        return ci_nit in self.cis

    def crear_cliente_con_usuario(
        self, nombres, apellidos, ci_nit, telefono, correo, password_hash
    ):
        self.usuarios[correo] = {
            "id_usuario": 10,
            "correo": correo,
            "password_hash": password_hash,
            "activo": True,
            "rol": "cliente",
        }
        self.cis.add(ci_nit)
        return {
            "id_usuario": 10,
            "id_cliente": 5,
            "correo": correo,
            "rol": "cliente",
        }


@pytest.fixture(autouse=True)
def limpiar_tokens():
    REVOKED_TOKENS.clear()
    yield
    REVOKED_TOKENS.clear()


def test_login_exitoso():
    repo = FakeUsuarioRepository(
        usuarios={
            "admin@cancha.com": {
                "id_usuario": 1,
                "correo": "admin@cancha.com",
                "password_hash": hash_password("Admin123*"),
                "activo": True,
                "rol": "administrador",
            }
        }
    )
    servicio = AuthService(repo=repo)
    respuesta = servicio.iniciar_sesion("admin@cancha.com", "Admin123*")

    assert respuesta["token_type"] == "bearer"
    assert respuesta["usuario"]["rol"] == "administrador"
    assert isinstance(respuesta["access_token"], str)


def test_login_contrasena_incorrecta_lanza_401():
    repo = FakeUsuarioRepository(
        usuarios={
            "admin@cancha.com": {
                "id_usuario": 1,
                "correo": "admin@cancha.com",
                "password_hash": hash_password("Admin123*"),
                "activo": True,
                "rol": "administrador",
            }
        }
    )
    servicio = AuthService(repo=repo)

    with pytest.raises(HTTPException) as exc:
        servicio.iniciar_sesion("admin@cancha.com", "OtraClave123")

    assert exc.value.status_code == 401


def test_login_usuario_inexistente_lanza_401():
    servicio = AuthService(repo=FakeUsuarioRepository())

    with pytest.raises(HTTPException) as exc:
        servicio.iniciar_sesion("nadie@cancha.com", "Clave123")

    assert exc.value.status_code == 401


def test_login_usuario_inactivo_lanza_403():
    repo = FakeUsuarioRepository(
        usuarios={
            "bloqueado@cancha.com": {
                "id_usuario": 4,
                "correo": "bloqueado@cancha.com",
                "password_hash": hash_password("Clave123*"),
                "activo": False,
                "rol": "cliente",
            }
        }
    )
    servicio = AuthService(repo=repo)

    with pytest.raises(HTTPException) as exc:
        servicio.iniciar_sesion("bloqueado@cancha.com", "Clave123*")

    assert exc.value.status_code == 403


def test_registrar_cliente_exitoso_y_cifra_password():
    repo = FakeUsuarioRepository()
    servicio = AuthService(repo=repo)
    datos = RegistroClienteRequest(
        nombres="María",
        apellidos="Gómez",
        ci_nit="7894561",
        telefono="71234567",
        correo="  Maria@Correo.COM ",
        password="Password123",
    )

    resultado = servicio.registrar_cliente(datos)

    assert resultado["correo"] == "maria@correo.com"
    assert resultado["rol"] == "cliente"
    assert repo.usuarios["maria@correo.com"]["password_hash"] != "Password123"


def test_registrar_cliente_correo_duplicado_lanza_409():
    repo = FakeUsuarioRepository(
        usuarios={"duplicado@correo.com": {"id_usuario": 2}}
    )
    servicio = AuthService(repo=repo)
    datos = RegistroClienteRequest(
        nombres="Juan",
        apellidos="Pérez",
        ci_nit="5551234",
        telefono="70001122",
        correo="duplicado@correo.com",
        password="Password123",
    )

    with pytest.raises(HTTPException) as exc:
        servicio.registrar_cliente(datos)

    assert exc.value.status_code == 409


def test_registrar_cliente_ci_duplicado_lanza_409():
    repo = FakeUsuarioRepository(cis={"9998887"})
    servicio = AuthService(repo=repo)
    datos = RegistroClienteRequest(
        nombres="Juan",
        apellidos="Pérez",
        ci_nit="9998887",
        telefono="70001122",
        correo="nuevo@correo.com",
        password="Password123",
    )

    with pytest.raises(HTTPException) as exc:
        servicio.registrar_cliente(datos)

    assert exc.value.status_code == 409


def test_cerrar_sesion_revoca_token():
    repo = FakeUsuarioRepository(
        usuarios={
            "cliente@cancha.com": {
                "id_usuario": 3,
                "correo": "cliente@cancha.com",
                "password_hash": hash_password("Cliente123*"),
                "activo": True,
                "rol": "cliente",
            }
        }
    )
    servicio = AuthService(repo=repo)
    login = servicio.iniciar_sesion("cliente@cancha.com", "Cliente123*")
    token = login["access_token"]

    respuesta = servicio.cerrar_sesion(token)
    assert "cerrada" in respuesta["mensaje"].lower()

    with pytest.raises(HTTPException) as exc:
        decode_access_token(token)
    assert exc.value.status_code == 401


def test_schema_rechaza_correo_invalido():
    with pytest.raises(ValidationError):
        LoginRequest(correo="correo_sin_arroba", password="Password123")