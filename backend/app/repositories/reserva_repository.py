from datetime import date, time
from app.core.database import get_db_connection


class ReservaRepository:
    # ======================== CONSULTAS DE APOYO ========================
    def obtener_cliente_por_usuario(self, id_usuario: int) -> dict | None:
        query = "SELECT * FROM clientes WHERE id_usuario = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_usuario,))
                return cur.fetchone()

    def obtener_cliente_por_id(self, id_cliente: int) -> dict | None:
        query = "SELECT * FROM clientes WHERE id_cliente = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cliente,))
                return cur.fetchone()

    def obtener_empleado_por_usuario(self, id_usuario: int) -> dict | None:
        query = "SELECT * FROM empleados WHERE id_usuario = %s AND activo = TRUE;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_usuario,))
                return cur.fetchone()

    def obtener_cancha(self, id_cancha: int) -> dict | None:
        query = "SELECT * FROM canchas WHERE id_cancha = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cancha,))
                return cur.fetchone()

    def obtener_servicio(self, id_servicio: int) -> dict | None:
        query = "SELECT * FROM servicios WHERE id_servicio = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_servicio,))
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

    def obtener_configuracion(self, clave: str) -> str | None:
        query = "SELECT valor FROM configuracion_negocio WHERE clave = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (clave,))
                fila = cur.fetchone()
                return fila["valor"] if fila else None

    def obtener_siguiente_correlativo(self, anio: int) -> int:
        query = """
            SELECT COALESCE(
                MAX(CAST(SPLIT_PART(codigo_reserva, '-', 3) AS INT)),
                0
            ) + 1 AS siguiente
            FROM reservas
            WHERE codigo_reserva LIKE %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (f"RES-{anio}-%",))
                return cur.fetchone()["siguiente"]

    # ======================== DISPONIBILIDAD Y CHOQUES ========================
    def listar_bloques_ocupados(
        self, id_cancha: int, fecha_reserva: date
    ) -> list[dict]:
        query = """
            SELECT id_reserva, codigo_reserva, hora_inicio, hora_fin, estado
            FROM reservas
            WHERE id_cancha = %s
              AND fecha_reserva = %s
              AND estado IN ('pendiente', 'confirmada', 'atendida')
            ORDER BY hora_inicio;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_cancha, fecha_reserva))
                return cur.fetchall()

    def existe_choque_horario(
        self,
        id_cancha: int,
        fecha_reserva: date,
        hora_inicio: time,
        hora_fin: time,
        excluir_id_reserva: int | None = None,
    ) -> bool:
        query = """
            SELECT 1
            FROM reservas
            WHERE id_cancha = %s
              AND fecha_reserva = %s
              AND estado IN ('pendiente', 'confirmada', 'atendida')
              AND id_reserva <> %s
              AND %s < hora_fin
              AND %s > hora_inicio;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        id_cancha,
                        fecha_reserva,
                        excluir_id_reserva if excluir_id_reserva is not None else -1,
                        hora_inicio,
                        hora_fin,
                    ),
                )
                return cur.fetchone() is not None

    # ======================== CRUD Y GESTIÓN DE RESERVAS ========================
    def listar_reservas(
        self,
        fecha_desde: date | None = None,
        fecha_hasta: date | None = None,
        id_cancha: int | None = None,
        estado: str | None = None,
        id_cliente: int | None = None,
    ) -> list[dict]:
        condiciones = []
        parametros: list = []

        if fecha_desde:
            condiciones.append("r.fecha_reserva >= %s")
            parametros.append(fecha_desde)
        if fecha_hasta:
            condiciones.append("r.fecha_reserva <= %s")
            parametros.append(fecha_hasta)
        if id_cancha:
            condiciones.append("r.id_cancha = %s")
            parametros.append(id_cancha)
        if estado:
            condiciones.append("r.estado = %s")
            parametros.append(estado)
        if id_cliente:
            condiciones.append("r.id_cliente = %s")
            parametros.append(id_cliente)

        where_sql = f"WHERE {' AND '.join(condiciones)}" if condiciones else ""
        query = f"""
            SELECT r.id_reserva, r.codigo_reserva, r.id_cliente,
                   c.nombres || ' ' || c.apellidos AS cliente_nombre,
                   c.telefono AS cliente_telefono,
                   r.id_cancha, ca.nombre AS cancha_nombre,
                   r.id_servicio, s.nombre AS servicio_nombre,
                   r.id_empleado, r.fecha_reserva, r.hora_inicio, r.hora_fin,
                   r.estado, r.monto_total, r.motivo_cancelacion,
                   r.observaciones, r.fecha_creacion, r.fecha_modificacion
            FROM reservas r
            INNER JOIN clientes c ON r.id_cliente = c.id_cliente
            INNER JOIN canchas ca ON r.id_cancha = ca.id_cancha
            INNER JOIN servicios s ON r.id_servicio = s.id_servicio
            {where_sql}
            ORDER BY r.fecha_reserva DESC, r.hora_inicio ASC;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchall()

    def obtener_reserva_por_id(self, id_reserva: int) -> dict | None:
        query = """
            SELECT r.id_reserva, r.codigo_reserva, r.id_cliente,
                   c.nombres || ' ' || c.apellidos AS cliente_nombre,
                   c.telefono AS cliente_telefono,
                   r.id_cancha, ca.nombre AS cancha_nombre,
                   r.id_servicio, s.nombre AS servicio_nombre,
                   r.id_empleado, r.fecha_reserva, r.hora_inicio, r.hora_fin,
                   r.estado, r.monto_total, r.motivo_cancelacion,
                   r.observaciones, r.creado_por, r.fecha_creacion,
                   r.modificado_por, r.fecha_modificacion
            FROM reservas r
            INNER JOIN clientes c ON r.id_cliente = c.id_cliente
            INNER JOIN canchas ca ON r.id_cancha = ca.id_cancha
            INNER JOIN servicios s ON r.id_servicio = s.id_servicio
            WHERE r.id_reserva = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_reserva,))
                return cur.fetchone()

    def crear_reserva(self, datos: dict) -> dict:
        query = """
            INSERT INTO reservas (
                codigo_reserva, id_cliente, id_cancha, id_servicio, id_empleado,
                fecha_reserva, hora_inicio, hora_fin, estado, monto_total,
                observaciones, creado_por
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'pendiente', %s, %s, %s)
            RETURNING id_reserva;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["codigo_reserva"],
                        datos["id_cliente"],
                        datos["id_cancha"],
                        datos["id_servicio"],
                        datos["id_empleado"],
                        datos["fecha_reserva"],
                        datos["hora_inicio"],
                        datos["hora_fin"],
                        datos["monto_total"],
                        datos["observaciones"],
                        datos["creado_por"],
                    ),
                )
                id_nuevo = cur.fetchone()["id_reserva"]
        return self.obtener_reserva_por_id(id_nuevo)

    def reprogramar_reserva(self, id_reserva: int, datos: dict) -> dict | None:
        query = """
            UPDATE reservas
            SET id_cancha = %s,
                id_servicio = %s,
                fecha_reserva = %s,
                hora_inicio = %s,
                hora_fin = %s,
                monto_total = %s,
                observaciones = %s,
                modificado_por = %s
            WHERE id_reserva = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (
                        datos["id_cancha"],
                        datos["id_servicio"],
                        datos["fecha_reserva"],
                        datos["hora_inicio"],
                        datos["hora_fin"],
                        datos["monto_total"],
                        datos["observaciones"],
                        datos["modificado_por"],
                        id_reserva,
                    ),
                )
        return self.obtener_reserva_por_id(id_reserva)

    def actualizar_estado(
        self,
        id_reserva: int,
        nuevo_estado: str,
        motivo_cancelacion: str | None,
        modificado_por: int,
    ) -> dict | None:
        query = """
            UPDATE reservas
            SET estado = %s,
                motivo_cancelacion = COALESCE(%s, motivo_cancelacion),
                modificado_por = %s
            WHERE id_reserva = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    query,
                    (nuevo_estado, motivo_cancelacion, modificado_por, id_reserva),
                )
        return self.obtener_reserva_por_id(id_reserva)