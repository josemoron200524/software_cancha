import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/catalogo_model.dart';
import '../models/reserva_model.dart';
import '../models/usuario_model.dart';
import '../services/catalogo_service.dart';
import '../services/reserva_service.dart';

class DisponibilidadScreen extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback? onReservaCreada;

  const DisponibilidadScreen({
    super.key,
    required this.usuario,
    this.onReservaCreada,
  });

  @override
  State<DisponibilidadScreen> createState() => _DisponibilidadScreenState();
}

class _DisponibilidadScreenState extends State<DisponibilidadScreen> {
  List<Cancha> _canchas = [];
  List<Servicio> _servicios = [];
  Cancha? _canchaSeleccionada;
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  DisponibilidadResponse? _disponibilidad;

  bool _cargandoInicial = true;
  bool _cargandoDisp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  String _formatearFechaApi(DateTime fecha) {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatearFechaBonita(DateTime fecha) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '${dias[fecha.weekday - 1]} $d/$m/${fecha.year}';
  }

  Future<void> _cargarCatalogos() async {
    setState(() {
      _cargandoInicial = true;
      _error = null;
    });
    try {
      final canchas = await CatalogoService.listarCanchas();
      final servicios = await CatalogoService.listarServicios();
      final serviciosActivos = servicios.where((s) => s.activo).toList();

      if (!mounted) return;
      setState(() {
        _canchas = canchas;
        _servicios = serviciosActivos;
        _canchaSeleccionada = canchas.isNotEmpty ? canchas.first : null;
        _cargandoInicial = false;
      });

      if (_canchaSeleccionada != null) {
        await _consultarDisponibilidad();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargandoInicial = false;
      });
    }
  }

  Future<void> _consultarDisponibilidad() async {
    final cancha = _canchaSeleccionada;
    if (cancha == null) return;

    setState(() {
      _cargandoDisp = true;
      _error = null;
    });

    try {
      final disp = await ReservaService.consultarDisponibilidad(
        idCancha: cancha.idCancha,
        fechaReserva: _formatearFechaApi(_fechaSeleccionada),
      );
      if (!mounted) return;
      setState(() {
        _disponibilidad = disp;
        _cargandoDisp = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargandoDisp = false;
      });
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada.isBefore(hoy) ? hoy : _fechaSeleccionada,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 90)),
    );
    if (elegida != null) {
      setState(() => _fechaSeleccionada = elegida);
      await _consultarDisponibilidad();
    }
  }

  List<TimeOfDay> _generarHorasSugeridas(List<BloqueHorario> libres) {
    final horas = <TimeOfDay>[];
    for (final bloque in libres) {
      final iniParts = bloque.horaInicio.split(':');
      final finParts = bloque.horaFin.split(':');
      if (iniParts.length < 2 || finParts.length < 2) continue;

      int actualMin =
          (int.tryParse(iniParts[0]) ?? 0) * 60 + (int.tryParse(iniParts[1]) ?? 0);
      final finMin =
          (int.tryParse(finParts[0]) ?? 0) * 60 + (int.tryParse(finParts[1]) ?? 0);

      while (actualMin + 60 <= finMin) {
        horas.add(TimeOfDay(hour: actualMin ~/ 60, minute: actualMin % 60));
        actualMin += 60;
      }
    }
    return horas;
  }

  Future<void> _abrirModalReserva({TimeOfDay? horaInicial}) async {
    final cancha = _canchaSeleccionada;
    if (cancha == null || _servicios.isEmpty) return;

    Servicio servicioElegido = _servicios.first;
    TimeOfDay horaElegida = horaInicial ?? const TimeOfDay(hour: 18, minute: 0);
    final obsCtrl = TextEditingController();
    final idClienteCtrl = TextEditingController();
    final esStaff = widget.usuario.rol != 'cliente';
    bool enviando = false;

    final creada = await showDialog<Reserva>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) {
          final horas = servicioElegido.duracionMinutos / 60.0;
          final montoEstimado =
              (cancha.precioHora * horas) + servicioElegido.precioAdicional;
          final horaTexto =
              '${horaElegida.hour.toString().padLeft(2, '0')}:${horaElegida.minute.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Text('Reservar ${cancha.nombre}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Fecha: ${_formatearFechaBonita(_fechaSeleccionada)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Servicio / Paquete',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: servicioElegido.idServicio,
                        items: _servicios.map((s) {
                          return DropdownMenuItem<int>(
                            value: s.idServicio,
                            child: Text(
                              '${s.nombre} (+Bs ${s.precioAdicional.toStringAsFixed(0)})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          setStateModal(() {
                            servicioElegido =
                                _servicios.firstWhere((s) => s.idServicio == id);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: horaElegida,
                      );
                      if (picked != null) {
                        setStateModal(() => horaElegida = picked);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      'Hora inicio: $horaTexto (${servicioElegido.duracionMinutos} min)',
                    ),
                  ),
                  if (esStaff) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: idClienteCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID Cliente (obligatorio para recepción)',
                        hintText: 'Ej: 1',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      hintText: 'Ej: Necesitamos chalecos o balón',
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          'Monto total estimado:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Bs ${montoEstimado.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: enviando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: enviando
                    ? null
                    : () async {
                        int? idCliente;
                        if (esStaff) {
                          idCliente = int.tryParse(idClienteCtrl.text.trim());
                          if (idCliente == null || idCliente <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa un ID de cliente válido.'),
                              ),
                            );
                            return;
                          }
                        }

                        setStateModal(() => enviando = true);
                        try {
                          final nueva = await ReservaService.crearReserva(
                            idCancha: cancha.idCancha,
                            idServicio: servicioElegido.idServicio,
                            fechaReserva: _formatearFechaApi(_fechaSeleccionada),
                            horaInicio: '$horaTexto:00',
                            idCliente: idCliente,
                            observaciones: obsCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, nueva);
                        } on ApiException catch (e) {
                          setStateModal(() => enviando = false);
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
                child: enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar reserva'),
              ),
            ],
          );
        },
      ),
    );

    if (creada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserva ${creada.codigoReserva} creada (Bs ${creada.montoTotal.toStringAsFixed(2)}).',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _consultarDisponibilidad();
      widget.onReservaCreada?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _canchas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _cargarCatalogos,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final disp = _disponibilidad;
    final horasSugeridas =
        disp != null ? _generarHorasSugeridas(disp.bloquesDisponibles) : <TimeOfDay>[];

    return RefreshIndicator(
      onRefresh: _consultarDisponibilidad,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '1. Selecciona una cancha',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _canchas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cancha = _canchas[index];
                final seleccionada =
                    _canchaSeleccionada?.idCancha == cancha.idCancha;
                final disponible = cancha.estado == 'disponible';

                return InkWell(
                  onTap: () {
                    setState(() => _canchaSeleccionada = cancha);
                    _consultarDisponibilidad();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: seleccionada
                          ? Colors.green.shade50
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: seleccionada
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: seleccionada ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cancha.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Icon(
                              disponible
                                  ? Icons.check_circle
                                  : Icons.build_circle,
                              size: 18,
                              color: disponible ? Colors.green : Colors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${cancha.tipoSuperficie} • ${cancha.capacidadJugadores} jug.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Bs ${cancha.precioHora.toStringAsFixed(2)} / hora',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '2. Fecha y disponibilidad',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_formatearFechaBonita(_fechaSeleccionada)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cargandoDisp)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
              ),
            )
          else if (disp != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          disp.canchaNombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Chip(
                          label: Text(
                            disp.disponible ? 'Disponible' : 'No disponible',
                          ),
                          backgroundColor: disp.disponible
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                        ),
                      ],
                    ),
                    if (disp.horaApertura != null && disp.horaCierre != null)
                      Text(
                        'Horario de atención: ${disp.horaApertura!.substring(0, 5)} a ${disp.horaCierre!.substring(0, 5)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    const Divider(height: 24),
                    const Text(
                      'Horarios ocupados:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (disp.bloquesOcupados.isEmpty)
                      Text(
                        'Sin reservas registradas para esta fecha.',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: disp.bloquesOcupados.map((b) {
                          return Chip(
                            avatar: const Icon(
                              Icons.block,
                              size: 16,
                              color: Colors.red,
                            ),
                            label: Text(
                              '${b.horaInicioCorta} - ${b.horaFinCorta} (${b.estado ?? 'ocupado'})',
                            ),
                            backgroundColor: Colors.red.shade50,
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Toca una hora libre para reservar:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    if (horasSugeridas.isEmpty)
                      Text(
                        'No hay bloques libres de al menos 1 hora para esta fecha.',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: horasSugeridas.map((hora) {
                          final texto =
                              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
                          return ActionChip(
                            avatar: const Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.green,
                            ),
                            label: Text(texto),
                            backgroundColor: Colors.green.shade50,
                            onPressed: () =>
                                _abrirModalReserva(horaInicial: hora),
                          );
                        }).toList(),
                      ),
                    if (disp.disponible) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _abrirModalReserva(),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Reservar otro horario'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_servicios.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Servicios y paquetes disponibles',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._servicios.map((s) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.sports_outlined),
                  title: Text(s.nombre),
                  subtitle: Text(
                    '${s.duracionMinutos} min${s.descripcion != null ? ' • ${s.descripcion}' : ''}',
                  ),
                  trailing: Text(
                    s.precioAdicional > 0
                        ? '+Bs ${s.precioAdicional.toStringAsFixed(2)}'
                        : 'Incluido',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}