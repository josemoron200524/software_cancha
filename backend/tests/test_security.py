import pytest
from fastapi import HTTPException
from app.core.security import (
    REVOKED_TOKENS,
    create_access_token,
    decode_access_token,
    hash_password,
    require_roles,
    revoke_token,
    verify_password,
)


@pytest.fixture(autouse=True)
def limpiar_tokens_revocados():
    REVOKED_TOKENS.clear()
    yield
    REVOKED_TOKENS.clear()


def test_hash_y_verificacion_contrasena():
    clave_plana = "Admin123*"
    clave_hash = hash_password(clave_plana)

    assert clave_hash != clave_plana
    assert verify_password(clave_plana, clave_hash) is True
    assert verify_password("ClaveIncorrecta", clave_hash) is False


def test_crear_y_decodificar_token_jwt():
    datos = {"id_usuario": 1, "correo": "admin@cancha.com", "rol": "administrador"}
    token = create_access_token(datos)
    payload = decode_access_token(token)

    assert payload["id_usuario"] == 1
    assert payload["correo"] == "admin@cancha.com"
    assert payload["rol"] == "administrador"
    assert "exp" in payload


def test_decodificar_token_invalido_lanza_401():
    with pytest.raises(HTTPException) as exc:
        decode_access_token("token.invalido.falso")

    assert exc.value.status_code == 401


def test_token_revocado_lanza_401():
    token = create_access_token({"id_usuario": 2, "correo": "a@b.com", "rol": "cliente"})
    revoke_token(token)

    with pytest.raises(HTTPException) as exc:
        decode_access_token(token)

    assert exc.value.status_code == 401


def test_require_roles_permite_rol_autorizado():
    verificador = require_roles("administrador", "recepcionista")
    usuario = {"id_usuario": 1, "correo": "admin@cancha.com", "rol": "administrador"}

    resultado = verificador(usuario_actual=usuario)
    assert resultado == usuario


def test_require_roles_bloquea_rol_no_autorizado_con_403():
    verificador = require_roles("administrador")
    usuario_cliente = {"id_usuario": 3, "correo": "cliente@cancha.com", "rol": "cliente"}

    with pytest.raises(HTTPException) as exc:
        verificador(usuario_actual=usuario_cliente)

    assert exc.value.status_code == 403