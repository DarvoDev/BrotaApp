import 'package:brota_app/main.dart';
import 'package:brota_app/models/modelos.dart';
import 'package:brota_app/services/almacen.dart';
import 'package:brota_app/state/brota_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reloj controlable para simular el paso de los días.
class Reloj {
  Reloj(this.ahora);
  DateTime ahora;
  DateTime call() => ahora;
  void avanzarDias(int n) => ahora = sumarDias(ahora, n).add(const Duration(hours: 9));
}

Future<(BrotaState, Reloj, AlmacenMemoria)> nuevo(DateTime inicio) async {
  final reloj = Reloj(inicio);
  final almacen = AlmacenMemoria();
  final estado = BrotaState(almacen: almacen, ahora: reloj.call);
  await estado.iniciar();
  return (estado, reloj, almacen);
}

void main() {
  // Lunes 9 de noviembre de 2026, 9:00.
  final lunes = DateTime(2026, 11, 9, 9);

  group('CU-05 Registrar estado de ánimo diario', () {
    test('ánimo bajo deja solo metas ligeras y en menor cantidad (CU-05a)', () async {
      final (e, _, _) = await nuevo(lunes);
      expect(e.metasHoy.length, 3);
      await e.registrarAnimo(1, 2);
      expect(e.metasHoy.length, 2);
      expect(e.metasHoy.every((m) => m.esfuerzo == 1), isTrue);
    });

    test('ánimo y energía altos agregan un reto de esfuerzo alto', () async {
      final (e, _, _) = await nuevo(lunes);
      await e.registrarAnimo(5, 3);
      expect(e.metasHoy.map((m) => m.esfuerzo), [1, 2, 3]);
    });

    test('A1: «ahora no» no vuelve a preguntar ese día, sí al siguiente', () async {
      final (e, reloj, _) = await nuevo(lunes);
      expect(e.debePreguntarAnimo, isTrue);
      await e.omitirAnimo();
      expect(e.debePreguntarAnimo, isFalse);
      reloj.avanzarDias(1);
      await e.abrirDia();
      expect(e.debePreguntarAnimo, isTrue);
    });

    test('A2: actualizar conserva el último valor y lo ya completado', () async {
      final (e, _, _) = await nuevo(lunes);
      await e.registrarAnimo(5, 3);
      final reto = e.metasHoy.last;
      e.completarActividad(reto);
      await e.registrarAnimo(2, 1);
      expect(e.animoDeHoy!.animo, 2);
      expect(e.animos.length, 1);
      expect(e.metasHoy.any((m) => m.id == reto.id), isTrue);
    });

    test('A3: tres días en el nivel más bajo sugieren recursos de ayuda', () async {
      final (e, reloj, _) = await nuevo(lunes);
      for (var i = 0; i < 3; i++) {
        expect(e.sugerirRecursos, isFalse);
        await e.registrarAnimo(1, 1);
        e.completarActividad(e.metasHoy.first);
        if (i < 2) {
          reloj.avanzarDias(1);
          await e.abrirDia();
        }
      }
      expect(e.sugerirRecursos, isTrue);
    });
  });

  group('CU-07 Crear tarea personalizada', () {
    test('se crea con categoría y esfuerzo, y valida el nombre', () async {
      final (e, _, _) = await nuevo(lunes);
      expect(e.validarTitulo('   '), isNotNull);
      expect(e.validarTitulo('Tender la cama'), isNull);
      final t = await e.crearTarea(' Tender la cama ', 'Hogar', 2);
      expect(t.titulo, 'Tender la cama');
      expect(t.categoria, 'Hogar');
      expect(t.calcularXP(), 20);
      expect(e.validarTitulo('tender la cama'), isNotNull);
    });
  });

  group('CU-09 Completar actividad', () {
    test('otorga XP una sola vez por día e inicia la racha', () async {
      final (e, _, _) = await nuevo(lunes);
      final m = e.metasHoy.first;
      final r = e.completarActividad(m)!;
      expect(r.xp, m.calcularXP());
      expect(e.xpTotal, m.calcularXP());
      expect(e.racha.dias, 1);
      expect(e.completarActividad(m), isNull);
      expect(e.xpTotal, m.calcularXP());
    });

    test('CU-09b: sube de nivel al alcanzar 100 XP', () async {
      final (e, _, _) = await nuevo(lunes);
      ResultadoCompletar? ultimo;
      for (var i = 0; i < 4; i++) {
        final t = await e.crearTarea('Tarea $i', 'Otro', 3); // 30 XP
        ultimo = e.completarActividad(t);
      }
      expect(e.xpTotal, 120);
      expect(e.nivel, 2);
      expect(ultimo!.subioNivel, isTrue);
      expect(e.xpEnNivel, 20);
    });

    test('desmarcar devuelve la XP y la racha del día', () async {
      final (e, _, _) = await nuevo(lunes);
      final m = e.metasHoy.first;
      e.completarActividad(m);
      e.desmarcarActividad(m);
      expect(e.xpTotal, 0);
      expect(e.racha.dias, 0);
    });
  });

  group('CU-10 Proteger racha flexible', () {
    test('un día sin actividad consume un escudo y conserva racha y XP', () async {
      final (e, reloj, _) = await nuevo(lunes);
      e.completarActividad(e.metasHoy.first);
      final xp = e.xpTotal;
      reloj.avanzarDias(2); // martes sin abrir; es miércoles
      await e.abrirDia();
      expect(e.racha.dias, 1);
      expect(e.racha.congelamientos, 0); // 1 escudo por semana
      expect(e.xpTotal, xp);
      expect(e.fueDescanso(DateTime(2026, 11, 10)), isTrue);
      expect(e.mensajeCierre!.reiniciada, isFalse);
      expect(e.mensajeCierre!.escudosUsados, 1);
    });

    test('A1: con actividad cada día no se consume nada', () async {
      final (e, reloj, _) = await nuevo(lunes);
      e.completarActividad(e.metasHoy.first);
      reloj.avanzarDias(1);
      await e.abrirDia();
      e.completarActividad(e.metasHoy.first);
      expect(e.racha.dias, 2);
      expect(e.racha.congelamientos, 1);
      expect(e.mensajeCierre, isNull);
    });

    test('A2: sin escudos la racha se reinicia pero XP y nivel se conservan', () async {
      final (e, reloj, _) = await nuevo(lunes);
      for (var i = 0; i < 4; i++) {
        e.completarActividad(await e.crearTarea('Tarea $i', 'Otro', 3));
      }
      reloj.avanzarDias(4); // martes, miércoles y jueves sin actividad; es viernes
      await e.abrirDia();
      expect(e.racha.dias, 0);
      expect(e.racha.congelamientos, 0);
      expect(e.xpTotal, 120);
      expect(e.nivel, 2);
      expect(e.mensajeCierre!.reiniciada, isTrue);
      expect(e.diasInactivosSeguidos, 3);
      expect(e.sugerirRecursos, isTrue); // A3
    });

    test('los escudos se renuevan cada lunes', () async {
      final (e, reloj, _) = await nuevo(lunes);
      e.completarActividad(e.metasHoy.first);
      reloj.avanzarDias(2);
      await e.abrirDia();
      expect(e.racha.congelamientos, 0);
      e.completarActividad(e.metasHoy.first);
      reloj.avanzarDias(5); // lunes siguiente
      await e.abrirDia();
      // jueves a domingo: sin escudo, la racha se reinicia; el lunes vuelve 1
      expect(e.racha.congelamientos, 1);
    });

    test('E1: el estado sobrevive a cerrar y reabrir la app', () async {
      final (e, reloj, almacen) = await nuevo(lunes);
      e.completarActividad(e.metasHoy.first);
      await e.registrarAnimo(4, 2);
      await e.agregarContacto('Mamá', '222 123 4567');
      reloj.avanzarDias(2);
      final otra = BrotaState(almacen: almacen, ahora: reloj.call);
      await otra.iniciar();
      expect(otra.racha.dias, 1);
      expect(otra.racha.congelamientos, 0);
      expect(otra.contactos.single.nombre, 'Mamá');
      expect(otra.animos.length, 1);
    });
  });

  group('CU-13 Activar botón SOS emocional', () {
    test('registra el uso sin tocar XP ni racha', () async {
      final (e, _, _) = await nuevo(lunes);
      e.completarActividad(e.metasHoy.first);
      final xp = e.xpTotal;
      await e.activarSOS('llamada: Línea de la Vida');
      expect(e.usosSos.length, 1);
      expect(e.xpTotal, xp);
      expect(e.racha.dias, 1);
    });
  });

  testWidgets('la app abre con el chequeo de ánimo y el botón S.O.S', (t) async {
    final estado = BrotaState(almacen: AlmacenMemoria());
    await estado.iniciar();
    await t.pumpWidget(BrotaApp(estado: estado));
    await t.pumpAndSettle();
    expect(find.text('¿Cómo te sientes hoy?'), findsWidgets);
    await t.tap(find.text('Ahora no'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Misiones de hoy'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Misiones de hoy'), findsOneWidget);
    expect(find.text('S.O.S'), findsWidgets);
    expect(estado.debePreguntarAnimo, isFalse);
  });

  testWidgets('recorrido en pantalla de teléfono sin desbordes', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final estado = BrotaState(almacen: AlmacenMemoria());
    await estado.iniciar();
    await t.pumpWidget(BrotaApp(estado: estado));
    await t.pumpAndSettle();

    // CU-05: registrar ánimo bajo ajusta las metas.
    await t.tap(find.text('Mal'));
    await t.tap(find.text('Baja'));
    await t.pump();
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(estado.animoDeHoy!.esBajo(), isTrue);
    expect(find.textContaining('Hoy toca algo suave'), findsOneWidget);

    // CU-09: completar una misión da XP.
    await t.scrollUntilVisible(
      find.text(estado.metasHoy.first.titulo),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text(estado.metasHoy.first.titulo));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('🌿 +10 Exp'), findsOneWidget); // aviso implícito
    expect(estado.racha.dias, 1);
    await t.pumpAndSettle(const Duration(seconds: 3));

    // CU-07: crear tarea personalizada.
    await t.scrollUntilVisible(
      find.text('Nueva tarea'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Se sube un poco más para que el botón no quede bajo el S.O.S.
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await t.pumpAndSettle();
    await t.tap(find.text('Nueva tarea'));
    await t.pumpAndSettle();
    await t.tap(find.text('Crear tarea'));
    await t.pump();
    expect(find.text('Escribe un nombre para tu tarea'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Tender la cama');
    await t.tap(find.text('Hogar'));
    await t.tap(find.text('Medio'));
    await t.pump();
    await t.tap(find.text('Crear tarea'));
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect(estado.tareas.single.categoria, 'Hogar');
    expect(find.text('Hogar · medio'), findsOneWidget);

    // Jardín y Rachas.
    await t.tap(find.text('Jardín'));
    await t.pumpAndSettle();
    expect(find.text('Tu jardín'), findsOneWidget);
    await t.tap(find.text('Rachas'));
    await t.pumpAndSettle();
    expect(find.text('día de racha'), findsOneWidget);

    // CU-13: botón SOS → emergencia primero → una sola confirmación.
    await t.tap(find.byType(FloatingActionButton));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Emergencias 911'), findsOneWidget);
    await t.tap(find.text('Llamar').first);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('¿Llamar a Emergencias 911?'), findsOneWidget);
    await t.tap(find.text('Cancelar'));
    await t.pump(const Duration(milliseconds: 500));
    expect(estado.usosSos, isEmpty); // A3

    await t.scrollUntilVisible(
      find.text('Agregar contacto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(find.byType(TextField).first, 'Mamá');
    await t.enterText(find.byType(TextField).last, '222 123 4567');
    await t.tap(find.text('Agregar contacto'));
    await t.pump(const Duration(milliseconds: 500));
    expect(estado.contactos.single.nombre, 'Mamá');
    expect(find.text('Mensaje'), findsOneWidget);
  });
}
