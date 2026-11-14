import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/catalogo.dart';
import '../models/modelos.dart';
import '../services/almacen.dart';

/// Estado de la app y lógica de los cinco casos de uso.
///
/// Corresponde a la clase Usuario del diagrama (xpTotal y las operaciones
/// registrarAnimo, completarActividad, activarSOS) junto con sus
/// composiciones: Racha, RegistroAnimo, ContactoConfianza y Cumplimiento.
///
/// Todo se guarda en el dispositivo; no necesita conexión (RNF-03).
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

  RegistroAnimo? get animoDeHoy => animos[_hoyClave];

  /// El chequeo se pide una vez al día; «ahora no» lo silencia ese día (A1).
  bool get debePreguntarAnimo =>
      animoDeHoy == null && _animoOmitido != _hoyClave;

  List<Microactividad> get metasHoy => [
    for (final id in _metasHoy)
      if (CatalogoMicroactividades.porId(id) != null)
        CatalogoMicroactividades.porId(id)!,
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

  // -------------------------------------------------------------- inicio ---

  Future<void> iniciar() async {
    try {
      final texto = await _almacen.leer();
      if (texto != null) _cargar(jsonDecode(texto) as Map<String, dynamic>);
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
        if (c.dia == _hoyClave && CatalogoMicroactividades.porId(c.actividadId) != null)
          c.actividadId,
    ];
    final pendientes = <String>[];
    // Rota el catálogo con la fecha para que las metas varíen cada día.
    final semilla = hoy.difference(DateTime(hoy.year)).inDays;
    for (final e in esfuerzos) {
      final opciones = CatalogoMicroactividades.buscar(e);
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

  // -------------------------------------------------------- persistencia ---

  Future<void> _guardar() async {
    bool fallo;
    try {
      await _almacen.guardar(jsonEncode(_aJson()));
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
  }
}
