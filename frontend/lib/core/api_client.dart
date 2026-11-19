import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

typedef HeadersMap = Map<String, String>;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const String tokenKey = 'access_token';

  static Future<HeadersMap> _buildHeaders({bool requiereAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiereAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<Uri> _buildUri(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    final filtered = <String, String>{};
    queryParams.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        filtered[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  static dynamic _procesarRespuesta(http.Response response) {
    final rawBody = utf8.decode(response.bodyBytes);
    dynamic data;

    if (rawBody.isNotEmpty) {
      try {
        data = jsonDecode(rawBody);
      } catch (_) {
        data = rawBody;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      response.statusCode,
      _extraerMensajeError(data, response.statusCode),
    );
  }

  static String _extraerMensajeError(dynamic data, int statusCode) {
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        final primero = detail.first;
        if (primero is Map<String, dynamic> && primero['msg'] != null) {
          return primero['msg'].toString().replaceFirst('Value error, ', '');
        }
      }
    }
    return 'Error del servidor (código $statusCode).';
  }

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool requiereAuth = true,
  }) async {
    try {
      final uri = await _buildUri(path, queryParams: queryParams);
      final headers = await _buildHeaders(requiereAuth: requiereAuth);
      final response = await http.get(uri, headers: headers);
      return _procesarRespuesta(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'No se pudo conectar con el servidor. Verifica que la API esté encendida.',
      );
    }
  }

  static Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiereAuth = true,
  }) async {
    try {
      final uri = await _buildUri(path);
      final headers = await _buildHeaders(requiereAuth: requiereAuth);
      final response = await http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _procesarRespuesta(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'No se pudo conectar con el servidor. Verifica que la API esté encendida.',
      );
    }
  }

  static Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiereAuth = true,
  }) async {
    try {
      final uri = await _buildUri(path);
      final headers = await _buildHeaders(requiereAuth: requiereAuth);
      final response = await http.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _procesarRespuesta(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'No se pudo conectar con el servidor. Verifica que la API esté encendida.',
      );
    }
  }

  static Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiereAuth = true,
  }) async {
    try {
      final uri = await _buildUri(path);
      final headers = await _buildHeaders(requiereAuth: requiereAuth);
      final response = await http.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _procesarRespuesta(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'No se pudo conectar con el servidor. Verifica que la API esté encendida.',
      );
    }
  }

  static Future<dynamic> delete(
    String path, {
    bool requiereAuth = true,
  }) async {
    try {
      final uri = await _buildUri(path);
      final headers = await _buildHeaders(requiereAuth: requiereAuth);
      final response = await http.delete(uri, headers: headers);
      return _procesarRespuesta(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        0,
        'No se pudo conectar con el servidor. Verifica que la API esté encendida.',
      );
    }
  }
}