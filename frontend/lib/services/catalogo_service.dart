import '../core/api_client.dart';
import '../models/catalogo_model.dart';

typedef CanchaList = List<Cancha>;
typedef ServicioList = List<Servicio>;

class CatalogoService {
  static Future<dynamic> _getConFallback(
    String rutaPrincipal,
    String rutaAlternativa,
  ) async {
    try {
      return await ApiClient.get(rutaPrincipal);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return await ApiClient.get(rutaAlternativa);
      }
      rethrow;
    }
  }

  static Future<CanchaList> listarCanchas() async {
    final data = await _getConFallback('/canchas', '/catalogo/canchas') as List;
    return data
        .map((item) => Cancha.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<ServicioList> listarServicios() async {
    final data =
        await _getConFallback('/servicios', '/catalogo/servicios') as List;
    return data
        .map((item) => Servicio.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}