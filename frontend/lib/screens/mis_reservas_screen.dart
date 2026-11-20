import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/catalogo_model.dart';
import '../models/reserva_model.dart';
import '../services/catalogo_service.dart';
import '../services/reserva_service.dart';

class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  List<Reserva> _reservas = [];
  String? _estadoFiltro;
  bool _cargando = true;
  String? _error;

  static const _estados = [
    null,
    'pendiente',
    'confirmada',
    'atendida',
    'cancelada',
    'no_asistio',
  ];

  @override
  void initState() {
    super.initState();
    _cargarReservas();
  }

  Future<void> _cargarReservas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await ReservaService.listarReservas(estado: _estadoFiltro);
      if (!mounted) return;
      setState(() {
        _reservas = lista;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'confirmada':
        return Colors.green.shade700;
      case 'pendiente':
        return Colors.orange.shade800;
      case 'atendida':
        return Colors.blue.shade700;
      case 'cancelada':
        return Colors.red.shade700;
      case 'no_asistio':
        return Colors.grey.shade700;
      default:
        return Colors.black87;
    }
  }

  String _etiquetaEstado(String? estado) {
    switch (estado) {
      case null:
        return 'Todas';
      case 'pendiente':
        return 'Pendiente';
      case 'confirmada':
        return 'Confirmada';
      case 'atendida':
        return 'Atendida';
      case 'cancelada':
        return 'Cancelada';
      case 'no_asistio':
        return 'No asistió';
      default:
        return estado;
    }
  }

  Future<void> _verPagos(Reserva reserva) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resumen = await ReservaService.obtenerPagosReserva(reserva.idReserva);
      if (!mounted) return;
      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Pagos • ${resumen.codigoReserva}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filaResumen('Monto total:', 'Bs ${resumen.montoTotal.toStringAsFixed(2)}'),
                _filaResumen('Total pagado:', 'Bs ${resumen.totalPagado.toStringAsFixed(2)}'),
                _filaResumen(
                  'Saldo pendiente:',
                  'Bs ${resumen.saldoPendiente.toStringAsFixed(2)}',
                  destacado: true,
                ),
                const Divider(height: 20),
                if (resumen.pagos.isEmpty)
                  const Text('Aún no existen pagos registrados para esta reserva.')
                else
                  ...resumen.pagos.map((p) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        'Bs ${p.monto.toStringAsFixed(2)} • ${p.tipoPago.toUpperCase()}',
                      ),
                      subtitle: Text(
                        'Método: ${p.metodoPago.toUpperCase()}${p.referenciaComprobante != null ? ' • Ref: ${p.referenciaComprobante}' : ''}',
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _filaResumen(String etiqueta, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta),
          Text(
            valor,
            style: TextStyle(
              fontWeight: destacado ? FontWeight.bold : FontWeight.w600,
              color: destacado ? Colors.green.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reprogramar(Reserva reserva) async {
    List<Cancha> canchas;
    List<Servicio> servicios;
    try {
      canchas = await CatalogoService.listarCanchas();
      servicios = (await CatalogoService.listarServicios())
          .where((s) => s.activo)
          .toList();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    if (!mounted) return;

    int idCancha = reserva.idCancha;
    int idServicio = reserva.idServicio;
    DateTime fecha = DateTime.tryParse(reserva.fechaReserva) ?? DateTime.now();
    final parts = reserva.horaInicio.split(':');
    TimeOfDay hora = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 18,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final obsCtrl = TextEditingController(text: reserva.observaciones ?? '');
    bool guardando = false;

    final actualizada = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          final fechaApi =
              '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
          final horaTxt =
              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Text('Reprogramar ${reserva.codigoReserva}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cancha',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: canchas.any((c) => c.idCancha == idCancha)
                            ? idCancha
                            : canchas.first.idCancha,
                        items: canchas
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.idCancha,
                                child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setStateModal(() => idCancha = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Servicio',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: servicios.any((s) => s.idServicio == idServicio)
                            ? idServicio
                            : servicios.first.idServicio,
                        items: servicios
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.idServicio,
                                child: Text(s.nombre, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setStateModal(() => idServicio = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final hoy = DateTime.now();
                      final elegida = await showDatePicker(
                        context: ctx,
                        initialDate: fecha.isBefore(hoy) ? hoy : fecha,
                        firstDate: DateTime(hoy.year, hoy.month, hoy.day),
                        lastDate: hoy.add(const Duration(days: 90)),
                      );
                      if (elegida != null) setStateModal(() => fecha = elegida);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('Fecha: $fechaApi'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final elegida = await showTimePicker(
                        context: ctx,
                        initialTime: hora,
                      );
                      if (elegida != null) setStateModal(() => hora = elegida);
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('Hora inicio: $horaTxt'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(ctx, false),
                child: const Text('Volver'),
              ),
              FilledButton(
                onPressed: guardando
                    ? null
                    : () async {
                        setStateModal(() => guardando = true);
                        try {
                          await ReservaService.reprogramarReserva(
                            idReserva: reserva.idReserva,
                            idCancha: idCancha,
                            idServicio: idServicio,
                            fechaReserva: fechaApi,
                            horaInicio: '$horaTxt:00',
                            observaciones: obsCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on ApiException catch (e) {
                          setStateModal(() => guardando = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                child: guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );

    if (actualizada == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva reprogramada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
      await _cargarReservas();
    }
  }

  Future<void> _cancelar(Reserva reserva) async {
    final motivoCtrl = TextEditingController();
    bool cancelando = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text('Cancelar ${reserva.codigoReserva}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Indica el motivo de la cancelación (se valida el plazo mínimo configurado).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo de cancelación',
                  hintText: 'Ej: Lluvia o cambio de planes',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: cancelando ? null : () => Navigator.pop(ctx, false),
              child: const Text('No cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: cancelando
                  ? null
                  : () async {
                      if (motivoCtrl.text.trim().length < 3) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Escribe un motivo de al menos 3 caracteres.'),
                          ),
                        );
                        return;
                      }
                      setStateModal(() => cancelando = true);
                      try {
                        await ReservaService.cancelarReserva(
                          idReserva: reserva.idReserva,
                          motivo: motivoCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiException catch (e) {
                        setStateModal(() => cancelando = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: cancelando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar cancelación'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva cancelada.')),
      );
      await _cargarReservas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: _estados.map((estado) {
              final seleccionado = _estadoFiltro == estado;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: seleccionado,
                  label: Text(_etiquetaEstado(estado)),
                  onSelected: (_) {
                    setState(() => _estadoFiltro = estado);
                    _cargarReservas();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _cargarReservas,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : _reservas.isEmpty
                      ? const Center(
                          child: Text('No tienes reservas en esta categoría.'),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargarReservas,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reservas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final r = _reservas[index];
                              final color = _colorEstado(r.estado);

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            r.codigoReserva,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _etiquetaEstado(r.estado),
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${r.canchaNombre} • ${r.servicioNombre}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fecha: ${r.fechaReserva}  |  Horario: ${r.rangoHorario}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total: Bs ${r.montoTotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                      if (r.observaciones != null &&
                                          r.observaciones!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Obs: ${r.observaciones}',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      if (r.motivoCancelacion != null &&
                                          r.motivoCancelacion!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Motivo cancelación: ${r.motivoCancelacion}',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 20),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _verPagos(r),
                                            icon: const Icon(Icons.payments_outlined, size: 18),
                                            label: const Text('Ver pagos'),
                                          ),
                                          if (r.esModificable)
                                            OutlinedButton.icon(
                                              onPressed: () => _reprogramar(r),
                                              icon: const Icon(Icons.edit_calendar, size: 18),
                                              label: const Text('Reprogramar'),
                                            ),
                                          if (r.esModificable)
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red.shade700,
                                              ),
                                              onPressed: () => _cancelar(r),
                                              icon: const Icon(Icons.cancel_outlined, size: 18),
                                              label: const Text('Cancelar'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}