from app.core.database import get_db_connection


class PersonaRepository:
    # ======================== UTILIDADES USUARIO ========================
    def existe_correo(self, correo: str) -> bool:
        query = "SELECT 1 FROM usuarios WHERE LOWER(correo) = LOWER(%s);"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (correo,))
                return cur.fetchone() is not None

    # ======================== CLIENTES ========================
    def listar_clientes(
        self, buscar: str | None = None, solo_activos: bool = True
    ) -> list[dict]:
        condiciones = []
        parametros: list = []

        if solo_activos:
            condiciones.append("c.activo = TRUE")

        if buscar:
            patron = f"%{buscar.strip()}%"
            condiciones.append(
                "(c.nombres ILIKE %s OR c.apellidos ILIKE %s OR COALESCE(c.ci_nit, '') ILIKE %s OR c.telefono ILIKE %s)"
            )
            parametros.extend([patron, patron, patron, patron])

        where_sql = f"WHERE {' AND '.join(condiciones)}" if condiciones else ""
        query = f"""
            SELECT c.id_cliente, c.id_usuario, c.nombres, c.apellidos,
                   c.ci_nit, c.telefono, c.activo, u.correo,
                   c.fecha_creacion, c.fecha_modificacion
            FROM clientes c
            LEFT JOIN usuarios u ON c.id_usuario = u.id_usuario
            {where_sql}
            ORDER BY c.id_cliente;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchall()

    def obtener_cliente_por_id(self, id_cliente: int) -> dict | None:
        query = """
            SELECT c.id_cliente, c.id_usuario, c.nombres, c.apellidos,
                   c.ci_nit, c.telefono, c.activo, u.correo,
                   c.fecha_creacion, c.fecha_modificacion
            FROM clientes c
            LEFT JOIN usuarios u ON c.id_usuario = u.id_usuario
            WHERE c.id_cliente = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cliente,))
                return cur.fetchone()

    def obtener_cliente_por_ci_nit(self, ci_nit: str) -> dict | None:
        query = "SELECT * FROM clientes WHERE ci_nit = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (ci_nit,))
                return cur.fetchone()

    def crear_cliente(
        self,
        datos: dict,
        creado_por: int,
        password_hash: str | None = None,
    ) -> dict:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                id_usuario_creado = None

                # Si recepción ingresó correo y clave, crea también su cuenta de portal
                if datos.get("correo") and password_hash:
                    cur.execute("SELECT id_rol FROM roles WHERE nombre = 'cliente';")
                    rol = cur.fetchone()
                    if not rol:
                        raise ValueError("El rol 'cliente' no existe en la base de datos.")

                    cur.execute(
                        """
                        INSERT INTO usuarios (id_rol, correo, password_hash)
                        VALUES (%s, %s, %s)
                        RETURNING id_usuario;
                        """,
                        (rol["id_rol"], datos["correo"], password_hash),
                    )
                    id_usuario_creado = cur.fetchone()["id_usuario"]

                cur.execute(
                    """
                    INSERT INTO clientes (
                        id_usuario, nombres, apellidos, ci_nit, telefono, creado_por
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id_cliente, id_usuario, nombres, apellidos, ci_nit,
                              telefono, activo, fecha_creacion, fecha_modificacion;
                    """,
                    (
                        id_usuario_creado,
                        datos["nombres"],
                        datos["apellidos"],
                        datos["ci_nit"],
                        datos["telefono"],
                        creado_por,
                    ),
                )
                cliente = cur.fetchone()
                cliente["correo"] = datos.get("correo")
                return cliente

    def actualizar_cliente(
        self, id_cliente: int, datos: dict, modificado_por: int
    ) -> dict | None:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE clientes
                    SET nombres = %s,
                        apellidos = %s,
                        ci_nit = %s,
                        telefono = %s,
                        activo = %s,
                        modificado_por = %s
                    WHERE id_cliente = %s
                    RETURNING id_cliente, id_usuario, nombres, apellidos, ci_nit,
                              telefono, activo, fecha_creacion, fecha_modificacion;
                    """,
                    (
                        datos["nombres"],
                        datos["apellidos"],
                        datos["ci_nit"],
                        datos["telefono"],
                        datos["activo"],
                        modificado_por,
                        id_cliente,
                    ),
                )
                cliente = cur.fetchone()
                if cliente and cliente["id_usuario"]:
                    cur.execute(
                        "UPDATE usuarios SET activo = %s WHERE id_usuario = %s;",
                        (datos["activo"], cliente["id_usuario"]),
                    )
                return cliente

    def desactivar_cliente(self, id_cliente: int, modificado_por: int) -> dict | None:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE clientes
                    SET activo = FALSE, modificado_por = %s
                    WHERE id_cliente = %s
                    RETURNING id_cliente, id_usuario, nombres, apellidos, ci_nit,
                              telefono, activo;
                    """,
                    (modificado_por, id_cliente),
                )
                cliente = cur.fetchone()
                if cliente and cliente["id_usuario"]:
                    cur.execute(
                        "UPDATE usuarios SET activo = FALSE WHERE id_usuario = %s;",
                        (cliente["id_usuario"],),
                    )
                return cliente

    # ======================== EMPLEADOS ========================
    def listar_empleados(self, solo_activos: bool = True) -> list[dict]:
        where_sql = "WHERE e.activo = TRUE" if solo_activos else ""
        query = f"""
            SELECT e.id_empleado, e.id_usuario, e.nombres, e.apellidos,
                   e.ci, e.telefono, e.cargo, e.activo,
                   u.correo, r.nombre AS rol,
                   e.fecha_creacion, e.fecha_modificacion
            FROM empleados e
            INNER JOIN usuarios u ON e.id_usuario = u.id_usuario
            INNER JOIN roles r ON u.id_rol = r.id_rol
            {where_sql}
            ORDER BY e.id_empleado;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query)
                return cur.fetchall()

    def obtener_empleado_por_id(self, id_empleado: int) -> dict | None:
        query = """
            SELECT e.id_empleado, e.id_usuario, e.nombres, e.apellidos,
                   e.ci, e.telefono, e.cargo, e.activo,
                   u.correo, r.nombre AS rol,
                   e.fecha_creacion, e.fecha_modificacion
            FROM empleados e
            INNER JOIN usuarios u ON e.id_usuario = u.id_usuario
            INNER JOIN roles r ON u.id_rol = r.id_rol
            WHERE e.id_empleado = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_empleado,))
                return cur.fetchone()

    def obtener_empleado_por_ci(self, ci: str) -> dict | None:
        query = "SELECT * FROM empleados WHERE ci = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (ci,))
                return cur.fetchone()

    def crear_empleado(
        self, datos: dict, password_hash: str, creado_por: int
    ) -> dict:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id_rol FROM roles WHERE nombre = %s;", (datos["rol"],)
                )
                rol = cur.fetchone()
                if not rol:
                    raise ValueError(f"El rol '{datos['rol']}' no existe en la base de datos.")

                cur.execute(
                    """
                    INSERT INTO usuarios (id_rol, correo, password_hash)
                    VALUES (%s, %s, %s)
                    RETURNING id_usuario;
                    """,
                    (rol["id_rol"], datos["correo"], password_hash),
                )
                id_usuario = cur.fetchone()["id_usuario"]

                cur.execute(
                    """
                    INSERT INTO empleados (
                        id_usuario, nombres, apellidos, ci, telefono, cargo, creado_por
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id_empleado, id_usuario, nombres, apellidos, ci,
                              telefono, cargo, activo, fecha_creacion, fecha_modificacion;
                    """,
                    (
                        id_usuario,
                        datos["nombres"],
                        datos["apellidos"],
                        datos["ci"],
                        datos["telefono"],
                        datos["cargo"],
                        creado_por,
                    ),
                )
                empleado = cur.fetchone()
                empleado["correo"] = datos["correo"]
                empleado["rol"] = datos["rol"]
                return empleado

    def actualizar_empleado(
        self, id_empleado: int, datos: dict, modificado_por: int
    ) -> dict | None:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id_rol FROM roles WHERE nombre = %s;", (datos["rol"],)
                )
                rol = cur.fetchone()
                if not rol:
                    raise ValueError(f"El rol '{datos['rol']}' no existe en la base de datos.")

                cur.execute(
                    """
                    UPDATE empleados
                    SET nombres = %s,
                        apellidos = %s,
                        ci = %s,
                        telefono = %s,
                        cargo = %s,
                        activo = %s,
                        modificado_por = %s
                    WHERE id_empleado = %s
                    RETURNING id_empleado, id_usuario, nombres, apellidos, ci,
                              telefono, cargo, activo, fecha_creacion, fecha_modificacion;
                    """,
                    (
                        datos["nombres"],
                        datos["apellidos"],
                        datos["ci"],
                        datos["telefono"],
                        datos["cargo"],
                        datos["activo"],
                        modificado_por,
                        id_empleado,
                    ),
                )
                empleado = cur.fetchone()
                if empleado:
                    cur.execute(
                        """
                        UPDATE usuarios
                        SET id_rol = %s, activo = %s
                        WHERE id_usuario = %s
                        RETURNING correo;
                        """,
                        (rol["id_rol"], datos["activo"], empleado["id_usuario"]),
                    )
                    usuario = cur.fetchone()
                    empleado["correo"] = usuario["correo"]
                    empleado["rol"] = datos["rol"]
                return empleado

    def desactivar_empleado(self, id_empleado: int, modificado_por: int) -> dict | None:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE empleados
                    SET activo = FALSE, modificado_por = %s
                    WHERE id_empleado = %s
                    RETURNING id_empleado, id_usuario, nombres, apellidos, ci,
                              cargo, activo;
                    """,
                    (modificado_por, id_empleado),
                )
                empleado = cur.fetchone()
                if empleado:
                    cur.execute(
                        "UPDATE usuarios SET activo = FALSE WHERE id_usuario = %s;",
                        (empleado["id_usuario"],),
                    )
                return empleado