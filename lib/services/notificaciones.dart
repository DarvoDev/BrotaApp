import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdatos;
import 'package:timezone/timezone.dart' as tz;

import '../models/modelos.dart';

/// Actor «Servicio de notificaciones» (CU-08, RF-07). BrotaState solo conoce
/// esta interfaz; así las pruebas no dependen del sistema operativo.
abstract class Notificador {
  /// Reemplaza todos los avisos programados por los de [lista].
  /// En modo suave (ánimo bajo o días de descanso) se deja 1 aviso por día.
  Future<void> programar(
    List<Recordatorio> lista, {
    required bool suave,
    required String nombreMascota,
  });
}

/// Notificaciones locales de Android: no necesitan servidor ni internet.
/// En web no hace nada (los recordatorios se ven al abrir la app).
class NotificadorLocal implements Notificador {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _listo = false;

  bool get _soportado =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _iniciar() async {
    if (_listo) return;
    tzdatos.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _listo = true;
  }

  @override
  Future<void> programar(
    List<Recordatorio> lista, {
    required bool suave,
    required String nombreMascota,
  }) async {
    if (!_soportado) return;
    try {
      await _iniciar();
      await _plugin.cancelAll();
      const detalles = NotificationDetails(
        android: AndroidNotificationDetails(
          'recordatorios',
          'Recordatorios amables',
          channelDescription: 'Avisos suaves de tus actividades',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      final usados = <int>{};
      var id = 0;
      final activos = [...lista.where((r) => r.activo)]
        ..sort((a, b) => a.horaMinutos.compareTo(b.horaMinutos));
      for (final r in activos) {
        for (final dia in r.diasSemana) {
          if (suave && usados.contains(dia)) continue;
          usados.add(dia);
          await _plugin.zonedSchedule(
            id: id++,
            title: 'Brota 🌱',
            body: '${r.titulo} · $nombreMascota te espera, sin prisa',
            scheduledDate: _siguiente(dia, r.horaMinutos),
            notificationDetails: detalles,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    } catch (e) {
      // Si el sistema niega el permiso, la app sigue mostrando los
      // recordatorios del día en Inicio.
      debugPrint('No se pudieron programar notificaciones: $e');
    }
  }

  /// Próxima fecha con ese día de la semana (1 = lunes) y hora.
  tz.TZDateTime _siguiente(int diaSemana, int minutos) {
    final ahora = tz.TZDateTime.now(tz.local);
    var f = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      minutos ~/ 60,
      minutos % 60,
    );
    while (f.weekday != diaSemana || !f.isAfter(ahora)) {
      f = f.add(const Duration(days: 1));
    }
    return f;
  }
}
