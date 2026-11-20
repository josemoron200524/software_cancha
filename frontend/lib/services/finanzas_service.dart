import '../core/api_client.dart';
import '../models/finanzas_model.dart';

typedef PagoListadoList = List<PagoListado>;

class FinanzasService {
  static Future<PagoListadoList> listarPagos({
    String? fechaDesde,
    String? fechaHasta,
    String? metodoPago,
  }) async {
    final data = await ApiClient.get(
      '/pagos',
      queryParams: {
        'fecha_desde': fechaDesde,
        'fecha_hasta': fechaHasta,
        'metodo_pago': metodoPago,
      },
    ) as List;

    return data
        .map((item) => PagoListado.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<ResultadoRegistroPago> registrarPago({
    required int idReserva,
    required double monto,
    required String tipoPago,
    required String metodoPago,
    String? referenciaComprobante,
  }) async {
    final data = await ApiClient.post(
      '/pagos',
      body: {
        'id_reserva': idReserva,
        'monto': monto,
        'tipo_pago': tipoPago,
        'metodo_pago': metodoPago,
        'referencia_comprobante':
            referenciaComprobante != null &&
                    referenciaComprobante.trim().isNotEmpty
                ? referenciaComprobante.trim()
                : null,
      },
    ) as Map<String, dynamic>;

    return ResultadoRegistroPago.fromJson(data);
  }
}