import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/admin_model.dart';
import '../services/admin_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReporteResumen? _resumen;
  List<ReporteCancha> _reporteCanchas = [];
  List<ReporteServicio> _reporteServicios = [];

  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  String _fmtApi(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _cargarDashboard() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final desde = _fechaDesde != null ? _fmtApi(_fechaDesde!) : null;
      final hasta = _fechaHasta != null ? _fmtApi(_fechaHasta!) : null;

      final resumen = await AdminService.obtenerReporteResumen(
        fechaDesde: desde,
        fechaHasta: hasta,
      );
      final canchas = await AdminService.obtenerReporteCanchas(
        fechaDesde: desde,
        fechaHasta: hasta,
      );
      final servicios = await AdminService.obtenerReporteServicios(
        fechaDesde: desde,
        fechaHasta: hasta,
      );

      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _reporteCanchas = canchas;
        _reporteServicios = servicios;
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

  Future<void> _elegirRango() async {
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
      await _cargarDashboard();
    }
  }

  Widget _kpiCard({
    required IconData icono,
    required Color color,
    required String titulo,
    required String valor,
    String? subtitulo,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.14),
                    child: Icon(icono, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipEstado(String titulo, int cantidad, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            cantidad.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _cargarDashboard,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final r = _resumen!;

    return RefreshIndicator(
      onRefresh: _cargarDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Resumen Ejecutivo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _elegirRango,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  (_fechaDesde != null && _fechaHasta != null)
                      ? '${_fmtApi(_fechaDesde!)} → ${_fmtApi(_fechaHasta!)}'
                      : 'Todo el historial',
                ),
              ),
              if (_fechaDesde != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _fechaDesde = null;
                      _fechaHasta = null;
                    });
                    _cargarDashboard();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Limpiar'),
                ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _cargarDashboard,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpiCard(
                icono: Icons.account_balance_wallet_outlined,
                color: Colors.green.shade800,
                titulo: 'Total recaudado',
                valor: 'Bs ${r.totalRecaudado.toStringAsFixed(2)}',
                subtitulo: 'Pagos efectivos en caja/QR',
              ),
              _kpiCard(
                icono: Icons.trending_up,
                color: Colors.teal.shade700,
                titulo: 'Monto proyectado',
                valor: 'Bs ${r.montoProyectado.toStringAsFixed(2)}',
                subtitulo: 'Reservas activas y atendidas',
              ),
              _kpiCard(
                icono: Icons.event_available,
                color: Colors.blue.shade700,
                titulo: 'Tasa de asistencia',
                valor: '${r.tasaAsistencia.toStringAsFixed(1)}%',
                subtitulo: '${r.atendidas} atendidas / ${r.noAsistio} no asistió',
              ),
              _kpiCard(
                icono: Icons.cancel_outlined,
                color: Colors.red.shade700,
                titulo: 'Tasa de cancelación',
                valor: '${r.tasaCancelacion.toStringAsFixed(1)}%',
                subtitulo: '${r.canceladas} de ${r.totalReservas} reservas',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reservas por estado (Total: ${r.totalReservas})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _chipEstado('Pendientes', r.pendientes, Colors.orange.shade800),
                      _chipEstado('Confirmadas', r.confirmadas, Colors.green.shade700),
                      _chipEstado('Atendidas', r.atendidas, Colors.blue.shade700),
                      _chipEstado('Canceladas', r.canceladas, Colors.red.shade700),
                      _chipEstado('No asistió', r.noAsistio, Colors.grey.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresos por método de pago',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (r.ingresosPorMetodo.isEmpty)
                    const Text('Sin pagos registrados en el período.')
                  else
                    ...r.ingresosPorMetodo.map((m) {
                      final porcentaje = r.totalRecaudado > 0
                          ? (m.totalRecaudado / r.totalRecaudado)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${m.metodoPago.toUpperCase()} (${m.cantidadPagos} pagos)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Bs ${m.totalRecaudado.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: porcentaje,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rendimiento por Cancha',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_reporteCanchas.isEmpty)
                    const Text('Sin datos de canchas.')
                  else
                    ..._reporteCanchas.map(
                      (c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            Icons.stadium_outlined,
                            color: Colors.green.shade800,
                          ),
                        ),
                        title: Text(
                          c.canchaNombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Reservas: ${c.totalReservas} • Atendidas: ${c.atendidas} • Canceladas: ${c.canceladas} • Estado: ${c.estado}',
                        ),
                        trailing: Text(
                          'Bs ${c.montoProyectado.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rendimiento por Servicio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_reporteServicios.isEmpty)
                    const Text('Sin datos de servicios.')
                  else
                    ..._reporteServicios.map(
                      (s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Icon(
                            Icons.sports_soccer,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        title: Text(
                          s.servicioNombre,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Reservas: ${s.totalReservas} • Atendidas: ${s.atendidas} • Canceladas: ${s.canceladas}',
                        ),
                        trailing: Text(
                          'Bs ${s.montoProyectado.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}