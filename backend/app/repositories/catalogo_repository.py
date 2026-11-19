from app.core.database import get_db_connection


class CatalogoRepository:
    # ======================== CANCHAS ========================
    def listar_canchas(self, solo_disponibles: bool = False) -> list[dict]:
        query = "SELECT * FROM canchas"
        if solo_disponibles:
            query += " WHERE estado = 'disponible'"
        query += " ORDER BY id_cancha;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query)
                return cur.fetchall()

    def obtener_cancha_por_id(self, id_cancha: int) -> dict | None:
        query = "SELECT * FROM canchas WHERE id_cancha = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cancha,))
                return cur.fetchone()

    def obtener_cancha_por_nombre(self, nombre: str) -> dict | None:
        query = "SELECT * FROM canchas WHERE LOWER(nombre) = LOWER(%s);"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (nombre,))
                return cur.fetchone()

    def crear_cancha(self, datos: dict, creado_por: int) -> dict:
        query = """
            INSERT INTO canchas (
                nombre, tipo_superficie, capacidad_jugadores,
                precio_hora, estado, descripcion, creado_por
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["nombre"],
                        datos["tipo_superficie"],
                        datos["capacidad_jugadores"],
                        datos["precio_hora"],
                        datos["estado"],
                        datos["descripcion"],
                        creado_por,
                    ),
                )
                return cur.fetchone()

    def actualizar_cancha(
        self, id_cancha: int, datos: dict, modificado_por: int
    ) -> dict | None:
        query = """
            UPDATE canchas
            SET nombre = %s,
                tipo_superficie = %s,
                capacidad_jugadores = %s,
                precio_hora = %s,
                estado = %s,
                descripcion = %s,
                modificado_por = %s
            WHERE id_cancha = %s
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["nombre"],
                        datos["tipo_superficie"],
                        datos["capacidad_jugadores"],
                        datos["precio_hora"],
                        datos["estado"],
                        datos["descripcion"],
                        modificado_por,
                        id_cancha,
                    ),
                )
                return cur.fetchone()

    def desactivar_cancha(self, id_cancha: int, modificado_por: int) -> dict | None:
        query = """
            UPDATE canchas
            SET estado = 'inactiva', modificado_por = %s
            WHERE id_cancha = %s
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (modificado_por, id_cancha))
                return cur.fetchone()

    # ======================= SERVICIOS =======================
    def listar_servicios(self, solo_activos: bool = True) -> list[dict]:
        query = "SELECT * FROM servicios"
        if solo_activos:
            query += " WHERE activo = TRUE"
        query += " ORDER BY id_servicio;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query)
                return cur.fetchall()

    def obtener_servicio_por_id(self, id_servicio: int) -> dict | None:
        query = "SELECT * FROM servicios WHERE id_servicio = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_servicio,))
                return cur.fetchone()

    def obtener_servicio_por_nombre(self, nombre: str) -> dict | None:
        query = "SELECT * FROM servicios WHERE LOWER(nombre) = LOWER(%s);"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (nombre,))
                return cur.fetchone()

    def crear_servicio(self, datos: dict, creado_por: int) -> dict:
        query = """
            INSERT INTO servicios (
                nombre, descripcion, duracion_minutos, precio_adicional, creado_por
            )
            VALUES (%s, %s, %s, %s, %s)
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["nombre"],
                        datos["descripcion"],
                        datos["duracion_minutos"],
                        datos["precio_adicional"],
                        creado_por,
                    ),
                )
                return cur.fetchone()

    def actualizar_servicio(
        self, id_servicio: int, datos: dict, modificado_por: int
    ) -> dict | None:
        query = """
            UPDATE servicios
            SET nombre = %s,
                descripcion = %s,
                duracion_minutos = %s,
                precio_adicional = %s,
                activo = %s,
                modificado_por = %s
            WHERE id_servicio = %s
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["nombre"],
                        datos["descripcion"],
                        datos["duracion_minutos"],
                        datos["precio_adicional"],
                        datos["activo"],
                        modificado_por,
                        id_servicio,
                    ),
                )
                return cur.fetchone()

    def desactivar_servicio(
        self, id_servicio: int, modificado_por: int
    ) -> dict | None:
        query = """
            UPDATE servicios
            SET activo = FALSE, modificado_por = %s
            WHERE id_servicio = %s
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (modificado_por, id_servicio))
                return cur.fetchone()

    # =============== HORARIOS DE DISPONIBILIDAD ===============
    def listar_horarios_por_cancha(self, id_cancha: int) -> list[dict]:
        query = """
            SELECT * FROM horarios_disponibilidad
            WHERE id_cancha = %s
            ORDER BY dia_semana;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cancha,))
                return cur.fetchall()

    def obtener_horario_por_id(self, id_horario: int) -> dict | None:
        query = "SELECT * FROM horarios_disponibilidad WHERE id_horario = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_horario,))
                return cur.fetchone()

    def obtener_horario_cancha_dia(
        self, id_cancha: int, dia_semana: int
    ) -> dict | None:
        query = """
            SELECT * FROM horarios_disponibilidad
            WHERE id_cancha = %s AND dia_semana = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cancha, dia_semana))
                return cur.fetchone()

    def crear_horario(self, datos: dict, creado_por: int) -> dict:
        query = """
            INSERT INTO horarios_disponibilidad (
                id_cancha, dia_semana, hora_apertura, hora_cierre, activo, creado_por
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["id_cancha"],
                        datos["dia_semana"],
                        datos["hora_apertura"],
                        datos["hora_cierre"],
                        datos["activo"],
                        creado_por,
                    ),
                )
                return cur.fetchone()

    def actualizar_horario(
        self, id_horario: int, datos: dict, modificado_por: int
    ) -> dict | None:
        query = """
            UPDATE horarios_disponibilidad
            SET hora_apertura = %s,
                hora_cierre = %s,
                activo = %s,
                modificado_por = %s
            WHERE id_horario = %s
            RETURNING *;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["hora_apertura"],
                        datos["hora_cierre"],
                        datos["activo"],
                        modificado_por,
                        id_horario,
                    ),
                )
                return cur.fetchone()

    def eliminar_horario(self, id_horario: int) -> bool:
        query = "DELETE FROM horarios_disponibilidad WHERE id_horario = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_horario,))
                return cur.rowcount > 0