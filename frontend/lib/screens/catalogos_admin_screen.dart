import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/admin_model.dart';
import '../services/admin_service.dart';

class CatalogosAdminScreen extends StatelessWidget {
  const CatalogosAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.stadium_outlined), text: 'Canchas'),
              Tab(icon: Icon(Icons.miscellaneous_services), text: 'Servicios'),
              Tab(icon: Icon(Icons.schedule), text: 'Horarios'),
              Tab(icon: Icon(Icons.tune), text: 'Reglas'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CanchasTab(),
                _ServiciosTab(),
                _HorariosTab(),
                _ReglasTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== TAB 1: CANCHAS ========================
class _CanchasTab extends StatefulWidget {
  const _CanchasTab();

  @override
  State<_CanchasTab> createState() => _CanchasTabState();
}

class _CanchasTabState extends State<_CanchasTab> {
  List<CanchaAdmin> _canchas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await AdminService.listarCanchas();
      if (!mounted) return;
      setState(() {
        _canchas = lista;
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
      case 'disponible':
        return Colors.green.shade700;
      case 'mantenimiento':
        return Colors.orange.shade800;
      default:
        return Colors.red.shade700;
    }
  }

  Future<void> _abrirFormulario({CanchaAdmin? existente}) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final supCtrl =
        TextEditingController(text: existente?.tipoSuperficie ?? 'Césped sintético');
    final capCtrl = TextEditingController(
      text: (existente?.capacidadJugadores ?? 10).toString(),
    );
    final precioCtrl = TextEditingController(
      text: (existente?.precioHora ?? 120.0).toStringAsFixed(2),
    );
    final descCtrl = TextEditingController(text: existente?.descripcion ?? '');
    String estado = existente?.estado ?? 'disponible';
    bool guardando = false;
    final esEdicion = existente != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text(esEdicion ? 'Editar Cancha' : 'Nueva Cancha'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Mínimo 3 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: supCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de superficie',
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Mínimo 3 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: capCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Capacidad jugadores',
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0 || n > 50) {
                                return '1 a 50';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Precio/hora (Bs)',
                            ),
                            validator: (v) {
                              final n = double.tryParse(
                                (v ?? '').trim().replaceAll(',', '.'),
                              );
                              if (n == null || n < 0) return 'Monto inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: estado,
                          items: const [
                            DropdownMenuItem(
                              value: 'disponible',
                              child: Text('Disponible'),
                            ),
                            DropdownMenuItem(
                              value: 'mantenimiento',
                              child: Text('Mantenimiento'),
                            ),
                            DropdownMenuItem(
                              value: 'inactiva',
                              child: Text('Inactiva'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setStateModal(() => estado = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateModal(() => guardando = true);
                      try {
                        final cap = int.parse(capCtrl.text.trim());
                        final precio = double.parse(
                          precioCtrl.text.trim().replaceAll(',', '.'),
                        );
                        if (esEdicion) {
                          await AdminService.actualizarCancha(
                            idCancha: existente.idCancha,
                            nombre: nombreCtrl.text,
                            tipoSuperficie: supCtrl.text,
                            capacidadJugadores: cap,
                            precioHora: precio,
                            estado: estado,
                            descripcion: descCtrl.text,
                          );
                        } else {
                          await AdminService.crearCancha(
                            nombre: nombreCtrl.text,
                            tipoSuperficie: supCtrl.text,
                            capacidadJugadores: cap,
                            precioHora: precio,
                            estado: estado,
                            descripcion: descCtrl.text,
                          );
                        }
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
                  : Text(esEdicion ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(esEdicion ? 'Cancha actualizada.' : 'Cancha creada.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargar();
    }
  }

  Future<void> _desactivar(CanchaAdmin cancha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar cancha'),
        content: Text('¿Deseas pasar "${cancha.nombre}" a estado inactiva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await AdminService.desactivarCancha(cancha.idCancha);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancha desactivada.')),
      );
      await _cargar();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cancha'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: _canchas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = _canchas[index];
                      final color = _colorEstado(c.estado);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.14),
                            child: Icon(Icons.stadium_outlined, color: color),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  c.estado.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${c.tipoSuperficie} • ${c.capacidadJugadores} jug. • Bs ${c.precioHora.toStringAsFixed(2)}/h'
                            '${c.descripcion != null && c.descripcion!.isNotEmpty ? '\n${c.descripcion}' : ''}',
                          ),
                          isThreeLine: c.descripcion != null &&
                              c.descripcion!.isNotEmpty,
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _abrirFormulario(existente: c),
                              ),
                              if (c.estado != 'inactiva')
                                IconButton(
                                  tooltip: 'Desactivar',
                                  icon: Icon(
                                    Icons.block,
                                    color: Colors.red.shade700,
                                  ),
                                  onPressed: () => _desactivar(c),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ======================== TAB 2: SERVICIOS ========================
class _ServiciosTab extends StatefulWidget {
  const _ServiciosTab();

  @override
  State<_ServiciosTab> createState() => _ServiciosTabState();
}

class _ServiciosTabState extends State<_ServiciosTab> {
  List<ServicioAdmin> _servicios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await AdminService.listarServicios();
      if (!mounted) return;
      setState(() {
        _servicios = lista;
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

  Future<void> _abrirFormulario({ServicioAdmin? existente}) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final descCtrl = TextEditingController(text: existente?.descripcion ?? '');
    final durCtrl = TextEditingController(
      text: (existente?.duracionMinutos ?? 60).toString(),
    );
    final precioCtrl = TextEditingController(
      text: (existente?.precioAdicional ?? 0.0).toStringAsFixed(2),
    );
    bool activo = existente?.activo ?? true;
    bool guardando = false;
    final esEdicion = existente != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text(esEdicion ? 'Editar Servicio' : 'Nuevo Servicio'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Mínimo 3 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duración (min)',
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0 || n > 480) {
                                return '1 a 480';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Adicional (Bs)',
                            ),
                            validator: (v) {
                              final n = double.tryParse(
                                (v ?? '').trim().replaceAll(',', '.'),
                              );
                              if (n == null || n < 0) return 'Monto inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                      ),
                    ),
                    if (esEdicion) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Servicio activo'),
                        value: activo,
                        onChanged: (v) => setStateModal(() => activo = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateModal(() => guardando = true);
                      try {
                        final dur = int.parse(durCtrl.text.trim());
                        final extra = double.parse(
                          precioCtrl.text.trim().replaceAll(',', '.'),
                        );
                        if (esEdicion) {
                          await AdminService.actualizarServicio(
                            idServicio: existente.idServicio,
                            nombre: nombreCtrl.text,
                            descripcion: descCtrl.text,
                            duracionMinutos: dur,
                            precioAdicional: extra,
                            activo: activo,
                          );
                        } else {
                          await AdminService.crearServicio(
                            nombre: nombreCtrl.text,
                            descripcion: descCtrl.text,
                            duracionMinutos: dur,
                            precioAdicional: extra,
                          );
                        }
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
                  : Text(esEdicion ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esEdicion ? 'Servicio actualizado.' : 'Servicio creado.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargar();
    }
  }

  Future<void> _desactivar(ServicioAdmin s) async {
    try {
      await AdminService.desactivarServicio(s.idServicio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio desactivado.')),
      );
      await _cargar();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo servicio'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: _servicios.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = _servicios[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: s.activo
                                ? Colors.blue.shade50
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.miscellaneous_services,
                              color: s.activo
                                  ? Colors.blue.shade800
                                  : Colors.grey,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: s.activo
                                      ? Colors.green.shade50
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  s.activo ? 'ACTIVO' : 'INACTIVO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: s.activo
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Duración: ${s.duracionMinutos} min • Adicional: Bs ${s.precioAdicional.toStringAsFixed(2)}'
                            '${s.descripcion != null && s.descripcion!.isNotEmpty ? '\n${s.descripcion}' : ''}',
                          ),
                          isThreeLine: s.descripcion != null &&
                              s.descripcion!.isNotEmpty,
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _abrirFormulario(existente: s),
                              ),
                              if (s.activo)
                                IconButton(
                                  tooltip: 'Desactivar',
                                  icon: Icon(
                                    Icons.block,
                                    color: Colors.red.shade700,
                                  ),
                                  onPressed: () => _desactivar(s),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ======================== TAB 3: HORARIOS ========================
class _HorariosTab extends StatefulWidget {
  const _HorariosTab();

  @override
  State<_HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends State<_HorariosTab> {
  List<CanchaAdmin> _canchas = [];
  int? _idCanchaSel;
  List<HorarioCancha> _horarios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final canchas = await AdminService.listarCanchas();
      if (!mounted) return;
      setState(() {
        _canchas = canchas;
        _idCanchaSel = canchas.isNotEmpty ? canchas.first.idCancha : null;
      });
      if (_idCanchaSel != null) {
        await _cargarHorarios(_idCanchaSel!);
      } else {
        setState(() => _cargando = false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    }
  }

  Future<void> _cargarHorarios(int idCancha) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await AdminService.listarHorariosCancha(idCancha);
      if (!mounted) return;
      setState(() {
        _horarios = lista;
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

  TimeOfDay _parseHora(String hhmm) {
    final partes = hhmm.split(':');
    final h = int.tryParse(partes.isNotEmpty ? partes[0] : '8') ?? 8;
    final m = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtHoraApi(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _fmtHoraCorta(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _abrirFormulario({HorarioCancha? existente}) async {
    if (_idCanchaSel == null) return;
    final esEdicion = existente != null;
    int diaSemana = existente?.diaSemana ?? 1;
    TimeOfDay apertura = existente != null
        ? _parseHora(existente.horaApertura)
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay cierre = existente != null
        ? _parseHora(existente.horaCierre)
        : const TimeOfDay(hour: 22, minute: 0);
    bool activo = existente?.activo ?? true;
    bool guardando = false;

    const diasNombres = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text(esEdicion ? 'Editar Horario' : 'Nuevo Horario'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!esEdicion) ...[
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Día de la semana',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: diaSemana,
                        items: List.generate(
                          7,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(diasNombres[i]),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) setStateModal(() => diaSemana = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Text(
                    'Día: ${existente.nombreDia}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: apertura,
                          );
                          if (picked != null) {
                            setStateModal(() => apertura = picked);
                          }
                        },
                        icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                        label: Text('Abre: ${_fmtHoraCorta(apertura)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: cierre,
                          );
                          if (picked != null) {
                            setStateModal(() => cierre = picked);
                          }
                        },
                        icon: const Icon(Icons.nightlight_outlined, size: 16),
                        label: Text('Cierra: ${_fmtHoraCorta(cierre)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horario habilitado'),
                  value: activo,
                  onChanged: (v) => setStateModal(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      setStateModal(() => guardando = true);
                      try {
                        if (esEdicion) {
                          await AdminService.actualizarHorario(
                            idHorario: existente.idHorario,
                            horaApertura: _fmtHoraApi(apertura),
                            horaCierre: _fmtHoraApi(cierre),
                            activo: activo,
                          );
                        } else {
                          await AdminService.crearHorario(
                            idCancha: _idCanchaSel!,
                            diaSemana: diaSemana,
                            horaApertura: _fmtHoraApi(apertura),
                            horaCierre: _fmtHoraApi(cierre),
                            activo: activo,
                          );
                        }
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
                  : Text(esEdicion ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && _idCanchaSel != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(esEdicion ? 'Horario actualizado.' : 'Horario creado.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarHorarios(_idCanchaSel!);
    }
  }

  Future<void> _eliminar(HorarioCancha h) async {
    try {
      await AdminService.eliminarHorario(h.idHorario);
      if (!mounted || _idCanchaSel == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario eliminado.')),
      );
      await _cargarHorarios(_idCanchaSel!);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _idCanchaSel == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo horario'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Seleccionar cancha',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _idCanchaSel,
                  items: _canchas
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.idCancha,
                          child: Text(c.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _idCanchaSel = v);
                    _cargarHorarios(v);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _horarios.isEmpty
                        ? const Center(
                            child: Text(
                              'Esta cancha aún no tiene horarios configurados.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                            itemCount: _horarios.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final h = _horarios[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: h.activo
                                        ? Colors.green.shade100
                                        : Colors.grey.shade200,
                                    child: Text(
                                      h.nombreDia.substring(0, 2),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: h.activo
                                            ? Colors.green.shade900
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    h.nombreDia,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${h.aperturaCorta} - ${h.cierreCorta} • ${h.activo ? 'Activo' : 'Inactivo'}',
                                  ),
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _abrirFormulario(existente: h),
                                      ),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade700,
                                        ),
                                        onPressed: () => _eliminar(h),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ======================== TAB 4: REGLAS DE NEGOCIO ========================
class _ReglasTab extends StatefulWidget {
  const _ReglasTab();

  @override
  State<_ReglasTab> createState() => _ReglasTabState();
}

class _ReglasTabState extends State<_ReglasTab> {
  List<ReglaNegocio> _reglas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await AdminService.listarReglas();
      if (!mounted) return;
      setState(() {
        _reglas = lista;
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

  Future<void> _editarRegla(ReglaNegocio regla) async {
    final valorCtrl = TextEditingController(text: regla.valor);
    final descCtrl = TextEditingController(text: regla.descripcion ?? '');
    bool guardando = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text(regla.tituloLegible),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Clave: ${regla.clave}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(labelText: 'Valor'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (valorCtrl.text.trim().isEmpty) return;
                      setStateModal(() => guardando = true);
                      try {
                        await AdminService.actualizarRegla(
                          clave: regla.clave,
                          valor: valorCtrl.text,
                          descripcion: descCtrl.text,
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
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Regla "${regla.tituloLegible}" actualizada.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _reglas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = _reglas[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.tune, color: Colors.green.shade800),
              ),
              title: Text(
                r.tituloLegible,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${r.descripcion ?? r.clave}\nValor actual: ${r.valor}',
              ),
              isThreeLine: true,
              trailing: FilledButton.tonalIcon(
                onPressed: () => _editarRegla(r),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
              ),
            ),
          );
        },
      ),
    );
  }
}