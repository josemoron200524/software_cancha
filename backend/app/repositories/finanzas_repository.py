from datetime import date
from app.core.database import get_db_connection


class FinanzasRepository:
    # ======================== APOYO RESERVAS / CLIENTES ========================
    def obtener_reserva(self, id_reserva: int) -> dict | None:
        query = """
            SELECT id_reserva, codigo_reserva, id_cliente, estado, monto_total
            FROM reservas
            WHERE id_reserva = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_reserva,))
                return cur.fetchone()

    def obtener_cliente_por_usuario(self, id_usuario: int) -> dict | None:
        query = "SELECT id_cliente FROM clientes WHERE id_usuario = %s;"
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_usuario,))
                return cur.fetchone()

    # ======================== PAGOS ========================
    def listar_pagos(
        self,
        fecha_desde: date | None = None,
        fecha_hasta: date | None = None,
        metodo_pago: str | None = None,
    ) -> list[dict]:
        condiciones = []
        parametros: list = []

        if fecha_desde:
            condiciones.append("p.fecha_pago::DATE >= %s")
            parametros.append(fecha_desde)
        if fecha_hasta:
            condiciones.append("p.fecha_pago::DATE <= %s")
            parametros.append(fecha_hasta)
        if metodo_pago:
            condiciones.append("p.metodo_pago = %s")
            parametros.append(metodo_pago)

        where_sql = f"WHERE {' AND '.join(condiciones)}" if condiciones else ""
        query = f"""
            SELECT p.id_pago, p.id_reserva, r.codigo_reserva,
                   c.nombres || ' ' || c.apellidos AS cliente_nombre,
                   p.monto, p.tipo_pago, p.metodo_pago,
                   p.referencia_comprobante, p.fecha_pago, p.registrado_por
            FROM pagos p
            INNER JOIN reservas r ON p.id_reserva = r.id_reserva
            INNER JOIN clientes c ON r.id_cliente = c.id_cliente
            {where_sql}
            ORDER BY p.fecha_pago DESC, p.id_pago DESC;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchall()

    def listar_pagos_por_reserva(self, id_reserva: int) -> list[dict]:
        query = """
            SELECT id_pago, id_reserva, monto, tipo_pago, metodo_pago,
                   referencia_comprobante, fecha_pago, registrado_por
            FROM pagos
            WHERE id_reserva = %s
            ORDER BY fecha_pago ASC, id_pago ASC;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_reserva,))
                return cur.fetchall()

    def obtener_total_pagado_reserva(self, id_reserva: int) -> float:
        query = """
            SELECT COALESCE(SUM(monto), 0) AS total_pagado
            FROM pagos
            WHERE id_reserva = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (id_reserva,))
                return float(cur.fetchone()["total_pagado"])

    def registrar_pago(
        self, datos: dict, confirmar_reserva: bool = False
    ) -> dict:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO pagos (
                        id_reserva, monto, tipo_pago, metodo_pago,
                        referencia_comprobante, registrado_por
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id_pago, id_reserva, monto, tipo_pago, metodo_pago,
                              referencia_comprobante, fecha_pago, registrado_por;
                    """,
                    (
                        datos["id_reserva"],
                        datos["monto"],
                        datos["tipo_pago"],
                        datos["metodo_pago"],
                        datos["referencia_comprobante"],
                        datos["registrado_por"],
                    ),
                )
                pago = cur.fetchone()

                if confirmar_reserva:
                    cur.execute(
                        """
                        UPDATE reservas
                        SET estado = 'confirmada', modificado_por = %s
                        WHERE id_reserva = %s AND estado = 'pendiente';
                        """,
                        (datos["registrado_por"], datos["id_reserva"]),
                    )

                return pago

    # ======================== CONFIGURACIÓN DE NEGOCIO ========================
    def listar_configuraciones(self) -> list[dict]:
        query = """
            SELECT id_config, clave, valor, descripcion,
                   modificado_por, fecha_modificacion
            FROM configuracion_negocio
            ORDER BY id_config;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query)
                return cur.fetchall()

    def obtener_configuracion(self, clave: str) -> dict | None:
        query = """
            SELECT id_config, clave, valor, descripcion,
                   modificado_por, fecha_modificacion
            FROM configuracion_negocio
            WHERE clave = %s;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (clave,))
                return cur.fetchone()

    def actualizar_configuracion(
        self,
        clave: str,
        valor: str,
        descripcion: str | None,
        modificado_por: int,
    ) -> dict | None:
        query = """
            UPDATE configuracion_negocio
            SET valor = %s,
                descripcion = COALESCE(%s, descripcion),
                modificado_por = %s,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE clave = %s
            RETURNING id_config, clave, valor, descripcion,
                      modificado_por, fecha_modificacion;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (valor, descripcion, modificado_por, clave))
                return cur.fetchone()

    # ======================== REPORTES Y KPIs ========================
    def obtener_resumen_reservas(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> dict:
        condiciones = []
        parametros: list = []

        if fecha_desde:
            condiciones.append("fecha_reserva >= %s")
            parametros.append(fecha_desde)
        if fecha_hasta:
            condiciones.append("fecha_reserva <= %s")
            parametros.append(fecha_hasta)

        where_sql = f"WHERE {' AND '.join(condiciones)}" if condiciones else ""
        query = f"""
            SELECT COUNT(*) AS total_reservas,
                   COUNT(*) FILTER (WHERE estado = 'pendiente') AS pendientes,
                   COUNT(*) FILTER (WHERE estado = 'confirmada') AS confirmadas,
                   COUNT(*) FILTER (WHERE estado = 'atendida') AS atendidas,
                   COUNT(*) FILTER (WHERE estado = 'cancelada') AS canceladas,
                   COUNT(*) FILTER (WHERE estado = 'no_asistio') AS no_asistio,
                   COALESCE(
                       SUM(monto_total) FILTER (WHERE estado IN ('pendiente', 'confirmada', 'atendida')),
                       0
                   ) AS monto_proyectado
            FROM reservas
            {where_sql};
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchone()

    def obtener_ingresos_por_metodo(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> list[dict]:
        condiciones = []
        parametros: list = []

        if fecha_desde:
            condiciones.append("fecha_pago::DATE >= %s")
            parametros.append(fecha_desde)
        if fecha_hasta:
            condiciones.append("fecha_pago::DATE <= %s")
            parametros.append(fecha_hasta)

        where_sql = f"WHERE {' AND '.join(condiciones)}" if condiciones else ""
        query = f"""
            SELECT metodo_pago,
                   COUNT(*) AS cantidad_pagos,
                   COALESCE(SUM(monto), 0) AS total_recaudado
            FROM pagos
            {where_sql}
            GROUP BY metodo_pago
            ORDER BY total_recaudado DESC;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchall()

    def obtener_reporte_por_cancha(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> list[dict]:
        filtros_join = []
        parametros: list = []

        if fecha_desde:
            filtros_join.append("r.fecha_reserva >= %s")
            parametros.append(fecha_desde)
        if fecha_hasta:
            filtros_join.append("r.fecha_reserva <= %s")
            parametros.append(fecha_hasta)

        extra_on = f" AND {' AND '.join(filtros_join)}" if filtros_join else ""
        query = f"""
            SELECT c.id_cancha, c.nombre AS cancha_nombre, c.estado,
                   COUNT(r.id_reserva) AS total_reservas,
                   COUNT(r.id_reserva) FILTER (WHERE r.estado = 'atendida') AS atendidas,
                   COUNT(r.id_reserva) FILTER (WHERE r.estado = 'cancelada') AS canceladas,
                   COALESCE(
                       SUM(r.monto_total) FILTER (WHERE r.estado IN ('pendiente', 'confirmada', 'atendida')),
                       0
                   ) AS monto_proyectado
            FROM canchas c
            LEFT JOIN reservas r ON c.id_cancha = r.id_cancha{extra_on}
            GROUP BY c.id_cancha, c.nombre, c.estado
            ORDER BY total_reservas DESC, c.id_cancha ASC;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchall()

    def obtener_reporte_por_servicio(
        self, fecha_desde: date | None = None, fecha_hasta: date | None = None
    ) -> list[dict]:
        filtros_join = []
        parametros: list = []

        if fecha_desde:
            filtros_join.append("r.fecha_reserva >= %s")
            parametros.append(fecha_desde)
        if fecha_hasta:
            filtros_join.append("r.fecha_reserva <= %s")
            parametros.append(fecha_hasta)

        extra_on = f" AND {' AND '.join(filtros_join)}" if filtros_join else ""
        query = f"""
            SELECT s.id_servicio, s.nombre AS servicio_nombre, s.activo,
                   COUNT(r.id_reserva) AS total_reservas,
                   COUNT(r.id_reserva) FILTER (WHERE r.estado = 'atendida') AS atendidas,
                   COUNT(r.id_reserva) FILTER (WHERE r.estado = 'cancelada') AS canceladas,
                   COALESCE(
                       SUM(r.monto_total) FILTER (WHERE r.estado IN ('pendiente', 'confirmada', 'atendida')),
                       0
                   ) AS monto_proyectado
            FROM servicios s
            LEFT JOIN reservas r ON s.id_servicio = r.id_servicio{extra_on}
            GROUP BY s.id_servicio, s.nombre, s.activo
            ORDER BY total_reservas DESC, s.id_servicio ASC;
        """
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(parametros))
                return cur.fetchall()