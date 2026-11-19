import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/usuario_model.dart';

class AuthService {
  static const String _userKey = 'usuario_actual';

  static Future<Usuario> login({
    required String correo,
    required String password,
  }) async {
    final data = await ApiClient.post(
      '/auth/login',
      requiereAuth: false,
      body: {
        'correo': correo.trim(),
        'password': password,
      },
    ) as Map<String, dynamic>;

    final token = data['access_token'] as String;
    final usuario = Usuario.fromJson(data['usuario'] as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(usuario.toJson()));

    return usuario;
  }

  static Future<void> registrarCliente({
    required String nombres,
    required String apellidos,
    required String ciNit,
    required String telefono,
    required String correo,
    required String password,
  }) async {
    await ApiClient.post(
      '/auth/register',
      requiereAuth: false,
      body: {
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'ci_nit': ciNit.trim(),
        'telefono': telefono.trim(),
        'correo': correo.trim(),
        'password': password,
      },
    );
  }

  static Future<Usuario?> verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiClient.tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final data = await ApiClient.get('/auth/me') as Map<String, dynamic>;
      final usuario = Usuario.fromJson(data);
      await prefs.setString(_userKey, jsonEncode(usuario.toJson()));
      return usuario;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await limpiarSesionLocal();
        return null;
      }
      // Si el backend no respondió en este instante, devuelve null para reintentar login
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      await ApiClient.post('/auth/logout');
    } catch (_) {
      // Aunque el token ya haya expirado, siempre limpiamos la sesión local
    } finally {
      await limpiarSesionLocal();
    }
  }

  static Future<void> limpiarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiClient.tokenKey);
    await prefs.remove(_userKey);
  }
}