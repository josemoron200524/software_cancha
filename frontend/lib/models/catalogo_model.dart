double parseMonto(dynamic valor) {
  if (valor == null) return 0.0;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString()) ?? 0.0;
}

class Cancha {
  final int idCancha;
  final String nombre;
  final String tipoSuperficie;
  final int capacidadJugadores;
  final double precioHora;
  final String? descripcion;
  final String estado;

  const Cancha({
    required this.idCancha,
    required this.nombre,
    required this.tipoSuperficie,
    required this.capacidadJugadores,
    required this.precioHora,
    this.descripcion,
    required this.estado,
  });

  factory Cancha.fromJson(Map<String, dynamic> json) {
    return Cancha(
      idCancha: json['id_cancha'] as int,
      nombre: json['nombre'] as String,
      tipoSuperficie: (json['tipo_superficie'] ?? 'Sintético').toString(),
      capacidadJugadores: (json['capacidad_jugadores'] as num?)?.toInt() ?? 10,
      precioHora: parseMonto(json['precio_hora']),
      descripcion: json['descripcion']?.toString(),
      estado: (json['estado'] ?? 'disponible').toString(),
    );
  }
}

class Servicio {
  final int idServicio;
  final String nombre;
  final String? descripcion;
  final int duracionMinutos;
  final double precioAdicional;
  final bool activo;

  const Servicio({
    required this.idServicio,
    required this.nombre,
    this.descripcion,
    required this.duracionMinutos,
    required this.precioAdicional,
    required this.activo,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      idServicio: json['id_servicio'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion']?.toString(),
      duracionMinutos: (json['duracion_minutos'] as num?)?.toInt() ?? 60,
      precioAdicional: parseMonto(json['precio_adicional']),
      activo: json['activo'] == null ? true : json['activo'] as bool,
    );
  }
}