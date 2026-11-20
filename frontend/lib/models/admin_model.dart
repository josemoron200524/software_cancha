double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

// ======================== REPORTES Y KPIs ========================
class IngresoMetodo {
  final String metodoPago;
  final int cantidadPagos;
  final double totalRecaudado;

  const IngresoMetodo({
    required this.metodoPago,
    required this.cantidadPagos,
    required this.totalRecaudado,
  });

  factory IngresoMetodo.fromJson(Map<String, dynamic> json) {
    return IngresoMetodo(
      metodoPago: (json['metodo_pago'] ?? '').toString(),
      cantidadPagos: _toInt(json['cantidad_pagos']),
      totalRecaudado: _toDouble(json['total_recaudado']),
    );
  }
}

class ReporteResumen {
  final int totalReservas;
  final int pendientes;
  final int confirmadas;
  final int atendidas;
  final int canceladas;
  final int noAsistio;
  final double tasaCancelacion;
  final double tasaAsistencia;
  final double montoProyectado;
  final double totalRecaudado;
  final List<IngresoMetodo> ingresosPorMetodo;

  const ReporteResumen({
    required this.totalReservas,
    required this.pendientes,
    required this.confirmadas,
    required this.atendidas,
    required this.canceladas,
    required this.noAsistio,
    required this.tasaCancelacion,
    required this.tasaAsistencia,
    required this.montoProyectado,
    required this.totalRecaudado,
    required this.ingresosPorMetodo,
  });

  factory ReporteResumen.fromJson(Map<String, dynamic> json) {
    final reservas = json['reservas'] as Map<String, dynamic>? ?? {};
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final metodosRaw = json['ingresos_por_metodo'] as List? ?? [];

    return ReporteResumen(
      totalReservas: _toInt(reservas['total']),
      pendientes: _toInt(reservas['pendientes']),
      confirmadas: _toInt(reservas['confirmadas']),
      atendidas: _toInt(reservas['atendidas']),
      canceladas: _toInt(reservas['canceladas']),
      noAsistio: _toInt(reservas['no_asistio']),
      tasaCancelacion: _toDouble(kpis['tasa_cancelacion_porcentaje']),
      tasaAsistencia: _toDouble(kpis['tasa_asistencia_porcentaje']),
      montoProyectado: _toDouble(kpis['monto_proyectado_reservas']),
      totalRecaudado: _toDouble(kpis['total_recaudado_pagos']),
      ingresosPorMetodo: metodosRaw
          .map((e) => IngresoMetodo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReporteCancha {
  final int idCancha;
  final String canchaNombre;
  final String estado;
  final int totalReservas;
  final int atendidas;
  final int canceladas;
  final double montoProyectado;

  const ReporteCancha({
    required this.idCancha,
    required this.canchaNombre,
    required this.estado,
    required this.totalReservas,
    required this.atendidas,
    required this.canceladas,
    required this.montoProyectado,
  });

  factory ReporteCancha.fromJson(Map<String, dynamic> json) {
    return ReporteCancha(
      idCancha: _toInt(json['id_cancha']),
      canchaNombre: (json['cancha_nombre'] ?? '').toString(),
      estado: (json['estado'] ?? '').toString(),
      totalReservas: _toInt(json['total_reservas']),
      atendidas: _toInt(json['atendidas']),
      canceladas: _toInt(json['canceladas']),
      montoProyectado: _toDouble(json['monto_proyectado']),
    );
  }
}

class ReporteServicio {
  final int idServicio;
  final String servicioNombre;
  final bool activo;
  final int totalReservas;
  final int atendidas;
  final int canceladas;
  final double montoProyectado;

  const ReporteServicio({
    required this.idServicio,
    required this.servicioNombre,
    required this.activo,
    required this.totalReservas,
    required this.atendidas,
    required this.canceladas,
    required this.montoProyectado,
  });

  factory ReporteServicio.fromJson(Map<String, dynamic> json) {
    return ReporteServicio(
      idServicio: _toInt(json['id_servicio']),
      servicioNombre: (json['servicio_nombre'] ?? '').toString(),
      activo: json['activo'] == null ? true : json['activo'] as bool,
      totalReservas: _toInt(json['total_reservas']),
      atendidas: _toInt(json['atendidas']),
      canceladas: _toInt(json['canceladas']),
      montoProyectado: _toDouble(json['monto_proyectado']),
    );
  }
}

// ======================== CATÁLOGOS ADMIN ========================
class CanchaAdmin {
  final int idCancha;
  final String nombre;
  final String tipoSuperficie;
  final int capacidadJugadores;
  final double precioHora;
  final String estado;
  final String? descripcion;

  const CanchaAdmin({
    required this.idCancha,
    required this.nombre,
    required this.tipoSuperficie,
    required this.capacidadJugadores,
    required this.precioHora,
    required this.estado,
    this.descripcion,
  });

  factory CanchaAdmin.fromJson(Map<String, dynamic> json) {
    return CanchaAdmin(
      idCancha: _toInt(json['id_cancha']),
      nombre: (json['nombre'] ?? '').toString(),
      tipoSuperficie: (json['tipo_superficie'] ?? '').toString(),
      capacidadJugadores: _toInt(json['capacidad_jugadores']),
      precioHora: _toDouble(json['precio_hora']),
      estado: (json['estado'] ?? 'disponible').toString(),
      descripcion: json['descripcion']?.toString(),
    );
  }
}

class ServicioAdmin {
  final int idServicio;
  final String nombre;
  final String? descripcion;
  final int duracionMinutos;
  final double precioAdicional;
  final bool activo;

  const ServicioAdmin({
    required this.idServicio,
    required this.nombre,
    this.descripcion,
    required this.duracionMinutos,
    required this.precioAdicional,
    required this.activo,
  });

  factory ServicioAdmin.fromJson(Map<String, dynamic> json) {
    return ServicioAdmin(
      idServicio: _toInt(json['id_servicio']),
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
      duracionMinutos: _toInt(json['duracion_minutos']),
      precioAdicional: _toDouble(json['precio_adicional']),
      activo: json['activo'] == null ? true : json['activo'] as bool,
    );
  }
}

class HorarioCancha {
  final int idHorario;
  final int idCancha;
  final int diaSemana;
  final String horaApertura;
  final String horaCierre;
  final bool activo;

  const HorarioCancha({
    required this.idHorario,
    required this.idCancha,
    required this.diaSemana,
    required this.horaApertura,
    required this.horaCierre,
    required this.activo,
  });

  factory HorarioCancha.fromJson(Map<String, dynamic> json) {
    return HorarioCancha(
      idHorario: _toInt(json['id_horario']),
      idCancha: _toInt(json['id_cancha']),
      diaSemana: _toInt(json['dia_semana']),
      horaApertura: (json['hora_apertura'] ?? '08:00:00').toString(),
      horaCierre: (json['hora_cierre'] ?? '22:00:00').toString(),
      activo: json['activo'] == null ? true : json['activo'] as bool,
    );
  }

  static const _dias = [
    '',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  String get nombreDia =>
      (diaSemana >= 1 && diaSemana <= 7) ? _dias[diaSemana] : 'Día $diaSemana';

  String get aperturaCorta =>
      horaApertura.length >= 5 ? horaApertura.substring(0, 5) : horaApertura;

  String get cierreCorta =>
      horaCierre.length >= 5 ? horaCierre.substring(0, 5) : horaCierre;
}

// ======================== EMPLEADOS ========================
class Empleado {
  final int idEmpleado;
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String ci;
  final String telefono;
  final String cargo;
  final String rol;
  final String correo;
  final bool activo;

  const Empleado({
    required this.idEmpleado,
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.ci,
    required this.telefono,
    required this.cargo,
    required this.rol,
    required this.correo,
    required this.activo,
  });

  factory Empleado.fromJson(Map<String, dynamic> json) {
    return Empleado(
      idEmpleado: _toInt(json['id_empleado']),
      idUsuario: _toInt(json['id_usuario']),
      nombres: (json['nombres'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? '').toString(),
      ci: (json['ci'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      cargo: (json['cargo'] ?? '').toString(),
      rol: (json['rol'] ?? 'recepcionista').toString(),
      correo: (json['correo'] ?? '').toString(),
      activo: json['activo'] == null ? true : json['activo'] as bool,
    );
  }

  String get nombreCompleto => '$nombres $apellidos'.trim();
}

// ======================== CONFIGURACIÓN ========================
class ReglaNegocio {
  final int idConfig;
  final String clave;
  final String valor;
  final String? descripcion;

  const ReglaNegocio({
    required this.idConfig,
    required this.clave,
    required this.valor,
    this.descripcion,
  });

  factory ReglaNegocio.fromJson(Map<String, dynamic> json) {
    return ReglaNegocio(
      idConfig: _toInt(json['id_config']),
      clave: (json['clave'] ?? '').toString(),
      valor: (json['valor'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
    );
  }

  String get tituloLegible {
    switch (clave) {
      case 'porcentaje_anticipo_minimo':
        return 'Porcentaje mínimo de anticipo (%)';
      case 'plazo_minimo_cancelacion_horas':
        return 'Plazo mínimo de cancelación (horas)';
      default:
        return clave.replaceAll('_', ' ');
    }
  }
}