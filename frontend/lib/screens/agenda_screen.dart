import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/catalogo_model.dart';
import '../models/persona_model.dart';
import '../models/reserva_model.dart';
import '../services/catalogo_service.dart';
import '../services/persona_service.dart';
import '../services/reserva_service.dart';
import 'pagos_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<Reserva> _reservas = [];
  List<Cancha> _canchas = [];
  List<Servicio> _servicios = [];
  List<Cliente> _clientes = [];

  DateTime? _fechaFiltro;
  int? _idCanchaFiltro;
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
    _inicializar();
  }

  String _fmtApi(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _inicializar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final canchas = await CatalogoService.listarCanchas();
      final servicios = (await CatalogoService.listarServicios())
          .where((s) => s.activo)
          .toList();
      final clientes = (await PersonaService.listarClientes())
          .where((c) => c.activo)
          .toList();

      if (!mounted) return;
      setState(() {
        _canchas = canchas;
        _servicios = servicios;
        _clientes = clientes;
      });
      await _cargarReservas();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  Future<void> _cargarReservas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final fechaApi = _fechaFiltro != null ? _fmtApi(_fechaFiltro!) : null;
      final lista = await ReservaService.listarReservas(
        estado: _estadoFiltro,
        fechaDesde: fechaApi,
        fechaHasta: fechaApi,
        idCancha: _idCanchaFiltro,
      );
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

  Future<void> _elegirFechaFiltro() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? hoy,
      firstDate: DateTime(2025, 1, 1),
      lastDate: hoy.add(const Duration(days: 365)),
    );
    if (elegida != null) {
      setState(() => _fechaFiltro = elegida);
      await _cargarReservas();
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

  Future<void> _cambiarEstado(Reserva reserva, String nuevoEstado) async {
    String? motivo;

    if (nuevoEstado == 'cancelada') {
      final motivoCtrl = TextEditingController();
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Cancelar ${reserva.codigoReserva}'),
          content: TextField(
            controller: motivoCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Motivo de cancelación',
              hintText: 'Ej: Solicitud telefónica del cliente',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar cancelación'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
      if (motivoCtrl.text.trim().length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Indica un motivo de al menos 3 caracteres.'),
            ),
          );
        }
        return;
      }
      motivo = motivoCtrl.text.trim();
    }

    try {
      await ReservaService.cambiarEstadoReserva(
        idReserva: reserva.idReserva,
        estado: nuevoEstado,
        motivoCancelacion: motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserva ${reserva.codigoReserva} pasó a "${_etiquetaEstado(nuevoEstado)}".',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarReservas();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _cobrarReserva(Reserva reserva) async {
    final resultado = await mostrarDialogoRegistrarPago(
      context: context,
      reservaFija: reserva,
    );
    if (resultado != null && mounted) {
      final extra = resultado.reservaConfirmadaAutomaticamente
          ? ' • ¡Confirmada automáticamente!'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cobro registrado en ${resultado.codigoReserva}. Saldo: Bs ${resultado.saldoPendiente.toStringAsFixed(2)}$extra',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarReservas();
    }
  }

  Future<void> _abrirNuevaReserva() async {
    try {
      final clientesAct = (await PersonaService.listarClientes())
          .where((c) => c.activo)
          .toList();
      if (mounted) {
        setState(() => _clientes = clientesAct);
      }
    } catch (_) {}

    if (!mounted) return;

    if (_canchas.isEmpty || _servicios.isEmpty || _clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Necesitas al menos una cancha, un servicio y un cliente activo.',
          ),
        ),
      );
      return;
    }

    int idCliente = _clientes.first.idCliente;
    Cancha canchaSel = _canchas.first;
    Servicio servicioSel = _servicios.first;
    DateTime fechaSel = _fechaFiltro ?? DateTime.now();
    TimeOfDay horaSel = const TimeOfDay(hour: 18, minute: 0);
    final obsCtrl = TextEditingController();
    bool guardando = false;

    final creada = await showDialog<Reserva>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          final horas = servicioSel.duracionMinutos / 60.0;
          final monto =
              (canchaSel.precioHora * horas) + servicioSel.precioAdicional;
          final horaTxt =
              '${horaSel.hour.toString().padLeft(2, '0')}:${horaSel.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: const Text('Nueva Reserva (Recepción)'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Cliente',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: idCliente,
                          items: _clientes.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.idCliente,
                              child: Text(
                                '${c.nombreCompleto} (${c.ciNit})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setStateModal(() => idCliente = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Cancha',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: canchaSel.idCancha,
                          items: _canchas.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.idCancha,
                              child: Text(
                                '${c.nombre} (Bs ${c.precioHora.toStringAsFixed(0)}/h)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setStateModal(() {
                              canchaSel =
                                  _canchas.firstWhere((c) => c.idCancha == v);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Servicio',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: servicioSel.idServicio,
                          items: _servicios.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.idServicio,
                              child: Text(
                                '${s.nombre} (${s.duracionMinutos} min)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setStateModal(() {
                              servicioSel = _servicios
                                  .firstWhere((s) => s.idServicio == v);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final hoy = DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: fechaSel.isBefore(hoy)
                                    ? hoy
                                    : fechaSel,
                                firstDate: DateTime(hoy.year, hoy.month, hoy.day),
                                lastDate: hoy.add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setStateModal(() => fechaSel = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_fmtApi(fechaSel)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: horaSel,
                              );
                              if (picked != null) {
                                setStateModal(() => horaSel = picked);
                              }
                            },
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(horaTxt),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones (opcional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total estimado:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Bs ${monto.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: guardando
                    ? null
                    : () async {
                        setStateModal(() => guardando = true);
                        try {
                          final nueva = await ReservaService.crearReserva(
                            idCancha: canchaSel.idCancha,
                            idServicio: servicioSel.idServicio,
                            fechaReserva: _fmtApi(fechaSel),
                            horaInicio: '$horaTxt:00',
                            idCliente: idCliente,
                            observaciones: obsCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, nueva);
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
                    : const Text('Crear reserva'),
              ),
            ],
          );
        },
      ),
    );

    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reserva ${creada.codigoReserva} creada correctamente.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarReservas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevaReserva,
        icon: const Icon(Icons.add),
        label: const Text('Nueva reserva'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _elegirFechaFiltro,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fechaFiltro != null ? _fmtApi(_fechaFiltro!) : 'Todas las fechas',
                  ),
                ),
                ActionChip(
                  label: const Text('Hoy'),
                  onPressed: () {
                    setState(() => _fechaFiltro = DateTime.now());
                    _cargarReservas();
                  },
                ),
                if (_fechaFiltro != null)
                  ActionChip(
                    label: const Text('Ver todas'),
                    onPressed: () {
                      setState(() => _fechaFiltro = null);
                      _cargarReservas();
                    },
                  ),
                SizedBox(
                  width: 220,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cancha',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        isDense: true,
                        value: _idCanchaFiltro,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todas las canchas'),
                          ),
                          ..._canchas.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.idCancha,
                              child: Text(
                                c.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _idCanchaFiltro = v);
                          _cargarReservas();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _estados.map((estado) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _estadoFiltro == estado,
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
                            child: Text(
                              'No hay reservas para los filtros seleccionados.',
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarReservas,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                              itemCount: _reservas.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final r = _reservas[index];
                                final color = _colorEstado(r.estado);

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${r.codigoReserva} • ${r.clienteNombre}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                        const SizedBox(height: 6),
                                        Text(
                                          '${r.canchaNombre} • ${r.servicioNombre}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Fecha: ${r.fechaReserva}  |  Horario: ${r.rangoHorario}  |  Total: Bs ${r.montoTotal.toStringAsFixed(2)}',
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
                                            if (r.estado != 'cancelada' &&
                                                r.estado != 'no_asistio')
                                              FilledButton.tonalIcon(
                                                onPressed: () =>
                                                    _cobrarReserva(r),
                                                icon: const Icon(
                                                  Icons.payments_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text('Cobrar'),
                                              ),
                                            if (r.estado == 'pendiente')
                                              OutlinedButton.icon(
                                                onPressed: () => _cambiarEstado(
                                                  r,
                                                  'confirmada',
                                                ),
                                                icon: const Icon(
                                                  Icons.check_circle_outline,
                                                  size: 18,
                                                  color: Colors.green,
                                                ),
                                                label: const Text('Confirmar'),
                                              ),
                                            if (r.estado == 'confirmada')
                                              OutlinedButton.icon(
                                                onPressed: () => _cambiarEstado(
                                                  r,
                                                  'atendida',
                                                ),
                                                icon: const Icon(
                                                  Icons.sports_score,
                                                  size: 18,
                                                  color: Colors.blue,
                                                ),
                                                label: const Text('Atendida'),
                                              ),
                                            if (r.estado == 'confirmada')
                                              OutlinedButton.icon(
                                                onPressed: () => _cambiarEstado(
                                                  r,
                                                  'no_asistio',
                                                ),
                                                icon: const Icon(
                                                  Icons.person_off_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text('No asistió'),
                                              ),
                                            if (r.esModificable)
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.red.shade700,
                                                ),
                                                onPressed: () => _cambiarEstado(
                                                  r,
                                                  'cancelada',
                                                ),
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                  size: 18,
                                                ),
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
      ),
    );
  }
}