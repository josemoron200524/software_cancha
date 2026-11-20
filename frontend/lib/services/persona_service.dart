import '../core/api_client.dart';
import '../models/persona_model.dart';

typedef ClienteList = List<Cliente>;

class PersonaService {
  static Future<ClienteList> listarClientes({String? buscar}) async {
    final params = (buscar != null && buscar.trim().isNotEmpty)
        ? {'buscar': buscar.trim()}
        : null;

    final data = await ApiClient.get('/clientes', queryParams: params) as List;

    return data
        .map((item) => Cliente.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Cliente> crearCliente({
    required String nombres,
    required String apellidos,
    required String ciNit,
    required String telefono,
    String? correo,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'ci_nit': ciNit.trim(),
      'telefono': telefono.trim(),
    };

    if (correo != null && correo.trim().isNotEmpty) {
      body['correo'] = correo.trim();
    }
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }

    final data =
        await ApiClient.post('/clientes', body: body) as Map<String, dynamic>;
    return Cliente.fromJson(data);
  }

  static Future<Cliente> actualizarCliente({
    required int idCliente,
    required String nombres,
    required String apellidos,
    required String ciNit,
    required String telefono,
    bool activo = true,
  }) async {
    final body = <String, dynamic>{
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'ci_nit': ciNit.trim(),
      'telefono': telefono.trim(),
      'activo': activo,
    };

    final data = await ApiClient.put('/clientes/$idCliente', body: body)
        as Map<String, dynamic>;
    return Cliente.fromJson(data);
  }

  static Future<Cliente> habilitarPortal({
    required int idCliente,
    required String correo,
    required String password,
  }) async {
    final data = await ApiClient.post(
      '/clientes/$idCliente/habilitar-portal',
      body: {
        'correo': correo.trim(),
        'password': password,
      },
    ) as Map<String, dynamic>;

    return Cliente.fromJson(data);
  }

  static Future<void> desactivarCliente(int idCliente) async {
    await ApiClient.delete('/clientes/$idCliente');
  }
}