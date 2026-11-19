class Usuario {
  final int idUsuario;
  final String correo;
  final String rol;

  const Usuario({
    required this.idUsuario,
    required this.correo,
    required this.rol,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idUsuario: json['id_usuario'] as int,
      correo: json['correo'] as String,
      rol: json['rol'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'correo': correo,
        'rol': rol,
      };

  String get rolLegible {
    switch (rol) {
      case 'administrador':
        return 'Administrador';
      case 'recepcionista':
        return 'Recepcionista';
      case 'cliente':
        return 'Cliente';
      default:
        return rol;
    }
  }
}