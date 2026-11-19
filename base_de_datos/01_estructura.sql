-- ============================================================================
-- PROYECTO FINAL: SISTEMA DE RESERVAS DE CANCHAS DEPORTIVAS (TEMA 1)
-- MOTOR: PostgreSQL (Neon) - Normalizado en 3FN
-- ============================================================================

-- 1. ROLES DEL SISTEMA (Administrador, Recepcionista, Cliente)
CREATE TABLE roles (
    id_rol SERIAL PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL UNIQUE,
    descripcion VARCHAR(150)
);

-- 2. USUARIOS (Autenticación, hash de contraseñas y control de roles)
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    id_rol INT NOT NULL REFERENCES roles(id_rol) ON UPDATE CASCADE ON DELETE RESTRICT,
    correo VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. CLIENTES (Pueden tener cuenta en el portal web o ser registrados en recepción)
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    id_usuario INT UNIQUE REFERENCES usuarios(id_usuario) ON UPDATE CASCADE ON DELETE SET NULL,
    nombres VARCHAR(80) NOT NULL,
    apellidos VARCHAR(80) NOT NULL,
    ci_nit VARCHAR(25) UNIQUE,
    telefono VARCHAR(25) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por INT REFERENCES usuarios(id_usuario),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. EMPLEADOS / RECEPCIONISTAS
CREATE TABLE empleados (
    id_empleado SERIAL PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE REFERENCES usuarios(id_usuario) ON UPDATE CASCADE ON DELETE RESTRICT,
    nombres VARCHAR(80) NOT NULL,
    apellidos VARCHAR(80) NOT NULL,
    ci VARCHAR(25) NOT NULL UNIQUE,
    telefono VARCHAR(25) NOT NULL,
    cargo VARCHAR(50) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por INT REFERENCES usuarios(id_usuario),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. CANCHAS DEPORTIVAS
CREATE TABLE canchas (
    id_cancha SERIAL PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    tipo_superficie VARCHAR(50) NOT NULL, -- Ej: Césped sintético, Futsal, Polifuncional
    capacidad_jugadores INT NOT NULL CHECK (capacidad_jugadores > 0),
    precio_hora NUMERIC(10, 2) NOT NULL CHECK (precio_hora >= 0),
    estado VARCHAR(20) NOT NULL DEFAULT 'disponible'
        CHECK (estado IN ('disponible', 'mantenimiento', 'inactiva')),
    descripcion TEXT,
    creado_por INT REFERENCES usuarios(id_usuario),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. SERVICIOS (Necesario para CRUD de servicios y reporte de reservas por servicio)
CREATE TABLE servicios (
    id_servicio SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE, -- Ej: Alquiler Diurno 1h, Alquiler Nocturno con Luz 1h
    descripcion TEXT,
    duracion_minutos INT NOT NULL CHECK (duracion_minutos > 0),
    precio_adicional NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (precio_adicional >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por INT REFERENCES usuarios(id_usuario),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7. HORARIOS DE ATENCIÓN Y DISPONIBILIDAD POR CANCHA
CREATE TABLE horarios_disponibilidad (
    id_horario SERIAL PRIMARY KEY,
    id_cancha INT NOT NULL REFERENCES canchas(id_cancha) ON UPDATE CASCADE ON DELETE CASCADE,
    dia_semana SMALLINT NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- 1=Lunes ... 7=Domingo
    hora_apertura TIME NOT NULL,
    hora_cierre TIME NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por INT REFERENCES usuarios(id_usuario),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_horario_valido CHECK (hora_cierre > hora_apertura),
    CONSTRAINT uq_cancha_dia UNIQUE (id_cancha, dia_semana)
);

-- 8. CONFIGURACIÓN DE REGLAS DE NEGOCIO (Ej: plazo mínimo de cancelación en horas)
CREATE TABLE configuracion_negocio (
    id_config SERIAL PRIMARY KEY,
    clave VARCHAR(60) NOT NULL UNIQUE,
    valor VARCHAR(100) NOT NULL,
    descripcion VARCHAR(200),
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 9. RESERVAS (Entidad principal con los 5 estados obligatorios y auditoría)
CREATE TABLE reservas (
    id_reserva SERIAL PRIMARY KEY,
    codigo_reserva VARCHAR(20) NOT NULL UNIQUE,
    id_cliente INT NOT NULL REFERENCES clientes(id_cliente) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_cancha INT NOT NULL REFERENCES canchas(id_cancha) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_servicio INT NOT NULL REFERENCES servicios(id_servicio) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_empleado INT REFERENCES empleados(id_empleado) ON UPDATE CASCADE ON DELETE SET NULL,
    fecha_reserva DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'confirmada', 'cancelada', 'atendida', 'no_asistio')),
    monto_total NUMERIC(10, 2) NOT NULL CHECK (monto_total >= 0),
    motivo_cancelacion TEXT,
    observaciones TEXT,
    creado_por INT NOT NULL REFERENCES usuarios(id_usuario),
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_por INT REFERENCES usuarios(id_usuario),
    fecha_modificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rango_horas_reserva CHECK (hora_fin > hora_inicio)
);

-- 10. PAGOS Y ANTICIPOS (Módulo opcional para puntos extra en alcance)
CREATE TABLE pagos (
    id_pago SERIAL PRIMARY KEY,
    id_reserva INT NOT NULL REFERENCES reservas(id_reserva) ON UPDATE CASCADE ON DELETE RESTRICT,
    monto NUMERIC(10, 2) NOT NULL CHECK (monto > 0),
    tipo_pago VARCHAR(20) NOT NULL CHECK (tipo_pago IN ('anticipo', 'saldo', 'total')),
    metodo_pago VARCHAR(25) NOT NULL CHECK (metodo_pago IN ('efectivo', 'qr', 'transferencia', 'tarjeta')),
    referencia_comprobante VARCHAR(80),
    fecha_pago TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    registrado_por INT NOT NULL REFERENCES usuarios(id_usuario)
);

-- ============================================================================
-- ÍNDICES PARA AGILIZAR LA AGENDA DIARIA/SEMANAL Y REPORTES
-- ============================================================================
CREATE INDEX idx_reservas_cancha_fecha ON reservas(id_cancha, fecha_reserva);
CREATE INDEX idx_reservas_estado ON reservas(estado);
CREATE INDEX idx_reservas_cliente ON reservas(id_cliente);
CREATE INDEX idx_pagos_reserva ON pagos(id_reserva);

-- ============================================================================
-- TRIGGER 1: VALIDACIÓN DE CHOQUES DE HORARIO A NIVEL DE BASE DE DATOS
-- Evita que se solapen dos reservas activas en la misma cancha y fecha
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_validar_choque_reserva()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado IN ('pendiente', 'confirmada', 'atendida') THEN
        IF EXISTS (
            SELECT 1
            FROM reservas r
            WHERE r.id_cancha = NEW.id_cancha
              AND r.fecha_reserva = NEW.fecha_reserva
              AND r.estado IN ('pendiente', 'confirmada', 'atendida')
              AND r.id_reserva <> COALESCE(NEW.id_reserva, -1)
              AND NEW.hora_inicio < r.hora_fin
              AND NEW.hora_fin > r.hora_inicio
        ) THEN
            RAISE EXCEPTION 'Choque de horario: la cancha ya tiene una reserva activa en ese rango.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_choque_reserva
BEFORE INSERT OR UPDATE ON reservas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_choque_reserva();

-- ============================================================================
-- TRIGGER 2: ACTUALIZACIÓN AUTOMÁTICA DE fecha_modificacion (AUDITORÍA)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_mod AFTER UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();
CREATE TRIGGER trg_clientes_mod BEFORE UPDATE ON clientes FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();
CREATE TRIGGER trg_empleados_mod BEFORE UPDATE ON empleados FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();
CREATE TRIGGER trg_canchas_mod BEFORE UPDATE ON canchas FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();
CREATE TRIGGER trg_servicios_mod BEFORE UPDATE ON servicios FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();
CREATE TRIGGER trg_horarios_mod BEFORE UPDATE ON horarios_disponibilidad FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();
CREATE TRIGGER trg_reservas_mod BEFORE UPDATE ON reservas FOR EACH ROW EXECUTE FUNCTION fn_actualizar_fecha_modificacion();