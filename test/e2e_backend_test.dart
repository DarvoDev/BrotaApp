// Prueba de extremo a extremo contra el backend real (Backend-Brota).
// Se omite si no hay servidor. Para correrla:
//   cd Backend-Brota && docker compose up -d --build
//   BROTA_API=http://localhost:8000 flutter test test/e2e_backend_test.dart
import 'dart:io';

import 'package:brota_app/models/modelos.dart';
import 'package:brota_app/services/almacen.dart';
import 'package:brota_app/state/brota_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final url = Platform.environment['BROTA_API'];

  test(
    'registro, sincronización sin duplicados, fantasma y muro con el servidor real',
    () async {
      final correo = 'e2e${DateTime.now().millisecondsSinceEpoch}@brota.mx';
      final e = BrotaState(almacen: AlmacenMemoria());
      await e.iniciar();
      expect(
        await e.registrarse(
          correo: correo,
          password: 'secreto123',
          nombre: 'Prueba',
          fechaNac: '2001-03-04',
          aceptaPrivacidad: true,
        ),
        isTrue,
      );
      await e.registrarAnimo(3, 2);
      e.completarActividad(e.metasHoy.first);
      final ids = e.cambiosPendientes.map((c) => c.id).toList();
      expect(ids, isNotEmpty);

      expect(await e.conectarServidor(url!, 'secreto123'), isNull);
      expect(e.conectado, isTrue);
      expect(e.cambiosPendientes, isEmpty);

      // Reenviar los mismos eventos: el servidor los reconoce como duplicados.
      e.cambiosPendientes.add(
        EntradaSincronizacion(
          id: ids.first,
          tipo: 'animo',
          fecha: DateTime.now().toIso8601String(),
          datos: {'dia': claveDia(DateTime.now()), 'animo': 3, 'energia': 2},
        ),
      );
      final r = await e.sincronizar();
      expect(r, contains('0 nuevo(s), 1 ya estaban'));

      // Muro: solo frases predefinidas; publicar y reportar.
      final p = await e.publicarFrase('f-2');
      expect(p.id, startsWith('srv-'));
      await e.reportarPublicacion(p, 'Parece spam');
      expect(e.publicacionesVisibles.any((x) => x.id == p.id), isFalse);

      // Compañero fantasma entre dos personas reales.
      final b = BrotaState(almacen: AlmacenMemoria());
      await b.iniciar();
      await b.registrarse(
        correo: 'b$correo',
        password: 'secreto123',
        nombre: 'Otra',
        fechaNac: '2003-05-06',
        aceptaPrivacidad: true,
      );
      expect(await b.conectarServidor(url, 'secreto123'), isNull);
      b.completarActividad(b.metasHoy.first); // envía «completé mi misión»
      await Future<void>.delayed(const Duration(seconds: 1));
      await e.refrescarFantasma();
      final senal = e.senalesFantasma.firstWhere((s) => !s.simulada);
      await e.reaccionarASenal(senal, 'sigue_asi');
      await b.refrescarFantasma();
      expect(b.reaccionesNuevas.map((i) => i.reaccion), contains('sigue_asi'));
      expect(b.reaccionesNuevas.every((i) => !i.simulada), isTrue);
      e.dispose();
      b.dispose();
    },
    skip: url == null ? 'Define BROTA_API para probar contra el servidor' : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
