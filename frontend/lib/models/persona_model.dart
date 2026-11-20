class Cliente {
  final int idCliente;
  final int? idUsuario;
  final String nombres;
  final String apellidos;
  final String ciNit;
  final String telefono;
  final String? correo;
  final bool activo;

  const Cliente({
    required this.idCliente,
    this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.ciNit,
    required this.telefono,
    this.correo,
    required this.activo,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      idCliente: json['id_cliente'] as int,
      idUsuario: json['id_usuario'] as int?,
      nombres: (json['nombres'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? '').toString(),
      ciNit: (json['ci_nit'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      correo: json['correo']?.toString(),
      activo: json['activo'] == null ? true : json['activo'] as bool,
    );
  }

  String get nombreCompleto => '$nombres $apellidos'.trim();
  bool get tieneCuentaPortal => idUsuario != null;
}