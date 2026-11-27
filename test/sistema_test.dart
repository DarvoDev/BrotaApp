import 'dart:convert';

import 'package:brota_app/data/catalogo.dart';
import 'package:brota_app/models/modelos.dart';
import 'package:brota_app/services/almacen.dart';
import 'package:brota_app/services/cifrado.dart';
import 'package:brota_app/state/brota_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reloj controlable para probar reglas que dependen del día.
class _Reloj {
  _Reloj(this.ahora);
  DateTime ahora;
  DateTime call() => ahora;
  void avanzar(int dias) =>
      ahora = sumarDias(ahora, dias).add(const Duration(hours: 9));
}

Future<(BrotaState, AlmacenMemoria, _Reloj)> _estado([DateTime? inicio]) async {
  final reloj = _Reloj(inicio ?? DateTime(2026, 11, 16, 9)); // lunes
  final almacen = AlmacenMemoria();
  final estado = BrotaState(servidor: '', almacen: almacen, ahora: reloj.call);
  await estado.iniciar();
  return (estado, almacen, reloj);
}

void main() {
  group('RNF-02 Cifrado del almacenamiento local', () {
    test('el texto cifrado se descifra y detecta manipulación', () {
      const clave = 'brota-clave-local-v2';
      const original = '{"animo":1,"sos":"llamada"}';
      final cifrado = CifradoLocal.cifrar(original, clave: clave);
      expect(cifrado, isNot(contains('animo')));
      expect(CifradoLocal.descifrar(cifrado, clave: clave), original);

      final bytes = base64.decode(cifrado);
      bytes[bytes.length - 1] = bytes.last == 0 ? 1 : 0;
      expect(
        () => CifradoLocal.descifrar(base64.encode(bytes), clave: clave),
        throwsFormatException,
      );
    });

    test('lo guardado no se lee como texto y sobrevive al reinicio', () async {
      final (estado, almacen, reloj) = await _estado();
      await estado.registrarAnimo(2, 1);
      await estado.activarSOS('llamada: Línea de la Vida');
      expect(almacen.datos, isNotNull);
      expect(almacen.datos, isNot(contains('Línea de la Vida')));
      expect(almacen.datos, isNot(contains('"animo"')));

      final otro = BrotaState(
        servidor: '',
        almacen: almacen,
        ahora: reloj.call,
      );
      await otro.iniciar();
      expect(otro.animoDeHoy!.animo, 2);
      expect(otro.usosSos.single['opcion'], 'llamada: Línea de la Vida');
    });
  });

  group('CU-01 Registrarse y CU-02 Iniciar sesión', () {
    test(
      'valida correo, contraseña y nombre; distingue al administrador',
      () async {
        final (e, _, _) = await _estado();
        expect(
          e.validarRegistro(
            correo: 'x',
            password: '123456',
            nombre: 'Ana',
            fechaNac: '2000-01-01',
            aceptaPrivacidad: true,
          ),
          isNotNull,
        );
        expect(
          e.validarRegistro(
            correo: 'a@b.com',
            password: '123',
            nombre: 'Ana',
            fechaNac: '2000-01-01',
            aceptaPrivacidad: true,
          ),
          isNotNull,
        );
        expect(
          e.validarRegistro(
            correo: 'a@b.com',
            password: '123456',
            nombre: 'Ana',
            fechaNac: '2000-01-01',
            aceptaPrivacidad: true,
          ),
          isNull,
        );

        final ok = await e.registrarse(
          correo: ' ana@brota.mx ',
          password: 'secreto123',
          fechaNac: '2000-01-01',
          aceptaPrivacidad: true,
          nombre: 'Ana',
          apellidos: 'Pérez',
          rol: Rol.administrador,
        );
        expect(ok, isTrue);
        expect(e.cuenta!.correo, 'ana@brota.mx');
        expect(e.cuenta!.hash, isNot(contains('secreto123')));
        expect(e.esAdmin, isTrue);
        expect(e.nombreUsuario, 'Ana');
      },
    );

    test('rechaza una contraseña incorrecta y acepta la correcta', () async {
      final (e, _, _) = await _estado();
      await e.registrarse(
        correo: 'ana@brota.mx',
        password: 'secreto123',
        fechaNac: '2000-01-01',
        aceptaPrivacidad: true,
        nombre: 'Ana',
      );
      expect(await e.iniciarSesion('ana@brota.mx', 'mala'), isFalse);
      expect(await e.iniciarSesion('otro@brota.mx', 'secreto123'), isFalse);
      expect(await e.iniciarSesion('ana@brota.mx', 'secreto123'), isTrue);
      await e.cerrarSesion();
      expect(e.tieneCuenta, isFalse);
      await e.continuarComoInvitado();
      expect(e.tieneCuenta, isFalse);
    });
  });

  group('CU-03 Avatar y CU-04 Mascota', () {
    test('se personalizan y persisten', () async {
      final (e, almacen, _) = await _estado();
      await e.personalizarAvatar('🌻');
      await e.elegirMascota('🐰', '  Lola  ');
      expect(e.avatar, '🌻');
      expect(e.mascota, '🐰');
      expect(e.mascotaNombre, 'Lola');

      final otro = BrotaState(servidor: '', almacen: almacen);
      await otro.iniciar();
      expect(otro.avatar, '🌻');
      expect(otro.mascotaNombre, 'Lola');
    });
  });

  group('CU-06 Explorar catálogo', () {
    test(
      'el catálogo ofrece microactividades y se pueden llevar a hoy',
      () async {
        final (e, _, _) = await _estado();
        expect(e.catalogo.length, 12);
        expect(
          CatalogoMicroactividades.todas.where((m) => m.esfuerzo == 1).length,
          5,
        );
        final m = e.catalogo.firstWhere(
          (x) => !e.metasHoy.any((actual) => actual.id == x.id),
        );
        await e.agregarMetaDelCatalogo(m.id);
        expect(e.metasExtra, [m.id]);
        expect(e.metasTotalesHoy.map((x) => x.id), contains(m.id));
        await e.agregarMetaDelCatalogo(m.id);
        expect(e.metasExtra.length, 1);
        await e.quitarMetaExtra(m.id);
        expect(e.metasExtra, isEmpty);
      },
    );
  });

  group('CU-08 Recordatorios amables', () {
    test(
      'se guardan, se actualizan y bajan de frecuencia con ánimo bajo',
      () async {
        final (e, _, reloj) = await _estado();
        final r = Recordatorio(
          id: 'r-1',
          titulo: 'Movilizarme un poco',
          horaMinutos: 9 * 60,
          diasSemana: [1, 2, 3, 4, 5],
        );
        await e.guardarRecordatorio(r);
        expect(e.recordatoriosDeHoy.single.horaTexto, '09:00');
        expect(r.aplicaHoy(DateTime(2026, 11, 16)), isTrue); // lunes
        expect(r.aplicaHoy(DateTime(2026, 11, 21)), isFalse); // sábado

        await e.guardarRecordatorio(r.copiaCon(activoNuevo: false));
        expect(e.recordatorios.single.activo, isFalse);
        await e.eliminarRecordatorio('r-1');
        expect(e.recordatorios, isEmpty);

        for (var i = 0; i < 3; i++) {
          await e.registrarAnimo(1, 1);
          if (i < 2) {
            reloj.avanzar(1);
            await e.abrirDia();
          }
        }
        expect(e.modoRecordatorioSuave, isTrue);
      },
    );
  });

  group('CU-11 Recursos de ayuda y CU-19 directorio', () {
    test('el 911 va primero y el administrador puede ampliarlo', () async {
      final (e, _, _) = await _estado();
      expect(e.recursos.first.esEmergencia, isTrue);
      expect(e.recursos.first.telefono, '911');
      expect(
        () => e.agregarRecurso(nombre: 'X', telefono: '1'),
        throwsStateError,
      );

      await e.registrarse(
        correo: 'admin@brota.mx',
        password: 'secreto123',
        fechaNac: '2000-01-01',
        aceptaPrivacidad: true,
        nombre: 'Sistema',
        rol: Rol.administrador,
      );
      final r = await e.agregarRecurso(
        nombre: 'Línea local',
        telefono: '2221234567',
        descripcion: 'Apoyo en Puebla',
      );
      expect(e.recursos.last.id, r.id);
      await e.eliminarRecurso(r.id);
      expect(e.recursos.any((x) => x.id == r.id), isFalse);
    });
  });

  group('CU-12 Mensajes motivacionales', () {
    test('hay un mensaje del día y el administrador agrega otros', () async {
      final (e, _, _) = await _estado();
      expect(e.mensajeMotivacionalDelDia.texto, isNotEmpty);
      expect(e.mensajeMotivacionalDelDia.validadoPor, isNotEmpty);
      await e.registrarse(
        correo: 'admin@brota.mx',
        password: 'secreto123',
        fechaNac: '2000-01-01',
        aceptaPrivacidad: true,
        nombre: 'Sistema',
        rol: Rol.administrador,
      );
      final m = await e.agregarMensaje(texto: 'Hoy puedes volver 💛');
      expect(e.mensajes.map((x) => x.id), contains(m.id));
      // CU-19a: el diccionario rechaza frases de culpa o comparación.
      expect(
        () =>
            e.agregarMensaje(texto: 'Deberías esforzarte más, no hay excusas'),
        throwsFormatException,
      );
      await e.eliminarMensaje(m.id);
      expect(e.mensajes.any((x) => x.id == m.id), isFalse);
    });
  });

  group('CU-14 Compartir logros y aliento', () {
    test(
      'solo publica frases predefinidas o logros, de forma anónima',
      () async {
        final (e, _, _) = await _estado();
        final antes = e.publicaciones.length;
        expect(() => e.publicarFrase('texto libre'), throwsFormatException);
        final p = await e.publicarFrase(frasesMuro.first.id);
        expect(e.publicaciones.length, antes + 1);
        expect(e.publicaciones.first.id, p.id);
        expect(p.contenido, frasesMuro.first.texto);
        final l = await e.publicarLogro();
        expect(l.esLogro, isTrue);
        expect(e.logroCompartible, contains('Exp'));
      },
    );
  });

  group('CU-15 Panel y CU-16 Resumen semanal', () {
    test('calcula métricas y el resumen de la semana', () async {
      final (e, _, _) = await _estado();
      await e.registrarAnimo(4, 2);
      e.completarActividad(e.metasHoy.first);
      final r = e.resumenSemanal();
      expect(r['inicio'], '2026-11-16');
      expect(r['fin'], '2026-11-22');
      expect(r['activos'], 1);
      expect(r['xp'], greaterThan(0));
      expect(r['animoPromedio'], 4.0);
      expect(e.diasActivos, 1);
      expect(e.rachaMaxima, 1);
      expect(e.porcentajeCumplimiento, 100);
      expect(e.xpDeLosUltimos(7).length, 7);
    });
  });

  group('CU-17 Exportar historial (PDF)', () {
    test('genera un PDF válido y menor a 2 MB', () async {
      final (e, _, _) = await _estado();
      await e.registrarAnimo(3, 2);
      e.completarActividad(e.metasHoy.first);
      final bytes = await e.exportarPdf();
      expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-1.4'));
      expect(bytes.length, lessThan(2 * 1024 * 1024));
      final texto = String.fromCharCodes(bytes);
      expect(texto, contains('Brota - Historial de progreso'));
      expect(texto, contains('startxref'));
      expect(texto, contains('%%EOF'));
    });
  });

  group('CU-18 Administrar catálogo', () {
    test(
      'solo el administrador agrega, edita y elimina microactividades',
      () async {
        final (e, _, _) = await _estado();
        expect(
          () =>
              e.agregarMicroactividad(titulo: 'X', esfuerzo: 1, duracionMin: 1),
          throwsStateError,
        );
        await e.registrarse(
          correo: 'admin@brota.mx',
          password: 'secreto123',
          fechaNac: '2000-01-01',
          aceptaPrivacidad: true,
          nombre: 'Sistema',
          rol: Rol.administrador,
        );
        final m = await e.agregarMicroactividad(
          titulo: 'Respirar en el balcón',
          esfuerzo: 2,
          duracionMin: 3,
        );
        expect(m.calcularXP(), 15);
        await e.actualizarMicroactividad(m.id, titulo: 'Respirar 3 minutos');
        expect(e.microPorId(m.id)!.titulo, 'Respirar 3 minutos');
        await e.eliminarMicroactividad(m.id);
        expect(e.microPorId(m.id), isNull);
      },
    );
  });

  group('RNF-07 Sincronización diferida', () {
    test(
      'sin servidor la cola se conserva cifrada y sobrevive al reinicio',
      () async {
        final (e, almacen, reloj) = await _estado();
        await e.crearTarea('Ordenar el escritorio', 'Hogar', 1);
        await e.crearTarea('Ordenar el escritorio 2', 'Hogar', 1);
        expect(e.hayCambiosPendientes, isTrue);
        expect(e.cambiosPendientes.map((c) => c.tipo), everyElement('tarea'));
        final ids = e.cambiosPendientes.map((c) => c.id).toSet();
        expect(ids.length, 2); // UUID distintos
        final mensaje = await e.sincronizar();
        expect(mensaje, contains('Sin servidor'));
        expect(e.cambiosPendientes.length, 2);

        final otro = BrotaState(
          servidor: '',
          almacen: almacen,
          ahora: reloj.call,
        );
        await otro.iniciar();
        expect(otro.cambiosPendientes.map((c) => c.id).toSet(), ids);
        expect(otro.tareas.length, 2);
      },
    );
  });
}
