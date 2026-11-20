import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import 'agenda_screen.dart';
import 'catalogos_admin_screen.dart';
import 'clientes_screen.dart';
import 'dashboard_screen.dart';
import 'disponibilidad_screen.dart';
import 'login_screen.dart';
import 'mi_cuenta_screen.dart';
import 'mis_reservas_screen.dart';
import 'pagos_screen.dart';
import 'personas_admin_screen.dart';

class _SeccionMenu {
  final String titulo;
  final IconData icono;
  final Widget vista;

  const _SeccionMenu({
    required this.titulo,
    required this.icono,
    required this.vista,
  });
}

class HomeScreen extends StatefulWidget {
  final Usuario usuario;

  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceActual = 0;

  List<_SeccionMenu> get _secciones {
    switch (widget.usuario.rol) {
      case 'administrador':
        return const [
          _SeccionMenu(
            titulo: 'Dashboard',
            icono: Icons.analytics_outlined,
            vista: DashboardScreen(),
          ),
          _SeccionMenu(
            titulo: 'Agenda',
            icono: Icons.calendar_month_outlined,
            vista: AgendaScreen(),
          ),
          _SeccionMenu(
            titulo: 'Catálogos',
            icono: Icons.stadium_outlined,
            vista: CatalogosAdminScreen(),
          ),
          _SeccionMenu(
            titulo: 'Personas',
            icono: Icons.groups_outlined,
            vista: PersonasAdminScreen(),
          ),
          _SeccionMenu(
            titulo: 'Pagos',
            icono: Icons.payments_outlined,
            vista: PagosScreen(),
          ),
        ];
      case 'recepcionista':
        return [
          const _SeccionMenu(
            titulo: 'Agenda',
            icono: Icons.calendar_month_outlined,
            vista: AgendaScreen(),
          ),
          const _SeccionMenu(
            titulo: 'Clientes',
            icono: Icons.people_outline,
            vista: ClientesScreen(),
          ),
          const _SeccionMenu(
            titulo: 'Pagos',
            icono: Icons.payments_outlined,
            vista: PagosScreen(),
          ),
          _SeccionMenu(
            titulo: 'Disponibilidad',
            icono: Icons.schedule_outlined,
            vista: DisponibilidadScreen(usuario: widget.usuario),
          ),
        ];
      default:
        return [
          _SeccionMenu(
            titulo: 'Disponibilidad',
            icono: Icons.stadium_outlined,
            vista: DisponibilidadScreen(
              usuario: widget.usuario,
              onReservaCreada: () => setState(() => _indiceActual = 1),
            ),
          ),
          const _SeccionMenu(
            titulo: 'Mis Reservas',
            icono: Icons.event_note_outlined,
            vista: MisReservasScreen(),
          ),
          _SeccionMenu(
            titulo: 'Mi Cuenta',
            icono: Icons.person_outline,
            vista: MiCuentaScreen(
              usuario: widget.usuario,
              onCerrarSesion: _cerrarSesion,
            ),
          ),
        ];
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final secciones = _secciones;
    final actual = secciones[_indiceActual];
    final esPantallaAncha = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.sports_soccer),
            const SizedBox(width: 8),
            Text('Canchas • ${actual.titulo}'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: const Icon(Icons.shield_outlined, size: 18),
              label: Text(widget.usuario.rolLegible),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: esPantallaAncha
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _indiceActual,
                  onDestinationSelected: (i) =>
                      setState(() => _indiceActual = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: secciones
                      .map(
                        (s) => NavigationRailDestination(
                          icon: Icon(s.icono),
                          label: Text(s.titulo),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: actual.vista),
              ],
            )
          : actual.vista,
      bottomNavigationBar: esPantallaAncha
          ? null
          : NavigationBar(
              selectedIndex: _indiceActual,
              onDestinationSelected: (i) => setState(() => _indiceActual = i),
              destinations: secciones
                  .map(
                    (s) => NavigationDestination(
                      icon: Icon(s.icono),
                      label: s.titulo,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}