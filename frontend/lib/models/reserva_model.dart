import 'catalogo_model.dart';

class BloqueHorario {
  final String horaInicio;
  final String horaFin;
  final String? estado;
  final String? codigoReserva;

  const BloqueHorario({
    required this.horaInicio,
    required this.horaFin,
    this.estado,
    this.codigoReserva,
  });

  factory BloqueHorario.fromJson(Map<String, dynamic> json) {
    return BloqueHorario(
      horaInicio: json['hora_inicio'].toString(),
      horaFin: json['hora_fin'].toString(),
      estado: json['estado']?.toString(),
      codigoReserva: json['codigo_reserva']?.toString(),
    );
  }

  String get horaInicioCorta =>
      horaInicio.length >= 5 ? horaInicio.substring(0, 5) : horaInicio;

  String get horaFinCorta =>
      horaFin.length >= 5 ? horaFin.substring(0, 5) : horaFin;
}

class DisponibilidadResponse {
  final int idCancha;
  final String canchaNombre;
  final String estadoCancha;
  final String fechaReserva;
  final int diaSemana;
  final bool disponible;
  final String? horaApertura;
  final String? horaCierre;
  final List<BloqueHorario> bloquesOcupados;
  final List<BloqueHorario> bloquesDisponibles;

  const DisponibilidadResponse({
    required this.idCancha,
    required this.canchaNombre,
    required this.estadoCancha,
    required this.fechaReserva,
    required this.diaSemana,
    required this.disponible,
    this.horaApertura,
    this.horaCierre,
    required this.bloquesOcupados,
    required this.bloquesDisponibles,
  });

  factory DisponibilidadResponse.fromJson(Map<String, dynamic> json) {
    final horario = json['horario_atencion'] as Map<String, dynamic>?;
    final ocupadosRaw = (json['bloques_ocupados'] as List?) ?? [];
    final libresRaw = (json['bloques_disponibles'] as List?) ?? [];

    return DisponibilidadResponse(
      idCancha: json['id_cancha'] as int,
      canchaNombre: json['cancha_nombre'].toString(),
      estadoCancha: json['estado_cancha'].toString(),
      fechaReserva: json['fecha_reserva'].toString(),
      diaSemana: (json['dia_semana'] as num).toInt(),
      disponible: json['disponible'] as bool,
      horaApertura: horario?['hora_apertura']?.toString(),
      horaCierre: horario?['hora_cierre']?.toString(),
      bloquesOcupados: ocupadosRaw
          .map((e) => BloqueHorario.fromJson(e as Map<String, dynamic>))
          .toList(),
      bloquesDisponibles: libresRaw
          .map((e) => BloqueHorario.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Reserva {
  final int idReserva;
  final String codigoReserva;
  final int idCliente;
  final String clienteNombre;
  final int idCancha;
  final String canchaNombre;
  final int idServicio;
  final String servicioNombre;
  final String fechaReserva;
  final String horaInicio;
  final String horaFin;
  final String estado;
  final double montoTotal;
  final String? motivoCancelacion;
  final String? observaciones;

  const Reserva({
    required this.idReserva,
    required this.codigoReserva,
    required this.idCliente,
    required this.clienteNombre,
    required this.idCancha,
    required this.canchaNombre,
    required this.idServicio,
    required this.servicioNombre,
    required this.fechaReserva,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
    required this.montoTotal,
    this.motivoCancelacion,
    this.observaciones,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      idReserva: json['id_reserva'] as int,
      codigoReserva: json['codigo_reserva'].toString(),
      idCliente: json['id_cliente'] as int,
      clienteNombre: (json['cliente_nombre'] ?? '').toString(),
      idCancha: json['id_cancha'] as int,
      canchaNombre: (json['cancha_nombre'] ?? '').toString(),
      idServicio: json['id_servicio'] as int,
      servicioNombre: (json['servicio_nombre'] ?? '').toString(),
      fechaReserva: json['fecha_reserva'].toString(),
      horaInicio: json['hora_inicio'].toString(),
      horaFin: json['hora_fin'].toString(),
      estado: json['estado'].toString(),
      montoTotal: parseMonto(json['monto_total']),
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
      observaciones: json['observaciones']?.toString(),
    );
  }

  String get rangoHorario {
    final ini = horaInicio.length >= 5 ? horaInicio.substring(0, 5) : horaInicio;
    final fin = horaFin.length >= 5 ? horaFin.substring(0, 5) : horaFin;
    return '$ini - $fin';
  }

  bool get esModificable => estado == 'pendiente' || estado == 'confirmada';
}

class PagoItem {
  final int idPago;
  final double monto;
  final String tipoPago;
  final String metodoPago;
  final String? referenciaComprobante;
  final String fechaPago;

  const PagoItem({
    required this.idPago,
    required this.monto,
    required this.tipoPago,
    required this.metodoPago,
    this.referenciaComprobante,
    required this.fechaPago,
  });

  factory PagoItem.fromJson(Map<String, dynamic> json) {
    return PagoItem(
      idPago: json['id_pago'] as int,
      monto: parseMonto(json['monto']),
      tipoPago: json['tipo_pago'].toString(),
      metodoPago: json['metodo_pago'].toString(),
      referenciaComprobante: json['referencia_comprobante']?.toString(),
      fechaPago: json['fecha_pago'].toString(),
    );
  }
}

class ResumenPagosReserva {
  final String codigoReserva;
  final String estadoReserva;
  final double montoTotal;
  final double totalPagado;
  final double saldoPendiente;
  final List<PagoItem> pagos;

  const ResumenPagosReserva({
    required this.codigoReserva,
    required this.estadoReserva,
    required this.montoTotal,
    required this.totalPagado,
    required this.saldoPendiente,
    required this.pagos,
  });

  factory ResumenPagosReserva.fromJson(Map<String, dynamic> json) {
    final pagosRaw = (json['pagos'] as List?) ?? [];
    return ResumenPagosReserva(
      codigoReserva: json['codigo_reserva'].toString(),
      estadoReserva: json['estado_reserva'].toString(),
      montoTotal: parseMonto(json['monto_total']),
      totalPagado: parseMonto(json['total_pagado']),
      saldoPendiente: parseMonto(json['saldo_pendiente']),
      pagos: pagosRaw
          .map((e) => PagoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ConfigItem {
  final String clave;
  final String valor;
  final String? descripcion;

  const ConfigItem({
    required this.clave,
    required this.valor,
    this.descripcion,
  });

  factory ConfigItem.fromJson(Map<String, dynamic> json) {
    return ConfigItem(
      clave: json['clave'].toString(),
      valor: json['valor'].toString(),
      descripcion: json['descripcion']?.toString(),
    );
  }
}