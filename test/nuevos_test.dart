import 'dart:convert';
import 'dart:io';

import 'package:brota_app/data/catalogo.dart';
import 'package:brota_app/logic/clasificador.dart';
import 'package:brota_app/logic/perceptron.dart';
import 'package:brota_app/models/modelos.dart';
import 'package:brota_app/services/almacen.dart';
import 'package:brota_app/services/notificaciones.dart';
import 'package:brota_app/state/brota_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Reloj {
  _Reloj(this.ahora);
  DateTime ahora;
  DateTime call() => ahora;
  void avanzar(int dias) => ahora = sumarDias(ahora, dias).add(const Duration(hours: 9));
}

Future<(BrotaState, _Reloj, AlmacenMemoria)> _nuevo({
  DateTime? inicio,
  Notificador? notificador,
  http.Client? cliente,
}) async {
  final reloj = _Reloj(inicio ?? DateTime(2026, 11, 9, 9)); // lunes
  final almacen = AlmacenMemoria();
  final e = BrotaState(
    almacen: almacen,
    ahora: reloj.call,
    notificador: notificador,
    clienteHttp: cliente,
  );
  await e.iniciar();
  return (e, reloj, almacen);
}

Future<void> _registrarAdmin(BrotaState e) => e.registrarse(
  correo: 'admin@brota.mx',
  password: 'secreto123',
  nombre: 'Equipo',
  fechaNac: '2000-01-01',
  aceptaPrivacidad: true,
  rol: Rol.administrador,
);

class _NotificadorFalso implements Notificador {
  int llamadas = 0;
  bool? ultimoSuave;
  int ultimos = 0;

  @override
  Future<void> programar(
    List<Recordatorio> lista, {
    required bool suave,
    required String nombreMascota,
  }) async {
    llamadas++;
    ultimoSuave = suave;
    ultimos = lista.length;
  }
}

void main() {
  group('Pendiente 1 · Perceptrón de riesgo', () {
    test('suma ponderada con los pesos iniciales y umbral en 0', () {
      final p = PerceptronRiesgo();
      // Usuario constante, ánimo y energía altos, activo hoy.
      final bajo = [1.0, 0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0];
      expect(p.puntaje(bajo), closeTo(1.4 - 1.2 + 0.2 - 0.8 - 0.6 - 1.0, 1e-9));
      expect(p.predecir(bajo), isFalse);
      // Sin actividad, escudo gastado y ánimo bajo.
      final alto = [0.0, 0.5, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0];
      expect(p.predecir(alto), isTrue);
    });

    test('regla de aprendizaje: corrige solo cuando se equivoca', () {
      final p = PerceptronRiesgo();
      final x = [1.0, 0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0]; // predice BAJO
      expect(p.aprender(x, huboRiesgo: false), isFalse); // acertó
      expect(p.pesos, PerceptronRiesgo.pesosIniciales);
      expect(p.aprender(x, huboRiesgo: true), isTrue); // se equivocó
      expect(p.pesos[0], closeTo(-1.2 + 0.1 * 1.0, 1e-9));
      expect(p.pesos[1], closeTo(0.4 + 0.1 * 0.5, 1e-9));
      expect(p.sesgo, closeTo(1.5, 1e-9));
      expect(p.ejemplos, 2);
      final copia = PerceptronRiesgo.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(copia.pesos, p.pesos);
      expect(copia.sesgo, p.sesgo);
    });

    test('las entradas se normalizan entre 0 y 1', () {
      const d = DatosRiesgo(
        diasActivos7: 7,
        horasCumplimiento7: [23, 23],
        escudosSemana: 3,
        mananaEsFinDeSemana: true,
        interaccionesFantasma7: 20,
        ultimoAnimo: 5,
        ultimaEnergia: 1,
        activoHoy: true,
      );
      expect(d.entradas, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0]);
      const vacio = DatosRiesgo(
        diasActivos7: 0,
        horasCumplimiento7: [],
        escudosSemana: 0,
        mananaEsFinDeSemana: false,
        interaccionesFantasma7: 0,
        ultimoAnimo: null,
        ultimaEnergia: null,
        activoHoy: false,
      );
      expect(vacio.entradas, [0.0, 0.5, 0.0, 0.0, 0.0, 0.5, 0.5, 0.0]);
    });

    test('días sin actividad → riesgo ALTO y misiones ligeras al día siguiente', () async {
      final (e, reloj, _) = await _nuevo();
      expect(e.prediccionHoy, isNull); // aún aprendiendo
      e.completarActividad(e.metasHoy.first);
      reloj.avanzar(3); // martes y miércoles sin actividad; es jueves
      await e.abrirDia();
      expect(e.prediccionHoy, isNotNull);
      expect(e.riesgoAltoHoy, isTrue);
      expect(e.metasHoy.length, 2);
      expect(e.metasHoy.every((m) => m.esfuerzo == 1), isTrue);
      expect(e.mensajeDelDia, contains('más ligeras'));
      expect(e.perceptron.ejemplos, greaterThanOrEqualTo(1));
      expect(e.cambiosPendientes.any((c) => c.tipo == 'riesgo'), isTrue);
    });

    test('constancia y buen ánimo → riesgo BAJO y metas normales', () async {
      final (e, reloj, _) = await _nuevo();
      for (var i = 0; i < 3; i++) {
        await e.registrarAnimo(4, 3);
        e.completarActividad(e.metasHoy.first);
        e.completarActividad(e.metasHoy.last);
        reloj.avanzar(1);
        await e.abrirDia();
      }
      expect(e.prediccionHoy, isNotNull);
      expect(e.riesgoAltoHoy, isFalse);
      expect(e.metasHoy.length, 3);
      expect(e.pronosticoManana, isNotNull);
    });

    test('el modelo aprendido sobrevive al reinicio y se puede reiniciar', () async {
      final (e, reloj, almacen) = await _nuevo();
      e.completarActividad(e.metasHoy.first);
      reloj.avanzar(4);
      await e.abrirDia();
      final ejemplos = e.perceptron.ejemplos;
      final otra = BrotaState(almacen: almacen, ahora: reloj.call);
      await otra.iniciar();
      expect(otra.perceptron.ejemplos, ejemplos);
      expect(otra.prediccionHoy?.alto, e.prediccionHoy?.alto);
      await otra.reiniciarModelo();
      expect(otra.perceptron.pesos, PerceptronRiesgo.pesosIniciales);
    });
  });

  group('Diccionario de palabras clave (CU-19a)', () {
    test('todos los ejemplos del diccionario se clasifican como se espera', () {
      final d = jsonDecode(
        File('docs/diccionario_motivacional.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      const nombres = {
        'motivadora': CategoriaFrase.motivadora,
        'neutra': CategoriaFrase.neutra,
        'no_apta': CategoriaFrase.noApta,
        'riesgo': CategoriaFrase.riesgo,
      };
      for (final ej in (d['ejemplos'] as List).cast<Map<String, dynamic>>()) {
        final c = ClasificadorFrases.clasificar(ej['texto'] as String);
        expect(c.categoria, nombres[ej['esperado']], reason: ej['texto'] as String);
        expect(c.implicita, ej['estilo'] == 'implicito', reason: ej['texto'] as String);
      }
    });

    test('normaliza acentos y no cuenta dos veces la misma palabra', () {
      expect(ClasificadorFrases.normalizar('¡Ánimo, Tú PUEDES!'), ['animo', 'tu', 'puedes']);
      final c = ClasificadorFrases.clasificar('No tienes que correr');
      expect(c.coincidencias.map((m) => m.termino), ['no tienes que']);
      expect(c.esMotivadora, isTrue);
    });

    test('los mensajes de la app son motivadores e implícitos', () {
      final textos = [
        for (final m in mensajesPorDefecto) m.texto,
        for (final f in frasesMuro) f.texto,
        ...frasesMotivacionales,
      ];
      for (final t in textos) {
        final c = ClasificadorFrases.clasificar(t);
        expect(c.esMotivadora, isTrue, reason: t);
        expect(c.implicita, isTrue, reason: t);
      }
    });
  });

  group('Pendiente 2 · Compañero fantasma', () {
    test('sin servidor muestra señales de ejemplo y permite una reacción por señal', () async {
      final (e, reloj, _) = await _nuevo(inicio: DateTime(2026, 11, 9, 23, 30));
      final senales = e.senalesFantasma;
      expect(senales, isNotEmpty);
      expect(senales.every((s) => s.simulada), isTrue);
      await e.reaccionarASenal(senales.first, 'tu_puedes');
      await e.reaccionarASenal(senales.first, 'bien_hecho'); // se ignora
      expect(e.interacciones.where((i) => !i.recibida).length, 1);
      expect(e.senalesFantasma.length, senales.length - 1);
      expect(e.datosRiesgo(e.hoy).interaccionesFantasma7, 1);
      reloj.ahora = DateTime(2026, 11, 10, 0, 5);
      expect(e.senalesFantasma, isEmpty); // de madrugada aún no hay
    });

    test('al completar la primera misión del día llega una reacción', () async {
      final (e, _, _) = await _nuevo();
      e.completarActividad(e.metasHoy.first);
      expect(e.reaccionesNuevas.length, 1);
      expect(reaccionesFantasma.keys, contains(e.reaccionesNuevas.first.reaccion));
      e.completarActividad(e.metasHoy.last);
      expect(e.reaccionesNuevas.length, 1); // solo la primera del día
      await e.marcarReaccionesVistas();
      expect(e.reaccionesNuevas, isEmpty);
    });
  });

  group('Pendiente 3 · Moderación de la comunidad', () {
    test('reportar oculta la publicación y el administrador decide', () async {
      final (e, _, _) = await _nuevo();
      final p = e.publicacionesVisibles.first;
      await e.reportarPublicacion(p, motivosReporte.first);
      expect(e.publicacionesVisibles.any((x) => x.id == p.id), isFalse);
      expect(e.reportesPendientes.single.publicacionId, p.id);
      expect(
        () => e.resolverReporte(e.reportesPendientes.single, ocultar: false),
        throwsStateError,
      );
      await _registrarAdmin(e);
      await e.resolverReporte(e.reportesPendientes.single, ocultar: false);
      expect(e.publicacionesVisibles.any((x) => x.id == p.id), isTrue);

      final q = e.publicacionesVisibles.first;
      await e.reportarPublicacion(q, motivosReporte.last);
      await e.resolverReporte(e.reportesPendientes.single, ocultar: true);
      expect(e.publicaciones.any((x) => x.id == q.id), isFalse);
      expect(e.reportesPendientes, isEmpty);
    });
  });

  group('Pendiente 4 · Escudos', () {
    test('se gana 1 escudo por semana', () async {
      final (e, _, _) = await _nuevo();
      expect(e.racha.congelamientos, 1);
      expect(congelamientosPorSemana, 1);
    });
  });

  group('Pendiente 5 · Tienda del jardín', () {
    test('las semillas se ganan jugando y comprar no baja el nivel', () async {
      final (e, _, _) = await _nuevo();
      for (var i = 0; i < 2; i++) {
        e.completarActividad(await e.crearTarea('Tarea $i', 'Otro', 3)); // 30 c/u
      }
      expect(e.semillas, 60);
      expect(await e.comprarDecoracion('d-arcoiris'), contains('Te faltan 60'));
      expect(await e.comprarDecoracion('d-banca'), isNull);
      expect(e.semillas, 0);
      expect(e.xpTotal, 60);
      expect(e.tieneDecoracion('d-banca'), isTrue);
      expect(await e.comprarDecoracion('d-banca'), 'Ya está en tu jardín');
      e.desmarcarActividad(e.tareas.first);
      expect(e.semillas, 0); // nunca negativo
    });
  });

  group('Pendiente 6 · Estados de la mascota', () {
    test('feliz, somnolienta y triste; nunca pierde nivel', () async {
      final (e, reloj, _) = await _nuevo();
      expect(e.estadoMascota, EstadoMascota.feliz);
      e.completarActividad(e.metasHoy.first);
      final nivel = e.nivelMascota;
      reloj.avanzar(2); // martes sin actividad; es miércoles
      await e.abrirDia();
      expect(e.estadoMascota, EstadoMascota.somnolienta);
      reloj.avanzar(1);
      await e.abrirDia();
      expect(e.estadoMascota, EstadoMascota.triste);
      expect(e.fraseMascota, isNotEmpty);
      expect(e.nivelMascota, nivel);
      e.completarActividad(e.metasHoy.first);
      expect(e.estadoMascota, EstadoMascota.feliz);
    });
  });

  group('Pendiente 7 · Edad, consentimiento y privacidad', () {
    String? validar(BrotaState e, String fecha, {bool tutor = false, bool privacidad = true}) =>
        e.validarRegistro(
          correo: 'a@b.com',
          password: '123456',
          nombre: 'Ana',
          fechaNac: fecha,
          aceptaPrivacidad: privacidad,
          consentimientoTutor: tutor,
        );

    test('reglas de 13 a 35 años', () async {
      final (e, _, _) = await _nuevo(); // hoy: 2026-11-09
      expect(validar(e, ''), contains('fecha de nacimiento'));
      expect(validar(e, '2014-01-01'), contains('13 años o más')); // 12
      expect(validar(e, '2011-01-01'), contains('consentimiento')); // 15
      expect(validar(e, '2011-01-01', tutor: true), isNull);
      expect(validar(e, '2000-01-01', privacidad: false), contains('privacidad'));
      expect(e.edadDe('2013-11-09'), 13);
      expect(e.edadDe('2013-11-10'), 12);
      await e.registrarse(
        correo: 'b@b.com',
        password: '123456',
        nombre: 'Beto',
        fechaNac: '1980-05-05',
        aceptaPrivacidad: true,
      );
      expect(e.tieneCuenta, isTrue); // mayores de 35: solo se avisa
      expect(e.fueraDeRangoObjetivo, isTrue);
      expect(e.cuenta!.aceptoPrivacidad, isTrue);
    });
  });

  group('Pendiente 10 · Niveles separados', () {
    test('avatar cada 100 Exp y mascota cada 150 Exp', () async {
      final (e, _, _) = await _nuevo();
      ResultadoCompletar? r;
      for (var i = 0; i < 5; i++) {
        r = e.completarActividad(await e.crearTarea('T$i', 'Otro', 3));
      }
      expect(e.xpTotal, 150);
      expect(e.nivel, 2);
      expect(e.nivelMascota, 2);
      expect(r!.subioMascota, isTrue);
      expect(r.subioNivel, isFalse);
    });
  });

  group('Pendiente 9 · Servicio de notificaciones', () {
    test('guardar o quitar un recordatorio reprograma los avisos', () async {
      final n = _NotificadorFalso();
      final (e, _, _) = await _nuevo(notificador: n);
      final antes = n.llamadas;
      await e.guardarRecordatorio(
        Recordatorio(id: 'r1', titulo: 'Agua', horaMinutos: 600, diasSemana: [1, 2]),
      );
      expect(n.llamadas, antes + 1);
      expect(n.ultimos, 1);
      expect(n.ultimoSuave, isFalse);
      await e.eliminarRecordatorio('r1');
      expect(n.ultimos, 0);
    });
  });

  group('Pendiente 8 · Servidor y RNF-07 sin duplicados', () {
    /// Servidor falso que imita al backend: guarda ids y responde duplicados.
    MockClient servidor(Set<String> guardados, List<String> rutas) => MockClient((req) async {
      rutas.add('${req.method} ${req.url.path}');
      final cuerpo = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
      Map<String, dynamic> sesion() => {
        'token': 'jwt-de-prueba',
        'usuario': {'id': 'u1', 'nombre': 'Ana', 'rol': 'usuario'},
      };
      switch (req.url.path) {
        case '/api/v1/salud':
          return _json(({'estado': 'ok'}), 200);
        case '/api/v1/auth/login':
          return _json(({'detail': 'Correo o contraseña incorrectos'}), 401);
        case '/api/v1/auth/registro':
          expect(cuerpo['fecha_nac'], '2000-01-01');
          expect(cuerpo['acepta_privacidad'], isTrue);
          return _json((sesion()), 201);
        case '/api/v1/sync':
          expect(req.headers['Authorization'], 'Bearer jwt-de-prueba');
          final aceptados = <String>[];
          final duplicados = <String>[];
          for (final ev in (cuerpo['eventos'] as List).cast<Map<String, dynamic>>()) {
            final id = ev['id'] as String;
            (guardados.add(id) ? aceptados : duplicados).add(id);
          }
          return http.Response(
            jsonEncode({'aceptados': aceptados, 'duplicados': duplicados, 'rechazados': []}),
            200,
          );
        case '/api/v1/fantasma/senales':
          return req.method == 'GET'
              ? _json(([{'id': 's-9', 'hace_minutos': 5}]), 200)
              : _json(({'id': 's-mia'}), 201);
        case '/api/v1/fantasma/recibidas':
          return _json(([]), 200);
        case '/api/v1/comunidad/publicaciones':
          return _json(([]), 200);
        default:
          return _json(({'detail': 'No existe'}), 404);
      }
    });

    test('conecta (crea la cuenta remota) y sincroniza sin duplicar', () async {
      final guardados = <String>{};
      final rutas = <String>[];
      final (e, _, _) = await _nuevo(cliente: servidor(guardados, rutas));
      await e.registrarse(
        correo: 'ana@brota.mx',
        password: 'secreto123',
        nombre: 'Ana',
        fechaNac: '2000-01-01',
        aceptaPrivacidad: true,
      );
      await e.registrarAnimo(3, 2);
      await e.crearTarea('Leer 5 minutos', 'Estudio', 1);
      expect(await e.conectarServidor('http://localhost:8000', 'mala'), contains('no coincide'));
      expect(await e.conectarServidor('http://localhost:8000/', 'secreto123'), isNull);
      expect(e.conectado, isTrue);
      expect(rutas, containsAllInOrder(['GET /api/v1/salud', 'POST /api/v1/auth/login', 'POST /api/v1/auth/registro', 'POST /api/v1/sync']));
      expect(e.cambiosPendientes, isEmpty);
      expect(guardados.length, 2);
      expect(e.senalesFantasma.single.id, 's-9'); // señal real, no simulada

      // Un reenvío del mismo evento no duplica nada en el servidor.
      final copia = EntradaSincronizacion(id: guardados.first, tipo: 'animo', fecha: '2026-11-09T09:00:00', datos: const {'dia': '2026-11-09', 'animo': 3, 'energia': 2});
      e.cambiosPendientes.add(copia);
      final r = await e.sincronizar();
      expect(r, contains('1 ya estaban'));
      expect(guardados.length, 2);
      expect(e.cambiosPendientes, isEmpty);
      e.dispose();
    });

    test('si el servidor no responde, la cola se conserva', () async {
      final caido = MockClient((_) async => throw const SocketException('sin red'));
      final (e, _, _) = await _nuevo(cliente: caido);
      await e.registrarse(
        correo: 'ana@brota.mx',
        password: 'secreto123',
        nombre: 'Ana',
        fechaNac: '2000-01-01',
        aceptaPrivacidad: true,
      );
      expect(await e.conectarServidor('http://10.0.2.2:8000', 'secreto123'), 'No hay conexión con el servidor');
      expect(e.conectado, isFalse);
      await e.crearTarea('Algo', 'Otro', 1);
      expect(e.cambiosPendientes.length, 1);
    });
  });
}

/// Respuesta JSON en UTF-8, como la del backend real.
http.Response _json(Object cuerpo, int codigo) =>
    http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), codigo);
