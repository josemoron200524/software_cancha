import '../core/api_client.dart';
import '../models/reserva_model.dart';

typedef ReservaList = List<Reserva>;
typedef ConfigList = List<ConfigItem>;

class ReservaService {
  static Future<DisponibilidadResponse> consultarDisponibilidad({
    required int idCancha,
    required String fechaReserva,
  }) async {
    final data = await ApiClient.get(
      '/reservas/disponibilidad',
      requiereAuth: false,
      queryParams: {
        'id_cancha': idCancha,
        'fecha_reserva': fechaReserva,
      },
    ) as Map<String, dynamic>;

    return DisponibilidadResponse.fromJson(data);
  }

  static Future<ReservaList> listarReservas({
    String? estado,
    String? fechaDesde,
    String? fechaHasta,
    int? idCancha,
  }) async {
    final data = await ApiClient.get(
      '/reservas',
      queryParams: {
        'estado': estado,
        'fecha_desde': fechaDesde,
        'fecha_hasta': fechaHasta,
        'id_cancha': idCancha,
      },
    ) as List;

    return data
        .map((item) => Reserva.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Reserva> crearReserva({
    required int idCancha,
    required int idServicio,
    required String fechaReserva,
    required String horaInicio,
    int? idCliente,
    String? observaciones,
  }) async {
    final body = <String, dynamic>{
      'id_cancha': idCancha,
      'id_servicio': idServicio,
      'fecha_reserva': fechaReserva,
      'hora_inicio': horaInicio,
      'observaciones':
          observaciones != null && observaciones.trim().isNotEmpty
              ? observaciones.trim()
              : null,
    };
    if (idCliente != null) {
      body['id_cliente'] = idCliente;
    }

    final data = await ApiClient.post('/reservas', body: body)
        as Map<String, dynamic>;
    return Reserva.fromJson(data);
  }

  static Future<Reserva> reprogramarReserva({
    required int idReserva,
    required int idCancha,
    required int idServicio,
    required String fechaReserva,
    required String horaInicio,
    String? observaciones,
  }) async {
    final data = await ApiClient.put(
      '/reservas/$idReserva/reprogramar',
      body: {
        'id_cancha': idCancha,
        'id_servicio': idServicio,
        'fecha_reserva': fechaReserva,
        'hora_inicio': horaInicio,
        'observaciones':
            observaciones != null && observaciones.trim().isNotEmpty
                ? observaciones.trim()
                : null,
      },
    ) as Map<String, dynamic>;

    return Reserva.fromJson(data);
  }

  static Future<Reserva> cambiarEstadoReserva({
    required int idReserva,
    required String estado,
    String? motivoCancelacion,
  }) async {
    final body = <String, dynamic>{'estado': estado};
    if (motivoCancelacion != null && motivoCancelacion.trim().isNotEmpty) {
      body['motivo_cancelacion'] = motivoCancelacion.trim();
    }

    final data = await ApiClient.patch(
      '/reservas/$idReserva/estado',
      body: body,
    ) as Map<String, dynamic>;

    return Reserva.fromJson(data);
  }

  static Future<Reserva> cancelarReserva({
    required int idReserva,
    required String motivo,
  }) async {
    return cambiarEstadoReserva(
      idReserva: idReserva,
      estado: 'cancelada',
      motivoCancelacion: motivo,
    );
  }

  static Future<ResumenPagosReserva> obtenerPagosReserva(int idReserva) async {
    final data = await ApiClient.get('/pagos/reserva/$idReserva')
        as Map<String, dynamic>;
    return ResumenPagosReserva.fromJson(data);
  }

  static Future<ConfigList> listarConfiguraciones() async {
    final data = await ApiClient.get('/configuracion') as List;
    return data
        .map((item) => ConfigItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}