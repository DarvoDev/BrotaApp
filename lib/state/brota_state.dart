import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/catalogo.dart';
import '../models/modelos.dart';
import '../services/almacen.dart';
import '../services/cifrado.dart';
import '../services/pdf_historial.dart';

/// Estado de la app y lógica de los diecinueve casos de uso del catálogo.
///
/// Corresponde a la clase Usuario del diagrama (xpTotal y las operaciones
/// registrarAnimo, completarActividad, activarSOS) junto con sus
/// composiciones: Cuenta, Avatar, Mascota, Racha, RegistroAnimo,
/// ContactoConfianza, Cumplimiento, Recordatorio, MensajeValidado,
/// Publicación y las colas de sincronización.
///
/// Todo se guarda cifrado en el dispositivo; no necesita conexión (RNF-02/03).
class BrotaState extends ChangeNotifier {
  BrotaState({required Almacen almacen, DateTime Function()? ahora})
    : _almacen = almacen, // ignore: prefer_initializing_formals
      _ahora = ahora ?? DateTime.now;

  final Almacen _almacen;
  final DateTime Function() _ahora;

  int xpTotal = 0;
  Racha racha = Racha();
  final List<TareaPersonalizada> tareas = [];
  final Map<String, RegistroAnimo> animos = {};
  final List<Cumplimiento> cumplimientos = [];
  final Set<String> descansos = {};
  final List<ContactoConfianza> contactos = [];

  /// Usos del botón SOS: solo en el dispositivo, solo para el Usuario.
  final List<Map<String, dynamic>> usosSos = [];

  // --------------------------------------- CU-01 a CU-04: cuenta y perfil ---
  Cuenta? cuenta;
  String avatar = '🌱';
  String mascota = '🐶';
  String mascotaNombre = 'Brotito';

  // ---------------------------- CU-06 y CU-18: catálogo administrable ------
  final List<Microactividad> catalogo = List.of(CatalogoMicroactividades.todas);
  final List<String> metasExtra = [];

  // --------------------------------------- CU-08: recordatorios amables ----
  final List<Recordatorio> recordatorios = [];

  // ------------------------------- CU-11 y CU-19: recursos y mensajes ------
  final List<RecursoAyuda> recursos = List.of(recursosAyuda);
  final List<MensajeValidado> mensajes = List.of(mensajesPorDefecto);

  // --------------------------------------- CU-14: muro de aliento ----------
  final List<Publicacion> publicaciones = List.of(publicacionesPorDefecto);

  // -------------------------------------- RNF-07: cola de sincronización ---
  final List<EntradaSincronizacion> cambiosPendientes = [];
  bool datosSincronizados = true;

  static const String _claveCifrado = 'brota-clave-local-v2';
  final Map<String, int> _contadores = {};

  List<String> _metasHoy = [];
  String? _diaMetas;
  String? _ultimoDiaCerrado;
  String? _semanaEscudos;
  String? _animoOmitido;
  int _tareasCreadas = 0;
  MensajeCierre? mensajeCierre;

  /// true si el último guardado local falló (CU-05, excepción E1).
  bool falloGuardado = false;

  // ------------------------------------------------------------ lecturas ---

  DateTime get hoy => soloDia(_ahora());
  String get _hoyClave => claveDia(hoy);

  int get nivel => 1 + xpTotal ~/ xpPorNivel;
  int get xpEnNivel => xpTotal % xpPorNivel;

  /// Clave fija del dispositivo: RNF-02 evita que los datos se lean como texto.
  String get claveCifrado => _claveCifrado;

  bool get tieneCuenta => cuenta != null;
  bool get esAdmin => cuenta?.rol == Rol.administrador;
  String get nombreUsuario {
    final n = cuenta?.nombre.trim() ?? '';
    return n.isEmpty ? 'ahí' : n;
  }

  Microactividad? microPorId(String id) {
    for (final m in catalogo) {
      if (m.id == id) return m;
    }
    return CatalogoMicroactividades.porId(id);
  }

  RegistroAnimo? get animoDeHoy => animos[_hoyClave];

  /// El chequeo se pide una vez al día; «ahora no» lo silencia ese día (A1).
  bool get debePreguntarAnimo =>
      animoDeHoy == null && _animoOmitido != _hoyClave;

  List<Microactividad> get metasHoy => [
    for (final id in _metasHoy)
      if (microPorId(id) != null) microPorId(id)!,
  ];

  /// Metas del día, incluidas las añadidas desde el catálogo (CU-06).
  List<Microactividad> get metasTotalesHoy => [
    ...metasHoy,
    for (final id in metasExtra)
      if (microPorId(id) != null && !_metasHoy.contains(id)) microPorId(id)!,
  ];

  bool completadaHoy(Actividad a) => cumplimientos.any(
    (c) => c.dia == _hoyClave && c.actividadId == a.id,
  );

  bool huboActividad(DateTime d) {
    final k = claveDia(d);
    return cumplimientos.any((c) => c.dia == k);
  }

  bool fueDescanso(DateTime d) => descansos.contains(claveDia(d));

  int get completadasHoy =>
      cumplimientos.where((c) => c.dia == _hoyClave).length;

  /// Mensaje amable que acompaña a las metas del día (CU-05, paso 6).
  String get mensajeDelDia {
    final r = animoDeHoy;
    if (r == null) return 'Un pasito a la vez 🌱';
    if (r.esBajo()) return 'Hoy toca algo suave 🌤️ Elegí metas ligeras para ti.';
    if (r.esAlto()) return 'Hoy hay un reto extra, solo si te nace ✨';
    return 'Un pasito a la vez 🌱';
  }

  /// CU-05, flujo A3: ánimo en el nivel más bajo 3 días seguidos.
  bool get animoMuyBajoSostenido {
    for (var i = 0; i < 3; i++) {
      final r = animos[claveDia(sumarDias(hoy, -i))];
      if (r == null || r.animo != 1) return false;
    }
    return true;
  }

  /// CU-10, flujo A3: días seguidos sin actividad hasta ayer.
  int get diasInactivosSeguidos {
    var n = 0;
    while (n < 30 && fueDescanso(sumarDias(hoy, -(n + 1)))) {
      n++;
    }
    return n;
  }

  bool get sugerirRecursos =>
      animoMuyBajoSostenido || (diasInactivosSeguidos >= 3 && completadasHoy == 0);

  DateTime get proximaRenovacion => sumarDias(lunesDe(hoy), 7);

  // ---------------------------------------- CU-08 Recordatorios amables ----

  /// A3 de CU-10: con ánimo bajo o inactividad, se reduce la frecuencia.
  bool get modoRecordatorioSuave =>
      animoMuyBajoSostenido || diasInactivosSeguidos >= 2;

  List<Recordatorio> get recordatoriosDeHoy => [
    for (final r in recordatorios)
      if (r.activo && r.aplicaHoy(hoy)) r,
  ];

  // ----------------------------------- CU-12 Mensajes motivacionales ------

  MensajeValidado get mensajeMotivacionalDelDia =>
      mensajes.isEmpty
      ? const MensajeValidado(
        id: 'msg-base',
        texto: 'Un pasito a la vez también es avanzar 🌱',
        categoria: 'Aliento',
        validadoPor: 'Equipo Brota',
      )
      : mensajes[hoy.day % mensajes.length];

  // ------------------------------------ CU-14 Compartir y aliento ---------

  /// Logro anónimo que se puede copiar o compartir sin exponer datos.
  String get logroCompartible =>
      'Llevo ${racha.dias} día(s) de racha y $xpTotal Exp en Brota. '
      'Un pasito a la vez también es avanzar 🌱';

  // --------------------------------- CU-15/16 Panel y resumen -------------

  Set<String> get diasConActividad => {
    for (final c in cumplimientos) c.dia,
  };

  int get diasActivos => diasConActividad.length;

  int get rachaMaxima {
    final dias = diasConActividad.toList()..sort();
    var mejor = 0;
    var actual = 0;
    DateTime? anterior;
    for (final d in dias) {
      final fecha = diaDeClave(d);
      if (anterior != null && sumarDias(anterior, 1) != fecha) actual = 0;
      actual++;
      if (actual > mejor) mejor = actual;
      anterior = fecha;
    }
    return mejor;
  }

  double get animoPromedio {
    if (animos.isEmpty) return 0;
    return animos.values.map((a) => a.animo).reduce((a, b) => a + b) /
        animos.length;
  }

  /// Porcentaje de días con actividad desde el primer registro.
  double get porcentajeCumplimiento {
    if (diasConActividad.isEmpty) return 0;
    final fechas = diasConActividad.map(diaDeClave).toList()..sort();
    final total = max(1, hoy.difference(fechas.first).inDays + 1);
    return (diasActivos * 100) / total;
  }

  Map<String, dynamic> resumenSemanal({DateTime? inicio}) {
    final lunes = lunesDe(inicio ?? hoy);
    final semana = [for (var i = 0; i < 7; i++) sumarDias(lunes, i)];
    final dias = [
      for (final d in semana)
        {
          'dia': claveDia(d),
          'actividad': huboActividad(d),
          'descanso': fueDescanso(d),
          'xp': cumplimientos
              .where((c) => c.dia == claveDia(d))
              .fold(0, (s, c) => s + c.xpOtorgada),
        },
    ];
    final animosSemana = [
      for (final d in semana)
        if (animos[claveDia(d)] != null) animos[claveDia(d)]!.animo,
    ];
    return {
      'inicio': claveDia(lunes),
      'fin': claveDia(sumarDias(lunes, 6)),
      'dias': dias,
      'activos': dias.where((d) => d['actividad'] as bool).length,
      'descansos': dias.where((d) => d['descanso'] as bool).length,
      'xp': dias.fold(0, (s, d) => s + (d['xp'] as int)),
      'animoPromedio': animosSemana.isEmpty
          ? 0.0
          : animosSemana.reduce((a, b) => a + b) / animosSemana.length,
    };
  }

  List<int> xpDeLosUltimos(int dias) => [
    for (var i = dias - 1; i >= 0; i--)
      cumplimientos
          .where((c) => c.dia == claveDia(sumarDias(hoy, -i)))
          .fold(0, (s, c) => s + c.xpOtorgada),
  ];

  bool get hayCambiosPendientes => cambiosPendientes.isNotEmpty;

  // -------------------------------------------------------------- inicio ---

  Future<void> iniciar() async {
    try {
      final texto = await _almacen.leer();
      if (texto != null) {
        Map<String, dynamic>? datos;
        try {
          datos = jsonDecode(
            CifradoLocal.descifrar(texto, clave: _claveCifrado),
          ) as Map<String, dynamic>;
        } catch (_) {
          // Compatibilidad con versiones anteriores guardadas en texto.
          try {
            datos = jsonDecode(texto) as Map<String, dynamic>;
          } catch (_) {
            datos = null;
          }
        }
        if (datos != null) _cargar(datos);
      }
    } catch (_) {
      // Datos ilegibles: se empieza de cero en vez de impedir abrir la app.
    }
    await abrirDia();
  }

  /// Se llama al abrir la app y al volver a primer plano. Cierra los días
  /// pendientes (CU-10) y prepara las metas del día.
  Future<void> abrirDia() async {
    final antes = '$_ultimoDiaCerrado|$_diaMetas|$_semanaEscudos';
    _cerrarDiasPendientes();
    if (_diaMetas != _hoyClave) {
      _diaMetas = _hoyClave;
      _metasHoy = _generarMetas(animoDeHoy);
    }
    if (antes != '$_ultimoDiaCerrado|$_diaMetas|$_semanaEscudos') {
      await _guardar();
      notifyListeners();
    }
  }

  // --------------------------------------- CU-10 Proteger racha flexible ---

  /// Cierre automático del día. Si la app estuvo cerrada, evalúa cada día
  /// pendiente en orden al siguiente inicio (excepción E1).
  void _cerrarDiasPendientes() {
    final ayer = sumarDias(hoy, -1);
    if (_ultimoDiaCerrado == null) {
      _ultimoDiaCerrado = claveDia(ayer);
      _semanaEscudos = claveDia(lunesDe(hoy));
      return;
    }
    var d = sumarDias(diaDeClave(_ultimoDiaCerrado!), 1);
    var escudosUsados = 0;
    var reiniciada = false;
    var rachaPerdida = 0;
    while (d.isBefore(hoy)) {
      _renovarEscudos(d);
      if (!huboActividad(d)) {
        if (racha.dias > 0) {
          if (racha.aplicarCongelamiento()) {
            escudosUsados++;
          } else {
            // A2: sin congelamientos. Solo la racha vuelve a 0;
            // XP, nivel y mascota no se tocan.
            rachaPerdida = racha.dias;
            racha.reiniciar();
            reiniciada = true;
          }
        }
        descansos.add(claveDia(d)); // «descanso», nunca «fallo»
      }
      d = sumarDias(d, 1);
    }
    _renovarEscudos(hoy);
    if (diaDeClave(_ultimoDiaCerrado!).isBefore(ayer)) {
      _ultimoDiaCerrado = claveDia(ayer);
    }
    if (escudosUsados > 0 || reiniciada) {
      mensajeCierre = MensajeCierre(
        reiniciada: reiniciada,
        escudosUsados: escudosUsados,
        rachaDias: reiniciada ? rachaPerdida : racha.dias,
      );
    }
  }

  void _renovarEscudos(DateTime d) {
    final semana = claveDia(lunesDe(d));
    if (_semanaEscudos != semana) {
      _semanaEscudos = semana;
      racha.congelamientos = congelamientosPorSemana;
    }
  }

  Future<void> descartarMensajeCierre() async {
    mensajeCierre = null;
    notifyListeners();
    await _guardar();
  }

  // ------------------------------- CU-05 Registrar estado de ánimo diario ---

  /// Guarda (o actualiza, A2) el ánimo del día y ajusta las metas (CU-05a).
  Future<void> registrarAnimo(int animo, int energia) async {
    final r = RegistroAnimo(dia: _hoyClave, animo: animo, energia: energia);
    animos[_hoyClave] = r;
    _diaMetas = _hoyClave;
    _metasHoy = _generarMetas(r);
    _registrarCambio('ánimo registrado');
    notifyListeners();
    await _guardar();
  }

  Future<void> omitirAnimo() async {
    _animoOmitido = _hoyClave;
    notifyListeners();
    await _guardar();
  }

  /// CU-05a Ajustar metas del día, por reglas (sin IA):
  /// ánimo o energía bajos → 2 metas de esfuerzo ligero;
  /// ánimo y energía altos → se agrega un reto de esfuerzo alto;
  /// en otro caso → 2 ligeras y 1 media.
  List<String> _generarMetas(RegistroAnimo? r) {
    final List<int> esfuerzos;
    if (r == null) {
      esfuerzos = [1, 1, 2];
    } else if (r.esBajo()) {
      esfuerzos = [1, 1];
    } else if (r.esAlto()) {
      esfuerzos = [1, 2, 3];
    } else {
      esfuerzos = [1, 1, 2];
    }
    // Lo ya completado hoy se conserva aunque cambie el ajuste.
    final ids = <String>[
      for (final c in cumplimientos)
        if (c.dia == _hoyClave && microPorId(c.actividadId) != null)
          c.actividadId,
    ];
    final pendientes = <String>[];
    // Rota el catálogo con la fecha para que las metas varíen cada día.
    final semilla = hoy.difference(DateTime(hoy.year)).inDays;
    for (final e in esfuerzos) {
      final opciones = catalogo.where((m) => m.esfuerzo == e).toList();
      for (var i = 0; i < opciones.length; i++) {
        final m = opciones[(semilla + i) % opciones.length];
        if (!ids.contains(m.id) && !pendientes.contains(m.id)) {
          pendientes.add(m.id);
          break;
        }
      }
    }
    final faltan = esfuerzos.length - ids.length;
    return [...ids, ...pendientes.take(faltan < 0 ? 0 : faltan)];
  }

  // ------------------------------------ CU-07 Crear tarea personalizada ---

  /// Devuelve un mensaje de error para el formulario, o null si es válida.
  String? validarTitulo(String titulo) {
    final t = titulo.trim();
    if (t.isEmpty) return 'Escribe un nombre para tu tarea';
    if (t.length > 60) return 'Máximo 60 caracteres';
    if (tareas.any((x) => x.titulo.toLowerCase() == t.toLowerCase())) {
      return 'Ya tienes una tarea con ese nombre';
    }
    return null;
  }

  /// Crea la tarea con su categoría y nivel de esfuerzo (CU-07a).
  Future<TareaPersonalizada> crearTarea(
    String titulo,
    String categoria,
    int esfuerzo,
  ) async {
    final t = TareaPersonalizada(
      id: 't-${++_tareasCreadas}',
      titulo: titulo.trim(),
      categoria: categoria,
      esfuerzo: esfuerzo,
    );
    tareas.add(t);
    _registrarCambio('tarea creada');
    notifyListeners();
    await _guardar();
    return t;
  }

  /// Quita la tarea de la lista. Lo ya ganado con ella se conserva.
  Future<void> eliminarTarea(TareaPersonalizada t) async {
    tareas.removeWhere((x) => x.id == t.id);
    notifyListeners();
    await _guardar();
  }

  // ------------------------------------------- CU-09 Completar actividad ---

  /// Registra el cumplimiento, otorga XP (CU-09a) y sube de nivel si la XP
  /// alcanza el umbral (CU-09b). La pantalla se actualiza de inmediato y el
  /// guardado ocurre después (RNF-01).
  ResultadoCompletar? completarActividad(Actividad a) {
    if (completadaHoy(a)) return null;
    final nivelAntes = nivel;
    final xp = a.calcularXP();
    if (completadasHoy == 0) racha.dias++;
    cumplimientos.add(
      Cumplimiento(
        dia: _hoyClave,
        actividadId: a.id,
        titulo: a.titulo,
        xpOtorgada: xp,
      ),
    );
    xpTotal += xp;
    _registrarCambio('actividad completada');
    notifyListeners();
    _guardar();
    return ResultadoCompletar(xp: xp, subioNivel: nivel > nivelAntes, nivel: nivel);
  }

  /// Deshace un cumplimiento de hoy marcado por error.
  void desmarcarActividad(Actividad a) {
    final i = cumplimientos.indexWhere(
      (c) => c.dia == _hoyClave && c.actividadId == a.id,
    );
    if (i < 0) return;
    xpTotal -= cumplimientos[i].xpOtorgada;
    if (xpTotal < 0) xpTotal = 0;
    cumplimientos.removeAt(i);
    if (completadasHoy == 0 && racha.dias > 0) racha.dias--;
    notifyListeners();
    _guardar();
  }

  // ------------------------------------ CU-13 Activar botón SOS emocional ---

  Future<void> agregarContacto(String nombre, String telefono) async {
    contactos.add(
      ContactoConfianza(nombre: nombre.trim(), telefono: telefono.trim()),
    );
    notifyListeners();
    await _guardar();
  }

  Future<void> eliminarContacto(ContactoConfianza c) async {
    contactos.remove(c);
    notifyListeners();
    await _guardar();
  }

  /// Registra el uso en el dispositivo (paso 6). No cambia XP ni racha, y
  /// no se comparte con nadie.
  Future<void> activarSOS(String opcion) async {
    usosSos.add({'fecha': _ahora().toIso8601String(), 'opcion': opcion});
    await _guardar();
  }

  // ------------------------------- CU-01 / CU-02 Registro e inicio sesión --

  String _hash(String texto) => sha256.convert(utf8.encode(texto)).toString();

  String _nuevoId(String prefijo) {
    final n = (_contadores[prefijo] ?? 0) + 1;
    _contadores[prefijo] = n;
    return '$prefijo-$n';
  }

  String? validarRegistro({
    required String correo,
    required String password,
    required String nombre,
  }) {
    final c = correo.trim().toLowerCase();
    if (!c.contains('@') || !c.contains('.')) {
      return 'Escribe un correo válido';
    }
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    if (nombre.trim().isEmpty) return 'Escribe tu nombre';
    if (cuenta?.correo == c) {
      return 'Ya existe una cuenta con ese correo';
    }
    return null;
  }

  /// CU-01: crea la cuenta local. Guarda el hash con sal, nunca la contraseña.
  Future<bool> registrarse({
    required String correo,
    required String password,
    required String nombre,
    String apellidos = '',
    String fechaNac = '',
    Rol rol = Rol.usuario,
  }) async {
    final error = validarRegistro(
      correo: correo,
      password: password,
      nombre: nombre,
    );
    if (error != null) return false;
    final sal = _hash(
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
    );
    cuenta = Cuenta(
      correo: correo.trim().toLowerCase(),
      hash: _hash('$sal$password'),
      sal: sal,
      nombre: nombre.trim(),
      apellidos: apellidos.trim(),
      fechaNac: fechaNac.trim(),
      rol: rol,
    );
    _registrarCambio('cuenta creada');
    notifyListeners();
    await _guardar();
    return true;
  }

  /// CU-02: compara el hash; no guarda sesiones en texto plano.
  Future<bool> iniciarSesion(String correo, String password) async {
    final c = cuenta;
    if (c == null || c.correo != correo.trim().toLowerCase()) return false;
    if (!c.verificar(password, _hash)) return false;
    _registrarCambio('inicio de sesión');
    notifyListeners();
    await _guardar();
    return true;
  }

  /// La app funciona como invitada: el núcleo no exige cuenta (RF-01/RNF-03).
  Future<void> continuarComoInvitado() async {
    _registrarCambio('modo invitado');
    notifyListeners();
    await _guardar();
  }

  Future<void> cerrarSesion() async {
    cuenta = null;
    _registrarCambio('cierre de sesión');
    notifyListeners();
    await _guardar();
  }

  // --------------------------- CU-03 / CU-04 Avatar y mascota -------------

  Future<void> personalizarAvatar(String emoji) async {
    avatar = emoji;
    _registrarCambio('avatar personalizado');
    notifyListeners();
    await _guardar();
  }

  Future<void> elegirMascota(String emoji, String nombre) async {
    mascota = emoji;
    mascotaNombre = nombre.trim().isEmpty ? 'Brotito' : nombre.trim();
    _registrarCambio('mascota elegida');
    notifyListeners();
    await _guardar();
  }

  // ------------------------------ CU-06 / CU-18 Catálogo ------------------

  /// CU-18: solo el Administrador modifica el catálogo de microactividades.
  Future<Microactividad> agregarMicroactividad({
    required String titulo,
    required int esfuerzo,
    required int duracionMin,
  }) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    final m = Microactividad(
      id: _nuevoId('m'),
      titulo: titulo.trim(),
      esfuerzo: esfuerzo.clamp(1, 3),
      duracionMin: max(1, duracionMin),
    );
    catalogo.add(m);
    _registrarCambio('microactividad agregada');
    notifyListeners();
    await _guardar();
    return m;
  }

  Future<void> actualizarMicroactividad(
    String id, {
    String? titulo,
    int? esfuerzo,
    int? duracionMin,
  }) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    final i = catalogo.indexWhere((m) => m.id == id);
    if (i < 0) return;
    catalogo[i] = catalogo[i].copiaCon(
      tituloNuevo: titulo?.trim(),
      esfuerzoNuevo: esfuerzo?.clamp(1, 3),
      duracionNueva: duracionMin,
    );
    _registrarCambio('microactividad actualizada');
    notifyListeners();
    await _guardar();
  }

  Future<void> eliminarMicroactividad(String id) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    catalogo.removeWhere((m) => m.id == id);
    _metasHoy.remove(id);
    metasExtra.remove(id);
    _registrarCambio('microactividad eliminada');
    notifyListeners();
    await _guardar();
  }

  /// CU-06: llevar una actividad del catálogo a las metas de hoy.
  Future<void> agregarMetaDelCatalogo(String id) async {
    if (microPorId(id) == null || metasExtra.contains(id) || _metasHoy.contains(id)) {
      return;
    }
    metasExtra.add(id);
    _registrarCambio('meta añadida desde catálogo');
    notifyListeners();
    await _guardar();
  }

  Future<void> quitarMetaExtra(String id) async {
    metasExtra.remove(id);
    notifyListeners();
    await _guardar();
  }

  // ------------------------------- CU-08 Recordatorios --------------------

  Future<void> guardarRecordatorio(Recordatorio r) async {
    final i = recordatorios.indexWhere((x) => x.id == r.id);
    if (i < 0) {
      recordatorios.add(r);
    } else {
      recordatorios[i] = r;
    }
    _registrarCambio('recordatorio guardado');
    notifyListeners();
    await _guardar();
  }

  Future<void> eliminarRecordatorio(String id) async {
    recordatorios.removeWhere((r) => r.id == id);
    notifyListeners();
    await _guardar();
  }

  // ------------------------- CU-11 / CU-19 Directorio de ayuda ------------

  Future<RecursoAyuda> agregarRecurso({
    required String nombre,
    required String telefono,
    String descripcion = '',
    bool esEmergencia = false,
    String categoria = 'Ayuda',
  }) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    final r = RecursoAyuda(
      id: _nuevoId('r'),
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      descripcion: descripcion.trim(),
      esEmergencia: esEmergencia,
      categoria: categoria,
    );
    recursos.add(r);
    _registrarCambio('recurso agregado');
    notifyListeners();
    await _guardar();
    return r;
  }

  Future<void> eliminarRecurso(String id) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    recursos.removeWhere((r) => r.id == id);
    _registrarCambio('recurso eliminado');
    notifyListeners();
    await _guardar();
  }

  // ----------------------- CU-12 / CU-19 Mensajes validados ---------------

  Future<MensajeValidado> agregarMensaje({
    required String texto,
    String categoria = 'Aliento',
    String validadoPor = 'Equipo Brota',
  }) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    final m = MensajeValidado(
      id: _nuevoId('msg'),
      texto: texto.trim(),
      categoria: categoria,
      validadoPor: validadoPor,
    );
    mensajes.add(m);
    _registrarCambio('mensaje validado agregado');
    notifyListeners();
    await _guardar();
    return m;
  }

  Future<void> eliminarMensaje(String id) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    mensajes.removeWhere((m) => m.id == id);
    _registrarCambio('mensaje eliminado');
    notifyListeners();
    await _guardar();
  }

  // --------------------------- CU-14 Muro de aliento ----------------------

  Future<Publicacion> publicarAliento(String texto) async {
    final t = texto.trim();
    if (t.isEmpty || t.length > 240) {
      throw const FormatException('Escribe entre 1 y 240 caracteres');
    }
    final p = Publicacion(
      id: _nuevoId('pub'),
      contenido: t,
      fecha: claveDia(hoy),
    );
    publicaciones.insert(0, p);
    _registrarCambio('mensaje de aliento publicado');
    notifyListeners();
    await _guardar();
    return p;
  }

  // -------------------------------- CU-17 Exportar historial PDF ----------

  /// Genera el PDF localmente; el límite de 2 MB se aplica en PdfHistorial.
  Future<Uint8List> exportarPdf() async {
    final lineas = <String>[
      'Resumen general',
      'Nivel: $nivel   Experiencia total: $xpTotal Exp',
      'Racha actual: ${racha.dias} dia(s)   Racha maxima: $rachaMaxima dia(s)',
      'Dias con actividad: $diasActivos   Cumplimiento: ${porcentajeCumplimiento.toStringAsFixed(1)}%',
      'Animo promedio: ${animoPromedio.toStringAsFixed(1)} de 5',
      '',
      'Ultimos 30 dias',
      for (final valor in xpDeLosUltimos(30))
        'XP del dia: $valor',
      '',
      'Cumplimientos registrados',
      for (final c in [...cumplimientos]..sort((a, b) => a.dia.compareTo(b.dia)))
        '${c.dia}  ${c.titulo}  +${c.xpOtorgada} Exp',
      '',
      'Registros de animo',
      for (final r in [...animos.values]..sort((a, b) => a.dia.compareTo(b.dia)))
        '${r.dia}  animo ${r.animo}/5  energia ${r.energia}/3',
      '',
      'Descansos protegidos',
      for (final d in [...descansos]..sort()) d,
      '',
      'Brota acompana, pero no sustituye la atencion profesional.',
    ];
    return PdfHistorial.generar(
      'Brota - Historial de progreso',
      lineas,
      subtitulo: 'Generado el ${claveDia(hoy)} - datos guardados solo en este dispositivo',
    );
  }

  // --------------------------- RNF-07 Sincronización ----------------------

  void _registrarCambio(String operacion) {
    cambiosPendientes.add(
      EntradaSincronizacion(
        id: _nuevoId('sync'),
        operacion: operacion,
        fecha: _ahora().toIso8601String(),
      ),
    );
    datosSincronizados = false;
  }

  /// Sin servidor, la "sincronización" confirma la cola local sin duplicar.
  /// Al haber red, aquí se enviarían las entradas y se borrarían tras el ACK.
  Future<void> sincronizar() async {
    cambiosPendientes.clear();
    datosSincronizados = true;
    notifyListeners();
    await _guardar();
  }

  // -------------------------------------------------------- persistencia ---

  Future<void> _guardar() async {
    bool fallo;
    try {
      await _almacen.guardar(
        CifradoLocal.cifrar(jsonEncode(_aJson()), clave: _claveCifrado),
      );
      fallo = false;
    } catch (_) {
      fallo = true;
    }
    if (fallo != falloGuardado) {
      falloGuardado = fallo;
      notifyListeners();
    }
  }

  Map<String, dynamic> _aJson() => {
    'version': 2,
    'xpTotal': xpTotal,
    'racha': racha.toJson(),
    'tareas': [for (final t in tareas) t.toJson()],
    'animos': [for (final r in animos.values) r.toJson()],
    'cumplimientos': [for (final c in cumplimientos) c.toJson()],
    'descansos': descansos.toList(),
    'contactos': [for (final c in contactos) c.toJson()],
    'usosSos': usosSos,
    'metasHoy': _metasHoy,
    'diaMetas': _diaMetas,
    'ultimoDiaCerrado': _ultimoDiaCerrado,
    'semanaEscudos': _semanaEscudos,
    'animoOmitido': _animoOmitido,
    'tareasCreadas': _tareasCreadas,
    'mensajeCierre': mensajeCierre?.toJson(),
    'cuenta': cuenta?.toJson(),
    'avatar': avatar,
    'mascota': mascota,
    'mascotaNombre': mascotaNombre,
    'catalogo': [for (final m in catalogo) m.toJson()],
    'metasExtra': metasExtra,
    'recordatorios': [for (final r in recordatorios) r.toJson()],
    'recursos': [for (final r in recursos) r.toJson()],
    'mensajes': [for (final m in mensajes) m.toJson()],
    'publicaciones': [for (final p in publicaciones) p.toJson()],
    'cambiosPendientes': [for (final c in cambiosPendientes) c.toJson()],
    'datosSincronizados': datosSincronizados,
    'contadores': _contadores,
  };

  void _cargar(Map<String, dynamic> j) {
    List<Map<String, dynamic>> lista(String k) =>
        ((j[k] as List?) ?? []).cast<Map<String, dynamic>>();

    xpTotal = j['xpTotal'] as int? ?? 0;
    if (j['racha'] != null) {
      racha = Racha.fromJson(j['racha'] as Map<String, dynamic>);
    }
    tareas
      ..clear()
      ..addAll(lista('tareas').map(TareaPersonalizada.fromJson));
    animos.clear();
    for (final r in lista('animos').map(RegistroAnimo.fromJson)) {
      animos[r.dia] = r;
    }
    cumplimientos
      ..clear()
      ..addAll(lista('cumplimientos').map(Cumplimiento.fromJson));
    descansos
      ..clear()
      ..addAll(((j['descansos'] as List?) ?? []).cast<String>());
    contactos
      ..clear()
      ..addAll(lista('contactos').map(ContactoConfianza.fromJson));
    usosSos
      ..clear()
      ..addAll(lista('usosSos'));
    _metasHoy = ((j['metasHoy'] as List?) ?? []).cast<String>();
    _diaMetas = j['diaMetas'] as String?;
    _ultimoDiaCerrado = j['ultimoDiaCerrado'] as String?;
    _semanaEscudos = j['semanaEscudos'] as String?;
    _animoOmitido = j['animoOmitido'] as String?;
    _tareasCreadas = j['tareasCreadas'] as int? ?? 0;
    mensajeCierre = j['mensajeCierre'] == null
        ? null
        : MensajeCierre.fromJson(j['mensajeCierre'] as Map<String, dynamic>);

    if (j['cuenta'] != null) {
      cuenta = Cuenta.fromJson(j['cuenta'] as Map<String, dynamic>);
    }
    avatar = j['avatar'] as String? ?? avatar;
    mascota = j['mascota'] as String? ?? mascota;
    mascotaNombre = j['mascotaNombre'] as String? ?? mascotaNombre;

    final catalogoGuardado = lista('catalogo').map(Microactividad.fromJson).toList();
    if (catalogoGuardado.isNotEmpty) {
      catalogo
        ..clear()
        ..addAll(catalogoGuardado);
    }
    metasExtra
      ..clear()
      ..addAll(((j['metasExtra'] as List?) ?? []).cast<String>());

    final recordatoriosGuardados =
        lista('recordatorios').map(Recordatorio.fromJson).toList();
    if (recordatoriosGuardados.isNotEmpty) {
      recordatorios
        ..clear()
        ..addAll(recordatoriosGuardados);
    }

    final recursosGuardados =
        lista('recursos').map(RecursoAyuda.fromJson).toList();
    if (recursosGuardados.isNotEmpty) {
      recursos
        ..clear()
        ..addAll(recursosGuardados);
    }

    final mensajesGuardados =
        lista('mensajes').map(MensajeValidado.fromJson).toList();
    if (mensajesGuardados.isNotEmpty) {
      mensajes
        ..clear()
        ..addAll(mensajesGuardados);
    }

    final publicacionesGuardadas =
        lista('publicaciones').map(Publicacion.fromJson).toList();
    if (publicacionesGuardadas.isNotEmpty) {
      publicaciones
        ..clear()
        ..addAll(publicacionesGuardadas);
    }

    cambiosPendientes
      ..clear()
      ..addAll(
        lista('cambiosPendientes').map(EntradaSincronizacion.fromJson),
      );
    datosSincronizados = j['datosSincronizados'] as bool? ?? true;
    _contadores.clear();
    if (j['contadores'] is Map) {
      for (final entry in (j['contadores'] as Map).entries) {
        _contadores[entry.key as String] = entry.value as int;
      }
    }
  }
}
