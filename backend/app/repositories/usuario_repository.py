from app.core.database import get_db_connection


class UsuarioRepository:
    def obtener_por_correo(self, correo: str) -> dict | None:
        query = """
            SELECT u.id_usuario, u.correo, u.password_hash, u.activo, r.nombre AS rol
            FROM usuarios u
            INNER JOIN roles r ON u.id_rol = r.id_rol
            WHERE u.correo = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (correo,))
                return cur.fetchone()

    def existe_ci_nit_cliente(self, ci_nit: str) -> bool:
        query = "SELECT 1 FROM clientes WHERE ci_nit = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (ci_nit,))
                return cur.fetchone() is not None

    def crear_cliente_con_usuario(
        self,
        nombres: str,
        apellidos: str,
        ci_nit: str,
        telefono: str,
        correo: str,
        password_hash: str,
    ) -> dict:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                # 1. Buscar el id del rol 'cliente'
                cur.execute("SELECT id_rol FROM roles WHERE nombre = 'cliente';")
                rol = cur.fetchone()
                if not rol:
                    raise ValueError("El rol 'cliente' no existe en la base de datos.")

                # 2. Insertar usuario con contraseña encriptada
                cur.execute(
                    """
                    INSERT INTO usuarios (id_rol, correo, password_hash)
                    VALUES (%s, %s, %s)
                    RETURNING id_usuario, correo;
                    """,
                    (rol["id_rol"], correo, password_hash),
                )
                nuevo_usuario = cur.fetchone()

                # 3. Insertar ficha de cliente vinculada con auditoría (creado_por)
                cur.execute(
                    """
                    INSERT INTO clientes (
                        id_usuario, nombres, apellidos, ci_nit, telefono, creado_por
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id_cliente;
                    """,
                    (
                        nuevo_usuario["id_usuario"],
                        nombres.strip(),
                        apellidos.strip(),
                        ci_nit.strip(),
                        telefono.strip(),
                        nuevo_usuario["id_usuario"],
                    ),
                )
                nuevo_cliente = cur.fetchone()

                return {
                    "id_usuario": nuevo_usuario["id_usuario"],
                    "id_cliente": nuevo_cliente["id_cliente"],
                    "correo": nuevo_usuario["correo"],
                    "rol": "cliente",
                }