import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/finanzas_model.dart';
import '../models/reserva_model.dart';
import '../services/finanzas_service.dart';
import '../services/reserva_service.dart';

Future<ResultadoRegistroPago?> mostrarDialogoRegistrarPago({
  required BuildContext context,
  Reserva? reservaFija,
}) async {
  List<Reserva> reservasCobrables = [];
  if (reservaFija != null) {
    reservasCobrables = [reservaFija];
  } else {
    try {
      final todas = await ReservaService.listarReservas();
      reservasCobrables = todas
          .where((r) => r.estado != 'cancelada' && r.estado != 'no_asistio')
          .toList();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }

  if (!context.mounted) return null;

  if (reservasCobrables.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay reservas activas disponibles para cobrar.'),
      ),
    );
    return null;
  }

  int idReservaSel = reservasCobrables.first.idReserva;
  ResumenPagosReserva? resumenSel;
  bool cargandoSaldo = true;
  bool guardando = false;

  String tipoPago = 'anticipo';
  String metodoPago = 'qr';
  final montoCtrl = TextEditingController();
  final refCtrl = TextEditingController();

  Future<void> cargarSaldo(
    int idReserva,
    void Function(VoidCallback) setStateModal,
  ) async {
    setStateModal(() => cargandoSaldo = true);
    try {
      final res = await ReservaService.obtenerPagosReserva(idReserva);
      setStateModal(() {
        resumenSel = res;
        cargandoSaldo = false;
        if (res.saldoPendiente > 0) {
          final sugerido = res.totalPagado == 0
              ? (res.montoTotal * 0.5)
              : res.saldoPendiente;
          final montoInicial = sugerido > res.saldoPendiente
              ? res.saldoPendiente
              : sugerido;
          montoCtrl.text = montoInicial.toStringAsFixed(2);
          tipoPago = res.totalPagado == 0 ? 'anticipo' : 'saldo';
        } else {
          montoCtrl.text = '0.00';
        }
      });
    } on ApiException {
      setStateModal(() => cargandoSaldo = false);
    }
  }

  bool iniciado = false;

  return showDialog<ResultadoRegistroPago>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateModal) {
        if (!iniciado) {
          iniciado = true;
          cargarSaldo(idReservaSel, setStateModal);
        }

        final saldo = resumenSel?.saldoPendiente ?? 0.0;
        final total = resumenSel?.montoTotal ?? 0.0;
        final pagado = resumenSel?.totalPagado ?? 0.0;

        return AlertDialog(
          title: const Text('Registrar Pago'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reservaFija == null) ...[
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Reserva',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: idReservaSel,
                          items: reservasCobrables.map((r) {
                            return DropdownMenuItem<int>(
                              value: r.idReserva,
                              child: Text(
                                '${r.codigoReserva} • ${r.clienteNombre} (Bs ${r.montoTotal.toStringAsFixed(0)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setStateModal(() => idReservaSel = v);
                            cargarSaldo(v, setStateModal);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Text(
                      '${reservaFija.codigoReserva} • ${reservaFija.clienteNombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${reservaFija.canchaNombre} (${reservaFija.fechaReserva} ${reservaFija.rangoHorario})',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (cargandoSaldo)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Monto total:'),
                              Text(
                                'Bs ${total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Pagado hasta ahora:'),
                              Text('Bs ${pagado.toStringAsFixed(2)}'),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Saldo pendiente:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Bs ${saldo.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: saldo > 0
                                      ? Colors.green.shade800
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (saldo <= 0)
                      const Text(
                        'Esta reserva ya se encuentra pagada en su totalidad.',
                        style: TextStyle(color: Colors.green),
                      )
                    else ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          if (pagado == 0)
                            ActionChip(
                              label: Text(
                                '50% Anticipo (Bs ${(total * 0.5).toStringAsFixed(2)})',
                              ),
                              onPressed: () {
                                setStateModal(() {
                                  tipoPago = 'anticipo';
                                  montoCtrl.text =
                                      (total * 0.5).toStringAsFixed(2);
                                });
                              },
                            ),
                          ActionChip(
                            label: Text(
                              'Saldo total (Bs ${saldo.toStringAsFixed(2)})',
                            ),
                            onPressed: () {
                              setStateModal(() {
                                tipoPago = pagado == 0 ? 'total' : 'saldo';
                                montoCtrl.text = saldo.toStringAsFixed(2);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tipo de pago',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: tipoPago,
                            items: const [
                              DropdownMenuItem(
                                value: 'anticipo',
                                child: Text('Anticipo'),
                              ),
                              DropdownMenuItem(
                                value: 'saldo',
                                child: Text('Saldo'),
                              ),
                              DropdownMenuItem(
                                value: 'total',
                                child: Text('Pago total'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setStateModal(() {
                                tipoPago = v;
                                if (v == 'total') {
                                  montoCtrl.text = saldo.toStringAsFixed(2);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Método de pago',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: metodoPago,
                            items: const [
                              DropdownMenuItem(
                                value: 'qr',
                                child: Text('QR'),
                              ),
                              DropdownMenuItem(
                                value: 'efectivo',
                                child: Text('Efectivo'),
                              ),
                              DropdownMenuItem(
                                value: 'transferencia',
                                child: Text('Transferencia'),
                              ),
                              DropdownMenuItem(
                                value: 'tarjeta',
                                child: Text('Tarjeta'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setStateModal(() => metodoPago = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monto a cobrar (Bs)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Referencia / Nro. comprobante (opcional)',
                          hintText: 'Ej: QR-987654 o Recibo #12',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            if (!cargandoSaldo && saldo > 0)
              FilledButton(
                onPressed: guardando
                    ? null
                    : () async {
                        final monto = double.tryParse(
                          montoCtrl.text.trim().replaceAll(',', '.'),
                        );
                        if (monto == null || monto <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa un monto mayor a 0.'),
                            ),
                          );
                          return;
                        }

                        setStateModal(() => guardando = true);
                        try {
                          final resultado = await FinanzasService.registrarPago(
                            idReserva: idReservaSel,
                            monto: monto,
                            tipoPago: tipoPago,
                            metodoPago: metodoPago,
                            referenciaComprobante: refCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, resultado);
                        } on ApiException catch (e) {
                          setStateModal(() => guardando = false);
                          if (context.mounted) {
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
                    : const Text('Registrar cobro'),
              ),
          ],
        );
      },
    ),
  );
}

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  List<PagoListado> _pagos = [];
  String? _metodoFiltro;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  bool _cargando = true;
  String? _error;

  static const _metodos = [null, 'qr', 'efectivo', 'transferencia', 'tarjeta'];

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  String _fmtApi(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _cargarPagos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await FinanzasService.listarPagos(
        fechaDesde: _fechaDesde != null ? _fmtApi(_fechaDesde!) : null,
        fechaHasta: _fechaHasta != null ? _fmtApi(_fechaHasta!) : null,
        metodoPago: _metodoFiltro,
      );
      if (!mounted) return;
      setState(() {
        _pagos = lista;
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

  Future<void> _elegirRangoFechas() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: hoy.add(const Duration(days: 365)),
      initialDateRange: (_fechaDesde != null && _fechaHasta != null)
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : null,
    );
    if (rango != null) {
      setState(() {
        _fechaDesde = rango.start;
        _fechaHasta = rango.end;
      });
      await _cargarPagos();
    }
  }

  Future<void> _nuevoPago() async {
    final resultado = await mostrarDialogoRegistrarPago(context: context);
    if (resultado != null && mounted) {
      final extra = resultado.reservaConfirmadaAutomaticamente
          ? ' • Reserva confirmada automáticamente.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pago registrado en ${resultado.codigoReserva}. Saldo: Bs ${resultado.saldoPendiente.toStringAsFixed(2)}$extra',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarPagos();
    }
  }

  String _etiquetaMetodo(String? m) {
    switch (m) {
      case null:
        return 'Todos';
      case 'qr':
        return 'QR';
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      case 'tarjeta':
        return 'Tarjeta';
      default:
        return m;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRecaudado =
        _pagos.fold<double>(0.0, (acc, p) => acc + p.monto);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoPago,
        icon: const Icon(Icons.add_card),
        label: const Text('Registrar pago'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 34,
                      color: Colors.green.shade800,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total recaudado (${_pagos.length} pagos)',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Bs ${totalRecaudado.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _elegirRangoFechas,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        (_fechaDesde != null && _fechaHasta != null)
                            ? '${_fmtApi(_fechaDesde!)} → ${_fmtApi(_fechaHasta!)}'
                            : 'Fechas',
                      ),
                    ),
                    if (_fechaDesde != null)
                      IconButton(
                        tooltip: 'Limpiar fechas',
                        onPressed: () {
                          setState(() {
                            _fechaDesde = null;
                            _fechaHasta = null;
                          });
                          _cargarPagos();
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _metodos.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _metodoFiltro == m,
                    label: Text(_etiquetaMetodo(m)),
                    onSelected: (_) {
                      setState(() => _metodoFiltro = m);
                      _cargarPagos();
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
                              onPressed: _cargarPagos,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _pagos.isEmpty
                        ? const Center(
                            child: Text('No hay pagos registrados en este filtro.'),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarPagos,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                              itemCount: _pagos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final p = _pagos[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(
                                        Icons.receipt_long,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    title: Text(
                                      '${p.codigoReserva} • ${p.clienteNombre}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${p.tipoPago.toUpperCase()} • ${p.metodoPago.toUpperCase()}'
                                      '${p.referenciaComprobante != null ? ' • Ref: ${p.referenciaComprobante}' : ''}'
                                      '\n${p.fechaCorta}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Text(
                                      'Bs ${p.monto.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
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