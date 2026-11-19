-- 1. Roles obligatorios
INSERT INTO roles (nombre, descripcion) VALUES
('administrador', 'Control total del sistema, usuarios, canchas, horarios y reportes'),
('recepcionista', 'Gestión de reservas, agenda, clientes y registro de pagos'),
('cliente', 'Consulta de disponibilidad y registro de reservas en línea');

-- 2. Usuarios de prueba (1 por cada rol)
-- IMPORTANTE: Cuando conectes tu backend, reemplaza estos placeholders
-- con hashes reales generados con bcrypt o Argon2 (requisito de seguridad).
INSERT INTO usuarios (id_rol, correo, password_hash) VALUES
(1, 'admin@cancha.com', '$2b$10$PLACEHOLDER_HASH_ADMIN_REEMPLAZAR'),
(2, 'recepcion@cancha.com', '$2b$10$PLACEHOLDER_HASH_RECEPCION_REEMPLAZAR'),
(3, 'cliente@cancha.com', '$2b$10$PLACEHOLDER_HASH_CLIENTE_REEMPLAZAR');

-- 3. Empleado y Cliente de ejemplo
INSERT INTO empleados (id_usuario, nombres, apellidos, ci, telefono, cargo, creado_por) VALUES
(2, 'Carlos', 'Mendoza', '8451203', '70011223', 'Recepcionista Turno Tarde', 1);

INSERT INTO clientes (id_usuario, nombres, apellidos, ci_nit, telefono, creado_por) VALUES
(3, 'Luis', 'Fernández', '9123456', '75544332', 1);

-- 4. Canchas deportivas
INSERT INTO canchas (nombre, tipo_superficie, capacidad_jugadores, precio_hora, descripcion, creado_por) VALUES
('Cancha 1 - Fútbol 5', 'Césped sintético', 10, 120.00, 'Cancha techada con iluminación LED', 1),
('Cancha 2 - Fútbol 7', 'Césped sintético', 14, 180.00, 'Cancha amplia al aire libre con reflectores', 1);

-- 5. Servicios
INSERT INTO servicios (nombre, descripcion, duracion_minutos, precio_adicional, creado_por) VALUES
('Alquiler Diurno (1 hora)', 'Uso de cancha en horario diurno sin iluminación', 60, 0.00, 1),
('Alquiler Nocturno con Luz (1 hora)', 'Uso de cancha con reflectores encendidos', 60, 30.00, 1),
('Paquete Partido + Balón y Chalecos (2 horas)', 'Dos horas de juego con indumentaria incluida', 120, 40.00, 1);

-- 6. Horarios de atención (Lunes=1 a Domingo=7, de 08:00 a 23:00 para ambas canchas)
INSERT INTO horarios_disponibilidad (id_cancha, dia_semana, hora_apertura, hora_cierre, creado_por)
SELECT c.id_cancha, d.dia, '08:00'::TIME, '23:00'::TIME, 1
FROM canchas c
CROSS JOIN generate_series(1, 7) AS d(dia);

-- 7. Reglas de negocio configurables
INSERT INTO configuracion_negocio (clave, valor, descripcion, modificado_por) VALUES
('plazo_minimo_cancelacion_horas', '2', 'Horas mínimas de anticipación permitidas para cancelar o reprogramar una reserva', 1),
('porcentaje_anticipo_minimo', '50', 'Porcentaje mínimo de anticipo para confirmar una reserva', 1);

-- 8. Reservas de ejemplo (sin choques de horario)
INSERT INTO reservas (
    codigo_reserva, id_cliente, id_cancha, id_servicio, id_empleado,
    fecha_reserva, hora_inicio, hora_fin, estado, monto_total, observaciones, creado_por
) VALUES
('RES-2026-0001', 1, 1, 2, 1, CURRENT_DATE + 1, '19:00', '20:00', 'confirmada', 150.00, 'Pagó anticipo por QR', 2),
('RES-2026-0002', 1, 1, 1, 1, CURRENT_DATE + 1, '20:00', '21:00', 'pendiente', 120.00, 'Reserva solicitada por portal', 3);

-- 9. Pago de anticipo de ejemplo
INSERT INTO pagos (id_reserva, monto, tipo_pago, metodo_pago, referencia_comprobante, registrado_por) VALUES
(1, 75.00, 'anticipo', 'qr', 'QR-884512', 2);