import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/reserva_model.dart';
import '../models/usuario_model.dart';
import '../services/reserva_service.dart';

class MiCuentaScreen extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onCerrarSesion;

  const MiCuentaScreen({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
  });

  @override
  State<MiCuentaScreen> createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  List<ConfigItem> _configs = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPoliticas();
  }

  Future<void> _cargarPoliticas() async {
    try {
      final data = await ReservaService.listarConfiguraciones();
      if (!mounted) return;
      setState(() {
        _configs = data;
        _cargando = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  String _tituloClave(String clave) {
    switch (clave) {
      case 'plazo_minimo_cancelacion_horas':
        return 'Plazo mínimo para cancelar o reprogramar';
      case 'porcentaje_anticipo_minimo':
        return 'Anticipo mínimo para confirmar reserva';
      default:
        return clave;
    }
  }

  String _valorFormateado(ConfigItem item) {
    if (item.clave == 'plazo_minimo_cancelacion_horas') {
      return '${item.valor} horas antes';
    }
    if (item.clave == 'porcentaje_anticipo_minimo') {
      return '${item.valor} %';
    }
    return item.valor;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.usuario.correo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rol: ${widget.usuario.rolLegible} • ID #${widget.usuario.idUsuario}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Políticas del complejo deportivo',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_configs.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No se pudieron cargar las políticas vigentes.'),
            ),
          )
        else
          ..._configs.map((c) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: Text(_tituloClave(c.clave)),
                subtitle: c.descripcion != null ? Text(c.descripcion!) : null,
                trailing: Text(
                  _valorFormateado(c),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
          ),
          onPressed: widget.onCerrarSesion,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}