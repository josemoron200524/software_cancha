import '../core/api_client.dart';
import '../models/admin_model.dart';

class AdminService {
  // ======================== REPORTES Y KPIs ========================
  static Future<ReporteResumen> obtenerReporteResumen({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final data = await ApiClient.get(
      '/reportes/resumen',
      queryParams: {
        'fecha_desde': fechaDesde,
        'fecha_hasta': fechaHasta,
      },
    ) as Map<String, dynamic>;
    return ReporteResumen.fromJson(data);
  }

  static Future<List<ReporteCancha>> obtenerReporteCanchas({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final data = await ApiClient.get(
      '/reportes/canchas',
      queryParams: {
        'fecha_desde': fechaDesde,
        'fecha_hasta': fechaHasta,
      },
    ) as List;
    return data
        .map((e) => ReporteCancha.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ReporteServicio>> obtenerReporteServicios({
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    final data = await ApiClient.get(
      '/reportes/servicios',
      queryParams: {
        'fecha_desde': fechaDesde,
        'fecha_hasta': fechaHasta,
      },
    ) as List;
    return data
        .map((e) => ReporteServicio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ======================== CANCHAS ========================
  static Future<List<CanchaAdmin>> listarCanchas() async {
    final data = await ApiClient.get(
      '/canchas',
      queryParams: {'solo_disponibles': 'false'},
    ) as List;
    return data
        .map((e) => CanchaAdmin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<CanchaAdmin> crearCancha({
    required String nombre,
    required String tipoSuperficie,
    required int capacidadJugadores,
    required double precioHora,
    required String estado,
    String? descripcion,
  }) async {
    final data = await ApiClient.post(
      '/canchas',
      body: {
        'nombre': nombre.trim(),
        'tipo_superficie': tipoSuperficie.trim(),
        'capacidad_jugadores': capacidadJugadores,
        'precio_hora': precioHora,
        'estado': estado,
        'descripcion': descripcion != null && descripcion.trim().isNotEmpty
            ? descripcion.trim()
            : null,
      },
    ) as Map<String, dynamic>;
    return CanchaAdmin.fromJson(data);
  }

  static Future<CanchaAdmin> actualizarCancha({
    required int idCancha,
    required String nombre,
    required String tipoSuperficie,
    required int capacidadJugadores,
    required double precioHora,
    required String estado,
    String? descripcion,
  }) async {
    final data = await ApiClient.put(
      '/canchas/$idCancha',
      body: {
        'nombre': nombre.trim(),
        'tipo_superficie': tipoSuperficie.trim(),
        'capacidad_jugadores': capacidadJugadores,
        'precio_hora': precioHora,
        'estado': estado,
        'descripcion': descripcion != null && descripcion.trim().isNotEmpty
            ? descripcion.trim()
            : null,
      },
    ) as Map<String, dynamic>;
    return CanchaAdmin.fromJson(data);
  }

  static Future<void> desactivarCancha(int idCancha) async {
    await ApiClient.delete('/canchas/$idCancha');
  }

  // ======================== SERVICIOS ========================
  static Future<List<ServicioAdmin>> listarServicios() async {
    final data = await ApiClient.get(
      '/servicios',
      queryParams: {'solo_activos': 'false'},
    ) as List;
    return data
        .map((e) => ServicioAdmin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ServicioAdmin> crearServicio({
    required String nombre,
    String? descripcion,
    required int duracionMinutos,
    required double precioAdicional,
  }) async {
    final data = await ApiClient.post(
      '/servicios',
      body: {
        'nombre': nombre.trim(),
        'descripcion': descripcion != null && descripcion.trim().isNotEmpty
            ? descripcion.trim()
            : null,
        'duracion_minutos': duracionMinutos,
        'precio_adicional': precioAdicional,
      },
    ) as Map<String, dynamic>;
    return ServicioAdmin.fromJson(data);
  }

  static Future<ServicioAdmin> actualizarServicio({
    required int idServicio,
    required String nombre,
    String? descripcion,
    required int duracionMinutos,
    required double precioAdicional,
    required bool activo,
  }) async {
    final data = await ApiClient.put(
      '/servicios/$idServicio',
      body: {
        'nombre': nombre.trim(),
        'descripcion': descripcion != null && descripcion.trim().isNotEmpty
            ? descripcion.trim()
            : null,
        'duracion_minutos': duracionMinutos,
        'precio_adicional': precioAdicional,
        'activo': activo,
      },
    ) as Map<String, dynamic>;
    return ServicioAdmin.fromJson(data);
  }

  static Future<void> desactivarServicio(int idServicio) async {
    await ApiClient.delete('/servicios/$idServicio');
  }

  // ======================== HORARIOS ========================
  static Future<List<HorarioCancha>> listarHorariosCancha(int idCancha) async {
    final data = await ApiClient.get('/horarios/cancha/$idCancha') as List;
    return data
        .map((e) => HorarioCancha.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<HorarioCancha> crearHorario({
    required int idCancha,
    required int diaSemana,
    required String horaApertura,
    required String horaCierre,
    bool activo = true,
  }) async {
    final data = await ApiClient.post(
      '/horarios',
      body: {
        'id_cancha': idCancha,
        'dia_semana': diaSemana,
        'hora_apertura': horaApertura,
        'hora_cierre': horaCierre,
        'activo': activo,
      },
    ) as Map<String, dynamic>;
    return HorarioCancha.fromJson(data);
  }

  static Future<HorarioCancha> actualizarHorario({
    required int idHorario,
    required String horaApertura,
    required String horaCierre,
    required bool activo,
  }) async {
    final data = await ApiClient.put(
      '/horarios/$idHorario',
      body: {
        'hora_apertura': horaApertura,
        'hora_cierre': horaCierre,
        'activo': activo,
      },
    ) as Map<String, dynamic>;
    return HorarioCancha.fromJson(data);
  }

  static Future<void> eliminarHorario(int idHorario) async {
    await ApiClient.delete('/horarios/$idHorario');
  }

  // ======================== EMPLEADOS ========================
  static Future<List<Empleado>> listarEmpleados({
    bool soloActivos = false,
  }) async {
    final data = await ApiClient.get(
      '/empleados',
      queryParams: {'solo_activos': soloActivos.toString()},
    ) as List;
    return data
        .map((e) => Empleado.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Empleado> crearEmpleado({
    required String nombres,
    required String apellidos,
    required String ci,
    required String telefono,
    required String cargo,
    required String rol,
    required String correo,
    required String password,
  }) async {
    final data = await ApiClient.post(
      '/empleados',
      body: {
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'ci': ci.trim(),
        'telefono': telefono.trim(),
        'cargo': cargo.trim(),
        'rol': rol,
        'correo': correo.trim(),
        'password': password,
      },
    ) as Map<String, dynamic>;
    return Empleado.fromJson(data);
  }

  static Future<Empleado> actualizarEmpleado({
    required int idEmpleado,
    required String nombres,
    required String apellidos,
    required String ci,
    required String telefono,
    required String cargo,
    required String rol,
    required bool activo,
  }) async {
    final data = await ApiClient.put(
      '/empleados/$idEmpleado',
      body: {
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'ci': ci.trim(),
        'telefono': telefono.trim(),
        'cargo': cargo.trim(),
        'rol': rol,
        'activo': activo,
      },
    ) as Map<String, dynamic>;
    return Empleado.fromJson(data);
  }

  static Future<void> desactivarEmpleado(int idEmpleado) async {
    await ApiClient.delete('/empleados/$idEmpleado');
  }

  // ======================== CONFIGURACIÓN ========================
  static Future<List<ReglaNegocio>> listarReglas() async {
    final data = await ApiClient.get('/configuracion') as List;
    return data
        .map((e) => ReglaNegocio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ReglaNegocio> actualizarRegla({
    required String clave,
    required String valor,
    String? descripcion,
  }) async {
    final data = await ApiClient.put(
      '/configuracion/$clave',
      body: {
        'valor': valor.trim(),
        'descripcion': descripcion != null && descripcion.trim().isNotEmpty
            ? descripcion.trim()
            : null,
      },
    ) as Map<String, dynamic>;
    return ReglaNegocio.fromJson(data);
  }
}