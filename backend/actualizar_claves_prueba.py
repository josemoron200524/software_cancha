from app.core.database import get_db_connection
from app.core.security import hash_password

USUARIOS_PRUEBA = [
    ("admin@cancha.com", "Admin123*"),
    ("recepcion@cancha.com", "Recepcion123*"),
    ("cliente@cancha.com", "Cliente123*"),
]


def actualizar():
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            for correo, clave_plana in USUARIOS_PRUEBA:
                clave_hash = hash_password(clave_plana)
                cur.execute(
                    "UPDATE usuarios SET password_hash = %s WHERE correo = %s;",
                    (clave_hash, correo),
                )
                print(f"Actualizado {correo} -> contraseña: {clave_plana}")


if __name__ == "__main__":
    actualizar()