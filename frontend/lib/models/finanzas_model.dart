import 'catalogo_model.dart';

class PagoListado {
  final int idPago;
  final int idReserva;
  final String codigoReserva;
  final String clienteNombre;
  final double monto;
  final String tipoPago;
  final String metodoPago;
  final String? referenciaComprobante;
  final String fechaPago;
  final int? registradoPor;

  const PagoListado({
    required this.idPago,
    required this.idReserva,
    required this.codigoReserva,
    required this.clienteNombre,
    required this.monto,
    required this.tipoPago,
    required this.metodoPago,
    this.referenciaComprobante,
    required this.fechaPago,
    this.registradoPor,
  });

  factory PagoListado.fromJson(Map<String, dynamic> json) {
    return PagoListado(
      idPago: json['id_pago'] as int,
      idReserva: json['id_reserva'] as int,
      codigoReserva: (json['codigo_reserva'] ?? '').toString(),
      clienteNombre: (json['cliente_nombre'] ?? '').toString(),
      monto: parseMonto(json['monto']),
      tipoPago: (json['tipo_pago'] ?? '').toString(),
      metodoPago: (json['metodo_pago'] ?? '').toString(),
      referenciaComprobante: json['referencia_comprobante']?.toString(),
      fechaPago: (json['fecha_pago'] ?? '').toString(),
      registradoPor: json['registrado_por'] as int?,
    );
  }

  String get fechaCorta {
    if (fechaPago.length >= 16) {
      return fechaPago.substring(0, 16).replaceFirst('T', ' ');
    }
    return fechaPago;
  }
}

class ResultadoRegistroPago {
  final String codigoReserva;
  final double montoTotal;
  final double totalPagado;
  final double saldoPendiente;
  final bool reservaConfirmadaAutomaticamente;
  final String estadoReservaActual;

  const ResultadoRegistroPago({
    required this.codigoReserva,
    required this.montoTotal,
    required this.totalPagado,
    required this.saldoPendiente,
    required this.reservaConfirmadaAutomaticamente,
    required this.estadoReservaActual,
  });

  factory ResultadoRegistroPago.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen_financiero'] as Map<String, dynamic>;
    return ResultadoRegistroPago(
      codigoReserva: resumen['codigo_reserva'].toString(),
      montoTotal: parseMonto(resumen['monto_total']),
      totalPagado: parseMonto(resumen['total_pagado']),
      saldoPendiente: parseMonto(resumen['saldo_pendiente']),
      reservaConfirmadaAutomaticamente:
          resumen['reserva_confirmada_automaticamente'] as bool? ?? false,
      estadoReservaActual: resumen['estado_reserva_actual'].toString(),
    );
  }
}