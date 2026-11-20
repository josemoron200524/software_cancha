import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/admin_model.dart';
import '../services/admin_service.dart';
import 'clientes_screen.dart';

class PersonasAdminScreen extends StatelessWidget {
  const PersonasAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Clientes'),
              Tab(icon: Icon(Icons.badge_outlined), text: 'Empleados'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ClientesScreen(),
                _EmpleadosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmpleadosTab extends StatefulWidget {
  const _EmpleadosTab();

  @override
  State<_EmpleadosTab> createState() => _EmpleadosTabState();
}

class _EmpleadosTabState extends State<_EmpleadosTab> {
  List<Empleado> _empleados = [];
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
      final lista = await AdminService.listarEmpleados(soloActivos: false);
      if (!mounted) return;
      setState(() {
        _empleados = lista;
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

  Future<void> _abrirFormulario({Empleado? existente}) async {
    final formKey = GlobalKey<FormState>();
    final nombresCtrl = TextEditingController(text: existente?.nombres ?? '');
    final apellidosCtrl =
        TextEditingController(text: existente?.apellidos ?? '');
    final ciCtrl = TextEditingController(text: existente?.ci ?? '');
    final telCtrl = TextEditingController(text: existente?.telefono ?? '');
    final cargoCtrl = TextEditingController(
      text: existente?.cargo ?? 'Recepcionista',
    );
    final correoCtrl = TextEditingController(text: existente?.correo ?? '');
    final passCtrl = TextEditingController();

    String rol = existente?.rol ?? 'recepcionista';
    bool activo = existente?.activo ?? true;
    bool guardando = false;
    final esEdicion = existente != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text(esEdicion ? 'Editar Empleado' : 'Nuevo Empleado'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombresCtrl,
                      decoration: const InputDecoration(labelText: 'Nombres'),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Mínimo 2 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: apellidosCtrl,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Mínimo 2 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ciCtrl,
                            decoration: const InputDecoration(labelText: 'CI'),
                            validator: (v) =>
                                (v == null || v.trim().length < 4)
                                    ? 'Mínimo 4'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: telCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 7)
                                    ? 'Mínimo 7'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cargoCtrl,
                      decoration: const InputDecoration(labelText: 'Cargo'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Mínimo 3 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Rol en el sistema',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: rol,
                          items: const [
                            DropdownMenuItem(
                              value: 'recepcionista',
                              child: Text('Recepcionista'),
                            ),
                            DropdownMenuItem(
                              value: 'administrador',
                              child: Text('Administrador'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setStateModal(() => rol = v);
                          },
                        ),
                      ),
                    ),
                    if (!esEdicion) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        validator: (v) => (v == null ||
                                !v.contains('@') ||
                                !v.contains('.'))
                            ? 'Correo inválido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña inicial',
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cuenta activa'),
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
                        if (esEdicion) {
                          await AdminService.actualizarEmpleado(
                            idEmpleado: existente.idEmpleado,
                            nombres: nombresCtrl.text,
                            apellidos: apellidosCtrl.text,
                            ci: ciCtrl.text,
                            telefono: telCtrl.text,
                            cargo: cargoCtrl.text,
                            rol: rol,
                            activo: activo,
                          );
                        } else {
                          await AdminService.crearEmpleado(
                            nombres: nombresCtrl.text,
                            apellidos: apellidosCtrl.text,
                            ci: ciCtrl.text,
                            telefono: telCtrl.text,
                            cargo: cargoCtrl.text,
                            rol: rol,
                            correo: correoCtrl.text,
                            password: passCtrl.text,
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
                  : Text(esEdicion ? 'Guardar' : 'Registrar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esEdicion ? 'Empleado actualizado.' : 'Empleado registrado.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargar();
    }
  }

  Future<void> _desactivar(Empleado emp) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar empleado'),
        content: Text('¿Seguro que deseas desactivar a ${emp.nombreCompleto}?'),
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
      await AdminService.desactivarEmpleado(emp.idEmpleado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empleado desactivado.')),
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
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo empleado'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: _empleados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = _empleados[index];
                      final esAdmin = e.rol == 'administrador';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: e.activo
                                ? (esAdmin
                                    ? Colors.purple.shade50
                                    : Colors.green.shade100)
                                : Colors.grey.shade300,
                            child: Icon(
                              esAdmin
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.support_agent,
                              color: e.activo
                                  ? (esAdmin
                                      ? Colors.purple.shade700
                                      : Colors.green.shade800)
                                  : Colors.grey.shade700,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.nombreCompleto,
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
                                  color: esAdmin
                                      ? Colors.purple.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  esAdmin ? 'Admin' : 'Recepción',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: esAdmin
                                        ? Colors.purple.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${e.cargo} • CI: ${e.ci} • Tel: ${e.telefono}\n${e.correo}${e.activo ? '' : ' • INACTIVO'}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _abrirFormulario(existente: e),
                              ),
                              if (e.activo)
                                IconButton(
                                  tooltip: 'Desactivar',
                                  icon: Icon(
                                    Icons.person_off_outlined,
                                    color: Colors.red.shade700,
                                  ),
                                  onPressed: () => _desactivar(e),
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