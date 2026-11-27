import 'dart:convert';
import 'dart:math';

import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/catalogo.dart';
import '../logic/clasificador.dart';
import '../logic/perceptron.dart';
import '../models/modelos.dart';
import '../services/almacen.dart';
import '../services/api.dart';
import '../services/credenciales.dart';
import '../services/cifrado.dart';
import '../services/notificaciones.dart';
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
  BrotaState({
    required Almacen almacen,
    DateTime Function()? ahora,
    Notificador? notificador,
    http.Client? clienteHttp,
    String? servidor,
    Credenciales? credenciales,
  }) : _almacen = almacen, // ignore: prefer_initializing_formals
       _credenciales = credenciales, // ignore: prefer_initializing_formals
       _servidorAuto = servidor ?? servidorPredeterminado,
       _ahora = ahora ?? DateTime.now,
       _notificador = notificador, // ignore: prefer_initializing_formals
       _clienteHttp = clienteHttp; // ignore: prefer_initializing_formals

  final Almacen _almacen;
  final DateTime Function() _ahora;
  final Notificador? _notificador;
  final http.Client? _clienteHttp;

  /// Servidor al que la cuenta se conecta sola (vacío = solo local).
  final String _servidorAuto;

  /// Contraseña en el llavero del teléfono para reconectar sin preguntar.
  final Credenciales? _credenciales;
  bool _reconectando = false;
  bool _reconexionFallida = false;

  // ------------------------- Perceptrón de riesgo (elemento innovador) -----
  PerceptronRiesgo perceptron = PerceptronRiesgo();

  /// Predicción guardada por día (aaaa-mm-dd → predicción para ese día).
  final Map<String, PrediccionRiesgo> predicciones = {};

  /// Días en los que se gastó un escudo (entrada x3 del perceptrón).
  final Set<String> diasEscudo = {};
  String? _primerDia;

  /// Días de historial que necesita el modelo antes de predecir.
  static const int diasMinimosRiesgo = 2;

  // -------------------------------------------- Compañero fantasma --------
  final List<InteraccionFantasma> interacciones = [];
  final Set<String> senalesRespondidas = {};
  List<SenalFantasma> _senalesServidor = [];

  // ------------------------------------------- Tienda del jardín ----------
  /// Moneda gastable: 1 semilla por cada Exp. La XP total no baja al comprar.
  int semillas = 0;
  final List<String> decoracionesCompradas = [];

  // ---------------------------------------- Moderación de la comunidad ----
  final List<ReportePublicacion> reportes = [];
  final Set<String> publicacionesOcultas = {};

  // ------------------------------------------------- Servidor opcional ----
  String servidorUrl = '';
  String? _token;
  String rolServidor = 'usuario';
  String? ultimaSincronizacion;
  Timer? _temporizadorSync;

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

  /// Nivel del avatar (cada 100 Exp). Brotito evoluciona con este nivel.
  int get nivel => 1 + xpTotal ~/ xpPorNivel;
  int get xpEnNivel => xpTotal % xpPorNivel;

  /// Nivel de la mascota (cada 150 Exp): sube por separado (RF-08).
  int get nivelMascota => 1 + xpTotal ~/ xpPorNivelMascota;
  int get xpEnNivelMascota => xpTotal % xpPorNivelMascota;

  // ------------------------------------------- estado de la mascota -------

  /// Días seguidos sin actividad hasta ayer, contando desde el primer uso.
  int get diasSinActividad {
    final inicio = _primerDia == null ? hoy : diaDeClave(_primerDia!);
    var n = 0;
    var d = sumarDias(hoy, -1);
    while (n < 60 && !d.isBefore(inicio) && !huboActividad(d)) {
      n++;
      d = sumarDias(d, -1);
    }
    return n;
  }

  /// Feliz si hoy hizo algo o ayer hubo actividad; somnolienta con 1 día sin
  /// actividad; triste con 2 o más. Nunca muere ni pierde nivel.
  EstadoMascota get estadoMascota {
    if (completadasHoy > 0) return EstadoMascota.feliz;
    final n = diasSinActividad;
    if (n >= 2) return EstadoMascota.triste;
    if (n == 1) return EstadoMascota.somnolienta;
    return EstadoMascota.feliz;
  }

  String get fraseMascota {
    final lista = frasesMascota[estadoMascota]!;
    return lista[hoy.day % lista.length];
  }

  // ------------------------------------------------- perceptrón -----------

  /// Predicción para hoy, calculada al cerrar el día de ayer.
  PrediccionRiesgo? get prediccionHoy => predicciones[_hoyClave];

  bool get riesgoAltoHoy => prediccionHoy?.alto ?? false;

  bool _hayHistorial(DateTime d) =>
      _primerDia != null &&
      !sumarDias(diaDeClave(_primerDia!), diasMinimosRiesgo - 1).isAfter(d);

  /// Entradas del perceptrón con los datos hasta el día [d] (inclusive).
  DatosRiesgo datosRiesgo(DateTime d) {
    final dias7 = [for (var i = 0; i < 7; i++) claveDia(sumarDias(d, -i))];
    final horas = [
      for (final c in cumplimientos)
        if (dias7.contains(c.dia)) c.hora,
    ];
    final lunes = lunesDe(d);
    final escudos = diasEscudo.where((k) {
      final f = diaDeClave(k);
      return !f.isBefore(lunes) && !f.isAfter(d);
    }).length;
    RegistroAnimo? ultimo;
    for (final r in animos.values) {
      if (diaDeClave(r.dia).isAfter(d)) continue;
      if (ultimo == null || r.dia.compareTo(ultimo.dia) > 0) ultimo = r;
    }
    final manana = sumarDias(d, 1);
    return DatosRiesgo(
      diasActivos7: dias7.where((k) => huboActividad(diaDeClave(k))).length,
      horasCumplimiento7: horas,
      escudosSemana: escudos,
      mananaEsFinDeSemana: manana.weekday >= DateTime.saturday,
      interaccionesFantasma7: interacciones
          .where((i) => dias7.contains(i.dia))
          .length,
      ultimoAnimo: ultimo?.animo,
      ultimaEnergia: ultimo?.energia,
      activoHoy: huboActividad(d),
    );
  }

  /// Pronóstico en vivo para mañana con lo que va del día (se recalcula al
  /// completar actividades o registrar el ánimo).
  PrediccionRiesgo? get pronosticoManana {
    if (!_hayHistorial(hoy)) return null;
    final x = datosRiesgo(hoy).entradas;
    final z = perceptron.puntaje(x);
    return PrediccionRiesgo(
      dia: claveDia(sumarDias(hoy, 1)),
      alto: z > 0,
      puntaje: z,
      entradas: x,
    );
  }

  /// Aprende del día [d] (ya cerrado) y predice el día siguiente.
  void _aprenderYPredecir(DateTime d) {
    final clave = claveDia(d);
    final previa = predicciones[clave];
    if (previa != null && previa.entradas.length == perceptron.pesos.length) {
      perceptron.aprender(previa.entradas, huboRiesgo: !huboActividad(d));
    }
    if (!_hayHistorial(d)) return;
    final x = datosRiesgo(d).entradas;
    final z = perceptron.puntaje(x);
    final siguiente = claveDia(sumarDias(d, 1));
    predicciones[siguiente] = PrediccionRiesgo(
      dia: siguiente,
      alto: z > 0,
      puntaje: z,
      entradas: x,
    );
    _registrarCambio('riesgo', {
      'dia': siguiente,
      'riesgo': z > 0 ? 'ALTO' : 'BAJO',
      'puntaje': double.parse(z.toStringAsFixed(2)),
    });
    // Se guardan solo los últimos 60 días.
    if (predicciones.length > 60) {
      final claves = predicciones.keys.toList()..sort();
      for (final k in claves.take(predicciones.length - 60)) {
        predicciones.remove(k);
      }
    }
  }

  /// Volver a los pesos iniciales (desde la pantalla del modelo).
  Future<void> reiniciarModelo() async {
    perceptron.reiniciar();
    notifyListeners();
    await _guardar();
  }

  // ------------------------------------------- compañero fantasma ---------

  bool get conectado => servidorUrl.isNotEmpty && _token != null;

  /// Hay servidor oficial configurado en esta versión de la app.
  bool get respaldoDisponible => _servidorAuto.isNotEmpty;

  /// Último recurso: la reconexión automática no pudo (no hay contraseña en
  /// el llavero o el servidor la rechazó). Sin red no se pide nada.
  bool get necesitaReconectar =>
      respaldoDisponible && cuenta != null && !conectado && _reconexionFallida;

  /// Vuelve a iniciar sesión con la contraseña del llavero, sin molestar:
  /// cuando el token del servidor vence (7 días) o la cuenta se creó sin red.
  Future<bool> _reconectarSola() async {
    if (_reconectando || !respaldoDisponible || cuenta == null) return false;
    final password = await _credenciales?.leer();
    if (password == null) {
      _reconexionFallida = true;
      notifyListeners();
      return false;
    }
    _reconectando = true;
    try {
      final error = await conectarServidor(_servidorAuto, password);
      // Sin red no es un fallo: se reintenta al volver a abrir la app.
      _reconexionFallida = error != null && error != errorSinConexion;
      notifyListeners();
      return error == null;
    } finally {
      _reconectando = false;
    }
  }

  Future<String?> reconectar(String password) =>
      conectarServidor(_servidorAuto, password);

  ServicioApi? get _api => conectado
      ? ServicioApi(servidorUrl, cliente: _clienteHttp, token: _token)
      : null;

  /// Señales «alguien completó su misión de hoy» a las que aún no respondí.
  /// Con servidor son reales; sin servidor la app genera de 2 a 4 señales de
  /// ejemplo al día en horarios aleatorios y lo indica en pantalla
  /// (`simulada = true`): no se presentan como personas reales.
  List<SenalFantasma> get senalesFantasma {
    if (conectado) {
      return [
        for (final s in _senalesServidor)
          if (!senalesRespondidas.contains(s.id)) s,
      ];
    }
    final ahora = _ahora();
    final dia = _hoyClave;
    final azar = Random(_semillaDia);
    final total = 2 + azar.nextInt(3);
    final lista = <SenalFantasma>[];
    for (var i = 0; i < total; i++) {
      final minuto = (7 + azar.nextInt(15)) * 60 + azar.nextInt(60);
      final id = 'sim-$dia-$i';
      final hace = ahora.hour * 60 + ahora.minute - minuto;
      if (hace >= 0 && !senalesRespondidas.contains(id)) {
        lista.add(SenalFantasma(id: id, haceMinutos: hace, simulada: true));
      }
    }
    return lista;
  }

  /// Reacciones recibidas que el usuario aún no ha visto.
  List<InteraccionFantasma> get reaccionesNuevas => [
    for (final i in interacciones)
      if (i.recibida && !i.vista) i,
  ];

  Future<void> reaccionarASenal(SenalFantasma s, String reaccion) async {
    if (!reaccionesFantasma.containsKey(reaccion)) return;
    if (senalesRespondidas.contains(s.id)) return;
    senalesRespondidas.add(s.id);
    interacciones.add(
      InteraccionFantasma(
        dia: _hoyClave,
        reaccion: reaccion,
        recibida: false,
        senalId: s.id,
        simulada: s.simulada,
      ),
    );
    notifyListeners();
    await _guardar();
    final api = _api;
    if (api != null && !s.simulada) {
      try {
        await api.reaccionar(s.id, reaccion);
      } on ErrorApi {
        // Si falla la red, la reacción queda registrada aquí.
      }
    }
  }

  Future<void> marcarReaccionesVistas() async {
    for (final i in reaccionesNuevas) {
      i.vista = true;
    }
    notifyListeners();
    await _guardar();
  }

  /// Primera actividad del día: se avisa «alguien completó su misión».
  /// Sin servidor se simula una reacción de vuelta (queda marcada así).
  Future<void> _avisarMisionCumplida() async {
    final api = _api;
    if (api != null) {
      try {
        await api.enviarSenal();
      } on ErrorApi {
        // Sin red: no pasa nada, el progreso ya está guardado.
      }
      return;
    }
    final claves = reaccionesFantasma.keys.toList();
    interacciones.add(
      InteraccionFantasma(
        dia: _hoyClave,
        reaccion: claves[Random(_semillaDia + 7).nextInt(claves.length)],
        recibida: true,
        simulada: true,
      ),
    );
  }

  /// Trae señales y reacciones reales del servidor.
  Future<void> refrescarFantasma() async {
    final api = _api;
    if (api == null) return;
    try {
      _senalesServidor = await api.senales();
      for (final r in await api.recibidas()) {
        interacciones.add(
          InteraccionFantasma(dia: _hoyClave, reaccion: r, recibida: true),
        );
      }
      notifyListeners();
      await _guardar();
    } on ErrorApi {
      // Sin conexión se conserva lo último que se tenía.
    }
  }

  // ----------------------------------------------- tienda del jardín ------

  bool tieneDecoracion(String id) => decoracionesCompradas.contains(id);

  /// Compra con semillas. Devuelve null si se pudo, o el motivo si no.
  Future<String?> comprarDecoracion(String id) async {
    final d = decoracionPorId(id);
    if (d == null) return 'Esa decoración no existe';
    if (tieneDecoracion(id)) return 'Ya está en tu jardín';
    if (semillas < d.precio) {
      return 'Te faltan ${d.precio - semillas} semillas. Se ganan con cada actividad 🌱';
    }
    semillas -= d.precio;
    decoracionesCompradas.add(id);
    notifyListeners();
    await _guardar();
    return null;
  }

  // ------------------------------------------- edad y consentimiento ------

  /// Edad cumplida a hoy, o null si la fecha no es válida o es futura.
  int? edadDe(String fechaNac) {
    final f = DateTime.tryParse(fechaNac.trim());
    if (f == null || f.isAfter(hoy)) return null;
    var edad = hoy.year - f.year;
    if (hoy.month < f.month || (hoy.month == f.month && hoy.day < f.day)) {
      edad--;
    }
    return edad;
  }

  /// Mayores de 35: se les permite usar Brota, solo se les avisa.
  bool get fueraDeRangoObjetivo {
    final e = cuenta == null ? null : edadDe(cuenta!.fechaNac);
    return e != null && e > edadMaximaObjetivo;
  }

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

  bool completadaHoy(Actividad a) =>
      cumplimientos.any((c) => c.dia == _hoyClave && c.actividadId == a.id);

  bool huboActividad(DateTime d) {
    final k = claveDia(d);
    return cumplimientos.any((c) => c.dia == k);
  }

  bool fueDescanso(DateTime d) => descansos.contains(claveDia(d));

  int get completadasHoy =>
      cumplimientos.where((c) => c.dia == _hoyClave).length;

  /// Mensaje amable que acompaña a las metas del día (CU-05, paso 6).
  /// Estilo implícito: describe lo que la app preparó, no da órdenes.
  String get mensajeDelDia {
    final r = animoDeHoy;
    if (riesgoAltoHoy) {
      return 'Hoy preparé misiones más ligeras 🌤️ El jardín no tiene prisa.';
    }
    if (r == null) return 'Un pasito a la vez 🌱';
    if (r.esBajo()) {
      return 'Hoy toca algo suave 🌤️ Elegí metas ligeras para ti.';
    }
    if (r.esAlto()) return 'Hoy hay un reto extra, solo si te nace ✨';
    return 'Un pasito a la vez 🌱';
  }

  /// Semilla estable por día para lo que se elige «al azar».
  int get _semillaDia =>
      _hoyClave.codeUnits.fold(0, (s, c) => s * 31 + c) & 0x7fffffff;

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
      animoMuyBajoSostenido ||
      (diasInactivosSeguidos >= 3 && completadasHoy == 0);

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

  /// Mensaje del día: se prefieren los de estilo implícito según el
  /// diccionario de palabras clave.
  MensajeValidado get mensajeMotivacionalDelDia {
    if (mensajes.isEmpty) {
      return const MensajeValidado(
        id: 'msg-base',
        texto: 'Un pasito a la vez también es avanzar 🌱',
        categoria: 'Aliento',
        validadoPor: 'Equipo Brota',
      );
    }
    final implicitos = [
      for (final m in mensajes)
        if (ClasificadorFrases.clasificar(m.texto).implicita) m,
    ];
    final lista = implicitos.isEmpty ? mensajes : implicitos;
    return lista[hoy.day % lista.length];
  }

  /// Clasifica una frase con el diccionario (CU-19a).
  Clasificacion clasificarFrase(String texto) =>
      ClasificadorFrases.clasificar(texto);

  // ------------------------------------ CU-14 Compartir y aliento ---------

  /// Logro anónimo que se puede copiar o compartir sin exponer datos.
  String get logroCompartible =>
      'Llevo ${racha.dias} día(s) de racha y $xpTotal Exp en Brota. '
      'Un pasito a la vez también es avanzar 🌱';

  /// Publicaciones que este usuario ve (las que reportó quedan ocultas).
  List<Publicacion> get publicacionesVisibles => [
    for (final p in publicaciones)
      if (!publicacionesOcultas.contains(p.id)) p,
  ];

  List<ReportePublicacion> get reportesPendientes => [
    for (final r in reportes)
      if (r.estado == 'pendiente') r,
  ];

  // --------------------------------- CU-15/16 Panel y resumen -------------

  Set<String> get diasConActividad => {for (final c in cumplimientos) c.dia};

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
          datos =
              jsonDecode(CifradoLocal.descifrar(texto, clave: _claveCifrado))
                  as Map<String, dynamic>;
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
    await _reprogramarNotificaciones();
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
    // RNF-07: al volver a abrir (y si hay red) se envían los pendientes.
    if (conectado) {
      _programarSync();
      unawaited(refrescarFantasma());
    } else if (respaldoDisponible && cuenta != null) {
      unawaited(_reconectarSola()); // cuenta creada sin red o sesión vencida
    }
  }

  // --------------------------------------- CU-10 Proteger racha flexible ---

  /// Cierre automático del día. Si la app estuvo cerrada, evalúa cada día
  /// pendiente en orden al siguiente inicio (excepción E1).
  void _cerrarDiasPendientes() {
    final ayer = sumarDias(hoy, -1);
    _primerDia ??= _hoyClave;
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
            diasEscudo.add(claveDia(d));
            _registrarCambio('escudo', {'dia': claveDia(d)});
          } else {
            // A2: sin congelamientos. Solo la racha vuelve a 0;
            // XP, nivel y mascota no se tocan.
            rachaPerdida = racha.dias;
            racha.reiniciar();
            reiniciada = true;
          }
        }
        descansos.add(claveDia(d)); // «descanso», nunca «fallo»
        _registrarCambio('descanso', {'dia': claveDia(d)});
      }
      // Perceptrón: aprende de este día y predice el siguiente.
      _aprenderYPredecir(d);
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
    _registrarCambio('animo', {
      'dia': _hoyClave,
      'animo': animo,
      'energia': energia,
    });
    notifyListeners();
    await _guardar();
  }

  Future<void> omitirAnimo() async {
    _animoOmitido = _hoyClave;
    notifyListeners();
    await _guardar();
  }

  /// CU-05a Ajustar metas del día:
  /// riesgo ALTO según el perceptrón → 2 metas de esfuerzo ligero (CU-20);
  /// ánimo o energía bajos → 2 metas de esfuerzo ligero;
  /// ánimo y energía altos → se agrega un reto de esfuerzo alto;
  /// en otro caso → 2 ligeras y 1 media.
  List<String> _generarMetas(RegistroAnimo? r) {
    final List<int> esfuerzos;
    if (riesgoAltoHoy) {
      esfuerzos = [1, 1];
    } else if (r == null) {
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
    _registrarCambio('tarea', {
      'id': t.id,
      'titulo': t.titulo,
      'categoria': t.categoria,
      'esfuerzo': t.esfuerzo,
    });
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
    final mascotaAntes = nivelMascota;
    final xp = a.calcularXP();
    final primeraDelDia = completadasHoy == 0;
    if (primeraDelDia) racha.dias++;
    final hora = _ahora().hour;
    cumplimientos.add(
      Cumplimiento(
        dia: _hoyClave,
        actividadId: a.id,
        titulo: a.titulo,
        xpOtorgada: xp,
        hora: hora,
      ),
    );
    xpTotal += xp;
    semillas += xp;
    _registrarCambio('cumplimiento', {
      'dia': _hoyClave,
      'actividad_id': a.id,
      'titulo': a.titulo,
      'xp': xp,
      'hora': hora,
    });
    notifyListeners();
    if (primeraDelDia) {
      // Compañero fantasma: «alguien completó su misión de hoy».
      _avisarMisionCumplida().then((_) {
        notifyListeners();
        return _guardar();
      });
    } else {
      _guardar();
    }
    return ResultadoCompletar(
      xp: xp,
      subioNivel: nivel > nivelAntes,
      nivel: nivel,
      subioMascota: nivelMascota > mascotaAntes,
      nivelMascota: nivelMascota,
    );
  }

  /// Deshace un cumplimiento de hoy marcado por error.
  void desmarcarActividad(Actividad a) {
    final i = cumplimientos.indexWhere(
      (c) => c.dia == _hoyClave && c.actividadId == a.id,
    );
    if (i < 0) return;
    final c = cumplimientos[i];
    xpTotal -= c.xpOtorgada;
    if (xpTotal < 0) xpTotal = 0;
    semillas = max(0, semillas - c.xpOtorgada);
    cumplimientos.removeAt(i);
    // Si aún no se subió, se quita de la cola para no enviarlo.
    cambiosPendientes.removeWhere(
      (e) =>
          e.tipo == 'cumplimiento' &&
          e.datos['dia'] == c.dia &&
          e.datos['actividad_id'] == c.actividadId,
    );
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

  /// Valida el registro, incluida la edad (13 a 35 años) y los permisos.
  String? validarRegistro({
    required String correo,
    required String password,
    required String nombre,
    required String fechaNac,
    bool aceptaPrivacidad = false,
    bool consentimientoTutor = false,
  }) {
    final c = correo.trim().toLowerCase();
    if (!c.contains('@') || !c.contains('.')) {
      return 'Escribe un correo válido';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (nombre.trim().isEmpty) return 'Escribe tu nombre';
    final edad = edadDe(fechaNac);
    if (edad == null) return 'Escribe tu fecha de nacimiento (AAAA-MM-DD)';
    if (edad < edadMinima) {
      return 'Brota es para personas de $edadMinima años o más. '
          'Gracias por tu interés 💚';
    }
    if (edad < edadMayoria && !consentimientoTutor) {
      return 'Por tener menos de $edadMayoria años, tu madre, padre o tutor '
          'debe dar su consentimiento';
    }
    if (!aceptaPrivacidad) return 'Lee y acepta el aviso de privacidad';
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
    required String fechaNac,
    bool aceptaPrivacidad = false,
    bool consentimientoTutor = false,
    Rol rol = Rol.usuario,
  }) async {
    final error = validarRegistro(
      correo: correo,
      password: password,
      nombre: nombre,
      fechaNac: fechaNac,
      aceptaPrivacidad: aceptaPrivacidad,
      consentimientoTutor: consentimientoTutor,
    );
    if (error != null) return false;
    final sal = _nuevaSal();
    cuenta = Cuenta(
      correo: correo.trim().toLowerCase(),
      hash: _hash('$sal$password'),
      sal: sal,
      nombre: nombre.trim(),
      apellidos: apellidos.trim(),
      fechaNac: fechaNac.trim(),
      rol: rol,
      aceptoPrivacidad: aceptaPrivacidad,
      consentimientoTutor: consentimientoTutor,
    );
    notifyListeners();
    await _guardar();
    // El respaldo se conecta solo (crea la cuenta también en el servidor).
    if (respaldoDisponible) {
      await _credenciales?.guardar(password);
      unawaited(conectarServidor(_servidorAuto, password));
    }
    return true;
  }

  String _nuevaSal() => _hash(
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
  );

  /// CU-02: compara el hash; no guarda sesiones en texto plano. Si en este
  /// teléfono no hay cuenta (teléfono nuevo o reinstalación), la busca en el
  /// servidor. En ambos casos el respaldo se conecta solo.
  Future<bool> iniciarSesion(String correo, String password) async {
    final correoN = correo.trim().toLowerCase();
    final c = cuenta;
    if (c != null && c.correo == correoN) {
      if (!c.verificar(password, _hash)) return false;
      notifyListeners();
      await _guardar();
      if (respaldoDisponible) {
        await _credenciales?.guardar(password);
        if (!conectado) unawaited(conectarServidor(_servidorAuto, password));
      }
      return true;
    }
    if (c != null || !respaldoDisponible) return false;
    final api = ServicioApi(_servidorAuto, cliente: _clienteHttp);
    try {
      final sesion = await api.login(correoN, password);
      final yo = await api.yo();
      final sal = _nuevaSal();
      cuenta = Cuenta(
        correo: correoN,
        hash: _hash('$sal$password'),
        sal: sal,
        nombre: yo['nombre'] as String? ?? '',
        apellidos: '',
        fechaNac: yo['fecha_nac'] as String? ?? '',
        rol: sesion.rol == 'administrador' ? Rol.administrador : Rol.usuario,
        aceptoPrivacidad: true,
      );
      servidorUrl = _servidorAuto;
      _token = sesion.token;
      rolServidor = sesion.rol;
      await _credenciales?.guardar(password);
      notifyListeners();
      await _guardar();
      unawaited(_alConectar());
      return true;
    } on ErrorApi {
      return false;
    }
  }

  /// La app funciona como invitada: el núcleo no exige cuenta (RF-01/RNF-03).
  Future<void> continuarComoInvitado() async {
    notifyListeners();
    await _guardar();
  }

  Future<void> cerrarSesion() async {
    cuenta = null;
    _token = null;
    _reconexionFallida = false;
    await _credenciales?.borrar();
    notifyListeners();
    await _guardar();
  }

  // --------------------------- CU-03 / CU-04 Avatar y mascota -------------

  Future<void> personalizarAvatar(String emoji) async {
    avatar = emoji;
    _registrarPerfil();
    notifyListeners();
    await _guardar();
  }

  Future<void> elegirMascota(String emoji, String nombre) async {
    mascota = emoji;
    mascotaNombre = nombre.trim().isEmpty ? 'Brotito' : nombre.trim();
    _registrarPerfil();
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
    notifyListeners();
    await _guardar();
  }

  Future<void> eliminarMicroactividad(String id) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    catalogo.removeWhere((m) => m.id == id);
    _metasHoy.remove(id);
    metasExtra.remove(id);
    notifyListeners();
    await _guardar();
  }

  /// CU-06: llevar una actividad del catálogo a las metas de hoy.
  Future<void> agregarMetaDelCatalogo(String id) async {
    if (microPorId(id) == null ||
        metasExtra.contains(id) ||
        _metasHoy.contains(id)) {
      return;
    }
    metasExtra.add(id);
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
    notifyListeners();
    await _guardar();
    await _reprogramarNotificaciones();
  }

  Future<void> eliminarRecordatorio(String id) async {
    recordatorios.removeWhere((r) => r.id == id);
    notifyListeners();
    await _guardar();
    await _reprogramarNotificaciones();
  }

  /// Actor «Servicio de notificaciones»: programa los avisos en Android.
  Future<void> _reprogramarNotificaciones() async {
    await _notificador?.programar(
      recordatorios,
      suave: modoRecordatorioSuave,
      nombreMascota: mascotaNombre,
    );
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
    notifyListeners();
    await _guardar();
    return r;
  }

  Future<void> eliminarRecurso(String id) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    recursos.removeWhere((r) => r.id == id);
    notifyListeners();
    await _guardar();
  }

  // ----------------------- CU-12 / CU-19 Mensajes validados ---------------

  /// CU-19 con CU-19a: antes de guardar, el mensaje pasa por el diccionario
  /// de palabras clave. Si no resulta «motivadora», se rechaza con el motivo.
  Future<MensajeValidado> agregarMensaje({
    required String texto,
    String categoria = 'Aliento',
    String validadoPor = 'Equipo Brota',
  }) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    final c = ClasificadorFrases.clasificar(texto);
    if (!c.esMotivadora) {
      throw FormatException(
        'El diccionario la clasifica como «${c.categoria.texto}» '
        '(puntaje ${c.puntaje}). Reescríbela describiendo el paso o el '
        'descanso, sin «debes» ni comparaciones.',
      );
    }
    final m = MensajeValidado(
      id: _nuevoId('msg'),
      texto: texto.trim(),
      categoria: categoria,
      validadoPor: validadoPor,
    );
    mensajes.add(m);
    notifyListeners();
    await _guardar();
    return m;
  }

  Future<void> eliminarMensaje(String id) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    mensajes.removeWhere((m) => m.id == id);
    notifyListeners();
    await _guardar();
  }

  // --------------------------- CU-14 Muro de aliento ----------------------

  /// CU-14: solo se publican frases predefinidas (no hay texto libre).
  Future<Publicacion> publicarFrase(String fraseId) async {
    final frase = frasesMuro.where((f) => f.id == fraseId).firstOrNull;
    if (frase == null) {
      throw const FormatException('Elige una de las frases del muro');
    }
    final api = _api;
    if (api != null) {
      try {
        await api.publicarFrase(fraseId);
        await cargarComunidad();
        return publicaciones.first;
      } on ErrorApi {
        // Sin red: se publica en el muro local.
      }
    }
    final p = Publicacion(
      id: _nuevoId('pub'),
      contenido: frase.texto,
      fecha: claveDia(hoy),
    );
    publicaciones.insert(0, p);
    notifyListeners();
    await _guardar();
    return p;
  }

  /// CU-14: compartir el logro anónimo (racha y Exp) en el muro.
  Future<Publicacion> publicarLogro() async {
    final api = _api;
    if (api != null) {
      try {
        await api.publicarLogro(racha.dias, xpTotal);
        await cargarComunidad();
        return publicaciones.first;
      } on ErrorApi {
        // Sin red: se publica en el muro local.
      }
    }
    final p = Publicacion(
      id: _nuevoId('pub'),
      contenido: logroCompartible,
      fecha: claveDia(hoy),
      esLogro: true,
    );
    publicaciones.insert(0, p);
    notifyListeners();
    await _guardar();
    return p;
  }

  /// Con servidor, el muro es el compartido por todos los usuarios.
  Future<void> cargarComunidad() async {
    final api = _api;
    if (api == null) return;
    try {
      final lista = await api.publicaciones();
      publicaciones
        ..clear()
        ..addAll(lista);
      notifyListeners();
      await _guardar();
    } on ErrorApi {
      // Se queda el último muro conocido.
    }
  }

  /// CU-23 Reportar publicación: se oculta de inmediato para quien reporta
  /// y queda en la lista de revisión del Administrador.
  Future<void> reportarPublicacion(Publicacion p, String motivo) async {
    publicacionesOcultas.add(p.id);
    final api = _api;
    var enviado = false;
    if (api != null && p.id.startsWith('srv-')) {
      try {
        await api.reportar(p.id, motivo);
        enviado = true;
      } on ErrorApi {
        enviado = false;
      }
    }
    if (!enviado) {
      reportes.add(
        ReportePublicacion(
          id: _nuevoId('rep'),
          publicacionId: p.id,
          texto: p.contenido,
          motivo: motivo,
          fecha: _hoyClave,
        ),
      );
    }
    notifyListeners();
    await _guardar();
  }

  /// CU-24 Moderar reportes (Administrador). Con servidor trae también los
  /// reportes de todos los usuarios.
  Future<void> cargarReportesServidor() async {
    final api = _api;
    if (api == null || rolServidor != 'administrador') return;
    try {
      final lista = await api.reportesPendientes();
      reportes.removeWhere((r) => r.id.startsWith('srv-'));
      reportes.addAll(lista);
      notifyListeners();
    } on ErrorApi {
      // Sin red: solo los reportes locales.
    }
  }

  Future<void> resolverReporte(
    ReportePublicacion r, {
    required bool ocultar,
  }) async {
    if (!esAdmin) throw StateError('Solo el administrador puede hacerlo');
    final api = _api;
    if (api != null && r.id.startsWith('srv-')) {
      await api.resolverReporte(r.id, ocultar);
    }
    r.estado = ocultar ? 'oculta' : 'mantenida';
    if (ocultar) {
      publicaciones.removeWhere((p) => p.id == r.publicacionId);
    } else {
      publicacionesOcultas.remove(r.publicacionId);
    }
    notifyListeners();
    await _guardar();
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
      for (final valor in xpDeLosUltimos(30)) 'XP del dia: $valor',
      '',
      'Cumplimientos registrados',
      for (final c in [
        ...cumplimientos,
      ]..sort((a, b) => a.dia.compareTo(b.dia)))
        '${c.dia}  ${c.titulo}  +${c.xpOtorgada} Exp',
      '',
      'Registros de animo',
      for (final r in [
        ...animos.values,
      ]..sort((a, b) => a.dia.compareTo(b.dia)))
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
      subtitulo:
          'Generado el ${claveDia(hoy)} - datos guardados solo en este dispositivo',
    );
  }

  // --------------------------- RNF-07 Sincronización ----------------------

  /// UUID v4 generado en el dispositivo: el servidor lo usa para no
  /// duplicar registros si el mismo cambio se envía dos veces.
  static String nuevoUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  void _registrarCambio(String tipo, Map<String, dynamic> datos) {
    cambiosPendientes.add(
      EntradaSincronizacion(
        id: nuevoUuid(),
        tipo: tipo,
        fecha: _ahora().toIso8601String(),
        datos: datos,
      ),
    );
    datosSincronizados = false;
    if (conectado) _programarSync();
  }

  void _registrarPerfil() => _registrarCambio('perfil', {
    'avatar': avatar,
    'mascota': mascota,
    'mascota_nombre': mascotaNombre,
    'xp_total': xpTotal,
  });

  /// Agrupa los cambios de unos segundos en un solo envío.
  void _programarSync() {
    _temporizadorSync?.cancel();
    _temporizadorSync = Timer(const Duration(seconds: 3), () {
      sincronizar();
    });
  }

  /// RNF-07: envía la cola al servidor. Cada evento lleva su UUID, así que
  /// reenviar no duplica nada; solo se borra de la cola lo que el servidor
  /// confirmó. Sin servidor o sin red, la cola se conserva cifrada aquí.
  Future<String> sincronizar() async {
    final api = _api;
    if (api == null) {
      return cambiosPendientes.isEmpty
          ? 'Todo está guardado en este dispositivo'
          : 'Sin servidor conectado: ${cambiosPendientes.length} cambio(s) '
                'siguen guardados y cifrados aquí';
    }
    final lote = [
      for (final c in cambiosPendientes)
        if (tiposSincronizables.contains(c.tipo)) c,
    ];
    try {
      final r = lote.isEmpty
          ? const ResultadoSync(aceptados: [], duplicados: [], rechazados: [])
          : await api.sincronizar(lote);
      final hechos = {...r.aceptados, ...r.duplicados, ...r.rechazados};
      cambiosPendientes.removeWhere(
        (c) => hechos.contains(c.id) || !tiposSincronizables.contains(c.tipo),
      );
      datosSincronizados = cambiosPendientes.isEmpty;
      ultimaSincronizacion = _ahora().toIso8601String();
      notifyListeners();
      await _guardar();
      return 'Sincronizado: ${r.aceptados.length} nuevo(s), '
          '${r.duplicados.length} ya estaban en el servidor';
    } on ErrorApi catch (e) {
      if (e.codigo == 401) {
        // Sesión del servidor vencida (7 días): se reconecta sola con la
        // contraseña del llavero y reenvía los cambios.
        _token = null;
        notifyListeners();
        await _guardar();
        if (await _reconectarSola()) return 'Sincronizado';
      }
      return '${e.mensaje}. Tus cambios siguen guardados y se enviarán después';
    }
  }

  /// Conecta la cuenta local con el servidor: inicia sesión y, si la cuenta
  /// no existe allá, la crea con los mismos datos. Devuelve null si se pudo.
  Future<String?> conectarServidor(String url, String password) async {
    final c = cuenta;
    if (c == null) return 'Primero crea tu cuenta en «Mi perfil»';
    if (url.trim().isEmpty) return 'Escribe la dirección del servidor';
    if (!c.verificar(password, _hash)) return 'La contraseña no coincide';
    final api = ServicioApi(url, cliente: _clienteHttp);
    try {
      await api.salud();
      SesionApi sesion;
      try {
        sesion = await api.login(c.correo, password);
      } on ErrorApi catch (e) {
        if (e.codigo != 401) rethrow;
        sesion = await api.registro(
          correo: c.correo,
          password: password,
          nombre: c.nombre,
          fechaNac: c.fechaNac,
          aceptaPrivacidad: c.aceptoPrivacidad,
          consentimientoTutor: c.consentimientoTutor,
        );
      }
      servidorUrl = url.trim();
      _token = sesion.token;
      rolServidor = sesion.rol;
      _reconexionFallida = false;
      await _credenciales?.guardar(password);
      notifyListeners();
      await _guardar();
      await _alConectar();
      return null;
    } on ErrorApi catch (e) {
      return e.mensaje;
    }
  }

  Future<void> _alConectar() async {
    await sincronizar();
    await refrescarFantasma();
    await cargarComunidad();
  }

  Future<void> desconectarServidor() async {
    _temporizadorSync?.cancel();
    servidorUrl = '';
    _token = null;
    rolServidor = 'usuario';
    _senalesServidor = [];
    notifyListeners();
    await _guardar();
  }

  @override
  void dispose() {
    _temporizadorSync?.cancel();
    super.dispose();
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
    'version': 3,
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
    'perceptron': perceptron.toJson(),
    'predicciones': [for (final p in predicciones.values) p.toJson()],
    'diasEscudo': diasEscudo.toList(),
    'primerDia': _primerDia,
    'interacciones': [for (final i in interacciones) i.toJson()],
    'senalesRespondidas': senalesRespondidas.toList(),
    'semillas': semillas,
    'decoraciones': decoracionesCompradas,
    'reportes': [for (final r in reportes) r.toJson()],
    'publicacionesOcultas': publicacionesOcultas.toList(),
    'servidorUrl': servidorUrl,
    'token': _token,
    'rolServidor': rolServidor,
    'ultimaSincronizacion': ultimaSincronizacion,
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

    final catalogoGuardado = lista(
      'catalogo',
    ).map(Microactividad.fromJson).toList();
    if (catalogoGuardado.isNotEmpty) {
      catalogo
        ..clear()
        ..addAll(catalogoGuardado);
    }
    metasExtra
      ..clear()
      ..addAll(((j['metasExtra'] as List?) ?? []).cast<String>());

    final recordatoriosGuardados = lista(
      'recordatorios',
    ).map(Recordatorio.fromJson).toList();
    if (recordatoriosGuardados.isNotEmpty) {
      recordatorios
        ..clear()
        ..addAll(recordatoriosGuardados);
    }

    final recursosGuardados = lista(
      'recursos',
    ).map(RecursoAyuda.fromJson).toList();
    if (recursosGuardados.isNotEmpty) {
      recursos
        ..clear()
        ..addAll(recursosGuardados);
    }

    final mensajesGuardados = lista(
      'mensajes',
    ).map(MensajeValidado.fromJson).toList();
    if (mensajesGuardados.isNotEmpty) {
      mensajes
        ..clear()
        ..addAll(mensajesGuardados);
    }

    final publicacionesGuardadas = lista(
      'publicaciones',
    ).map(Publicacion.fromJson).toList();
    if (publicacionesGuardadas.isNotEmpty) {
      publicaciones
        ..clear()
        ..addAll(publicacionesGuardadas);
    }

    // Las entradas de la versión 2 no tenían tipo: no se pueden enviar.
    cambiosPendientes
      ..clear()
      ..addAll(
        lista(
          'cambiosPendientes',
        ).where((c) => c['tipo'] is String).map(EntradaSincronizacion.fromJson),
      );
    datosSincronizados = j['datosSincronizados'] as bool? ?? true;
    _contadores.clear();
    if (j['contadores'] is Map) {
      for (final entry in (j['contadores'] as Map).entries) {
        _contadores[entry.key as String] = entry.value as int;
      }
    }
    List<String> textos(String k) => ((j[k] as List?) ?? []).cast<String>();

    if (racha.congelamientos > congelamientosPorSemana) {
      racha.congelamientos = congelamientosPorSemana; // antes eran 2
    }
    if (j['perceptron'] is Map) {
      perceptron = PerceptronRiesgo.fromJson(
        (j['perceptron'] as Map).cast<String, dynamic>(),
      );
    }
    predicciones.clear();
    for (final p in lista('predicciones').map(PrediccionRiesgo.fromJson)) {
      predicciones[p.dia] = p;
    }
    diasEscudo
      ..clear()
      ..addAll(textos('diasEscudo'));
    _primerDia = j['primerDia'] as String?;
    if (_primerDia == null) {
      // Datos de la versión 2: el primer día es el registro más antiguo.
      final dias = [
        for (final c in cumplimientos) c.dia,
        ...animos.keys,
        ...descansos,
      ]..sort();
      _primerDia = dias.isEmpty ? null : dias.first;
    }
    interacciones
      ..clear()
      ..addAll(lista('interacciones').map(InteraccionFantasma.fromJson));
    senalesRespondidas
      ..clear()
      ..addAll(textos('senalesRespondidas'));
    semillas = j['semillas'] as int? ?? xpTotal;
    decoracionesCompradas
      ..clear()
      ..addAll(textos('decoraciones'));
    reportes
      ..clear()
      ..addAll(lista('reportes').map(ReportePublicacion.fromJson));
    publicacionesOcultas
      ..clear()
      ..addAll(textos('publicacionesOcultas'));
    servidorUrl = j['servidorUrl'] as String? ?? '';
    _token = j['token'] as String?;
    rolServidor = j['rolServidor'] as String? ?? 'usuario';
    ultimaSincronizacion = j['ultimaSincronizacion'] as String?;
  }
}
