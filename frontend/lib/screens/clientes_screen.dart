import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/persona_model.dart';
import '../services/persona_service.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _buscarCtrl = TextEditingController();
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final texto = _buscarCtrl.text.trim();
      final lista = await PersonaService.listarClientes(
        buscar: texto.isNotEmpty ? texto : null,
      );
      if (!mounted) return;
      setState(() {
        _clientes = lista;
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

  Future<void> _abrirDialogoHabilitarPortal(Cliente cliente) async {
    final formKey = GlobalKey<FormState>();
    final correoCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool guardando = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: const Text('Habilitar acceso al portal'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Cliente: ${cliente.nombreCompleto}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Al crear su correo y contraseña podrá ingresar desde su teléfono conservando su historial de reservas.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || !v.contains('@') || !v.contains('.')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña inicial',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                ],
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
                        await PersonaService.habilitarPortal(
                          idCliente: cliente.idCliente,
                          correo: correoCtrl.text,
                          password: passCtrl.text,
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
                  : const Text('Habilitar portal'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Portal habilitado para ${cliente.nombreCompleto}. Ya puede iniciar sesión.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarClientes();
    }
  }

  Future<void> _abrirFormulario({Cliente? existente}) async {
    final formKey = GlobalKey<FormState>();
    final nombresCtrl = TextEditingController(text: existente?.nombres ?? '');
    final apellidosCtrl =
        TextEditingController(text: existente?.apellidos ?? '');
    final ciCtrl = TextEditingController(text: existente?.ciNit ?? '');
    final telCtrl = TextEditingController(text: existente?.telefono ?? '');
    final correoCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    bool crearCuentaPortal = false;
    bool guardando = false;
    final esEdicion = existente != null;
    final puedeHabilitarPortal =
        !esEdicion || (!existente.tieneCuentaPortal && existente.activo);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text(esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    TextFormField(
                      controller: ciCtrl,
                      decoration: const InputDecoration(labelText: 'CI / NIT'),
                      validator: (v) => (v == null || v.trim().length < 4)
                          ? 'Mínimo 4 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Mínimo 7 dígitos'
                          : null,
                    ),
                    if (esEdicion && existente.tieneCuentaPortal) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 20,
                              color: Colors.blue.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cuenta portal activa: ${existente.correo ?? ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (puedeHabilitarPortal) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          esEdicion
                              ? 'Habilitar acceso al portal'
                              : 'Crear cuenta de acceso al portal',
                        ),
                        subtitle: Text(
                          esEdicion
                              ? 'Asigna correo y contraseña conservando su historial de reservas'
                              : 'Opcional: déjalo desactivado para clientes presenciales',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: crearCuentaPortal,
                        onChanged: (v) =>
                            setStateModal(() => crearCuentaPortal = v),
                      ),
                      if (crearCuentaPortal) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                          ),
                          validator: (v) {
                            if (!crearCuentaPortal) return null;
                            if (v == null ||
                                !v.contains('@') ||
                                !v.contains('.')) {
                              return 'Correo inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña inicial',
                          ),
                          validator: (v) {
                            if (!crearCuentaPortal) return null;
                            if (v == null || v.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                      ],
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
                          await PersonaService.actualizarCliente(
                            idCliente: existente.idCliente,
                            nombres: nombresCtrl.text,
                            apellidos: apellidosCtrl.text,
                            ciNit: ciCtrl.text,
                            telefono: telCtrl.text,
                            activo: existente.activo,
                          );
                          if (crearCuentaPortal &&
                              !existente.tieneCuentaPortal) {
                            await PersonaService.habilitarPortal(
                              idCliente: existente.idCliente,
                              correo: correoCtrl.text,
                              password: passCtrl.text,
                            );
                          }
                        } else {
                          await PersonaService.crearCliente(
                            nombres: nombresCtrl.text,
                            apellidos: apellidosCtrl.text,
                            ciNit: ciCtrl.text,
                            telefono: telCtrl.text,
                            correo: crearCuentaPortal ? correoCtrl.text : null,
                            password: crearCuentaPortal ? passCtrl.text : null,
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
                  : Text(esEdicion ? 'Guardar cambios' : 'Registrar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esEdicion
                ? (crearCuentaPortal
                    ? 'Cliente actualizado y portal habilitado.'
                    : 'Cliente actualizado.')
                : 'Cliente registrado.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargarClientes();
    }
  }

  Future<void> _desactivar(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar cliente'),
        content: Text(
          '¿Seguro que deseas desactivar a ${cliente.nombreCompleto}?',
        ),
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
      await PersonaService.desactivarCliente(cliente.idCliente);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente desactivado.')),
      );
      await _cargarClientes();
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
    final filtro = _buscarCtrl.text.trim().toLowerCase();
    final visibles = filtro.isEmpty
        ? _clientes
        : _clientes.where((c) {
            return c.nombreCompleto.toLowerCase().contains(filtro) ||
                c.ciNit.toLowerCase().contains(filtro) ||
                c.telefono.toLowerCase().contains(filtro) ||
                (c.correo ?? '').toLowerCase().contains(filtro);
          }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscarCtrl,
                    onSubmitted: (_) => _cargarClientes(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, CI/NIT o teléfono...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscarCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _buscarCtrl.clear();
                                _cargarClientes();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _cargarClientes,
                  child: const Text('Buscar'),
                ),
              ],
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
                              onPressed: _cargarClientes,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : visibles.isEmpty
                        ? const Center(
                            child: Text('No se encontraron clientes.'),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarClientes,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                              itemCount: visibles.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final c = visibles[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: c.activo
                                          ? Colors.green.shade100
                                          : Colors.grey.shade300,
                                      child: Icon(
                                        c.tieneCuentaPortal
                                            ? Icons.verified_user_outlined
                                            : Icons.person_outline,
                                        color: c.activo
                                            ? Colors.green.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.nombreCompleto,
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
                                            color: c.tieneCuentaPortal
                                                ? Colors.blue.shade50
                                                : Colors.amber.shade50,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            c.tieneCuentaPortal
                                                ? 'Portal'
                                                : 'Presencial',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: c.tieneCuentaPortal
                                                  ? Colors.blue.shade800
                                                  : Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'ID #${c.idCliente} • CI/NIT: ${c.ciNit} • Tel: ${c.telefono}'
                                      '${c.correo != null ? '\n${c.correo}' : ''}',
                                    ),
                                    isThreeLine: c.correo != null,
                                    trailing: Wrap(
                                      children: [
                                        if (!c.tieneCuentaPortal && c.activo)
                                          IconButton(
                                            tooltip:
                                                'Habilitar acceso al portal',
                                            icon: Icon(
                                              Icons.vpn_key_outlined,
                                              color: Colors.blue.shade700,
                                            ),
                                            onPressed: () =>
                                                _abrirDialogoHabilitarPortal(c),
                                          ),
                                        IconButton(
                                          tooltip: 'Editar',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () =>
                                              _abrirFormulario(existente: c),
                                        ),
                                        if (c.activo)
                                          IconButton(
                                            tooltip: 'Desactivar',
                                            icon: Icon(
                                              Icons.person_off_outlined,
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
          ),
        ],
      ),
    );
  }
}