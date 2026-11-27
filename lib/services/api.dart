import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/modelos.dart';

/// Servidor oficial con el que se compila el APK que se reparte:
///   flutter build apk --release --dart-define=BROTA_SERVIDOR=https://brota.midominio.com
/// Vacío en desarrollo: la pantalla del servidor muestra el campo de dirección.
const String servidorPredeterminado = String.fromEnvironment('BROTA_SERVIDOR');

/// Error devuelto por el servidor o por la red, con mensaje en español.
class ErrorApi implements Exception {
  ErrorApi(this.mensaje, {this.codigo = 0});

  final String mensaje;

  /// Código HTTP; 0 si no hubo respuesta (sin red, servidor apagado).
  final int codigo;

  @override
  String toString() => mensaje;
}

class SesionApi {
  const SesionApi({
    required this.token,
    required this.rol,
    this.avisoEdad = false,
  });

  final String token;
  final String rol;
  final bool avisoEdad;
}

class ResultadoSync {
  const ResultadoSync({
    required this.aceptados,
    required this.duplicados,
    required this.rechazados,
  });

  final List<String> aceptados;
  final List<String> duplicados;
  final List<String> rechazados;
}

/// Cliente del backend Brota (repositorio Backend-Brota, API REST /api/v1).
///
/// Es opcional: la app funciona completa sin servidor. Cuando el usuario
/// conecta su cuenta (Más → Servidor y sincronización), se usa para el JWT,
/// la sincronización sin duplicados (RNF-07), el compañero fantasma real y el
/// muro compartido y moderado. En producción la URL debe ser HTTPS.
class ServicioApi {
  ServicioApi(String url, {http.Client? cliente, this.token})
    : base = _normalizar(url),
      _cliente = cliente ?? http.Client();

  final String base;
  final http.Client _cliente;
  String? token;

  static const Duration _espera = Duration(seconds: 8);

  static String _normalizar(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api/v1')) u = '$u/api/v1';
    return u;
  }

  Map<String, String> get _cabeceras => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<dynamic> _pedir(String metodo, String ruta, [Object? cuerpo]) async {
    final uri = Uri.parse('$base$ruta');
    http.Response r;
    try {
      final body = cuerpo == null ? null : jsonEncode(cuerpo);
      r = await switch (metodo) {
        'GET' => _cliente.get(uri, headers: _cabeceras),
        'POST' => _cliente.post(uri, headers: _cabeceras, body: body),
        _ => throw ArgumentError(metodo),
      }.timeout(_espera);
    } on ErrorApi {
      rethrow;
    } catch (_) {
      throw ErrorApi('No hay conexión con el servidor');
    }
    final texto = utf8.decode(r.bodyBytes);
    final datos = texto.isEmpty ? null : jsonDecode(texto);
    if (r.statusCode >= 400) {
      final detalle = datos is Map && datos['detail'] is String
          ? datos['detail'] as String
          : 'El servidor respondió ${r.statusCode}';
      throw ErrorApi(detalle, codigo: r.statusCode);
    }
    return datos;
  }

  Future<bool> salud() async {
    final d = await _pedir('GET', '/salud');
    return d is Map && d['estado'] == 'ok';
  }

  SesionApi _sesion(dynamic d) {
    final m = d as Map<String, dynamic>;
    final s = SesionApi(
      token: m['token'] as String,
      rol: (m['usuario'] as Map?)?['rol'] as String? ?? 'usuario',
      avisoEdad: m['aviso_edad'] as bool? ?? false,
    );
    token = s.token;
    return s;
  }

  Future<SesionApi> login(String correo, String password) async =>
      _sesion(
        await _pedir('POST', '/auth/login', {
          'correo': correo,
          'password': password,
        }),
      );

  Future<SesionApi> registro({
    required String correo,
    required String password,
    required String nombre,
    required String fechaNac,
    required bool aceptaPrivacidad,
    required bool consentimientoTutor,
  }) async => _sesion(
    await _pedir('POST', '/auth/registro', {
      'correo': correo,
      'password': password,
      'nombre': nombre,
      'fecha_nac': fechaNac,
      'acepta_privacidad': aceptaPrivacidad,
      'consentimiento_tutor': consentimientoTutor,
    }),
  );

  /// POST /sync: reenviar el mismo lote no duplica nada en el servidor.
  Future<ResultadoSync> sincronizar(List<EntradaSincronizacion> lote) async {
    final d = await _pedir('POST', '/sync', {
      'eventos': [for (final e in lote) e.toJson()],
    }) as Map<String, dynamic>;
    List<String> l(String k) => ((d[k] as List?) ?? []).cast<String>();
    return ResultadoSync(
      aceptados: l('aceptados'),
      duplicados: l('duplicados'),
      rechazados: l('rechazados'),
    );
  }

  // ------------------------------------------------ compañero fantasma ---

  Future<void> enviarSenal() async => _pedir('POST', '/fantasma/senales', {});

  Future<List<SenalFantasma>> senales() async {
    final d = await _pedir('GET', '/fantasma/senales') as List;
    return [
      for (final s in d.cast<Map<String, dynamic>>())
        SenalFantasma(
          id: '${s['id']}',
          haceMinutos: (s['hace_minutos'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  Future<void> reaccionar(String senalId, String reaccion) async =>
      _pedir('POST', '/fantasma/reacciones', {
        'senal_id': senalId,
        'reaccion': reaccion,
      });

  Future<List<String>> recibidas() async {
    final d = await _pedir('GET', '/fantasma/recibidas') as List;
    return [
      for (final r in d.cast<Map<String, dynamic>>()) r['reaccion'] as String,
    ];
  }

  // ------------------------------------------------- muro moderado -------

  Future<List<Publicacion>> publicaciones() async {
    final d = await _pedir('GET', '/comunidad/publicaciones') as List;
    return [
      for (final p in d.cast<Map<String, dynamic>>())
        Publicacion(
          id: 'srv-${p['id']}',
          contenido: p['texto'] as String,
          fecha: (p['fecha'] as String).substring(0, 10),
          esLogro: p['es_logro'] as bool? ?? false,
        ),
    ];
  }

  Future<void> publicarFrase(String fraseId) async =>
      _pedir('POST', '/comunidad/publicaciones', {'frase_id': fraseId});

  Future<void> publicarLogro(int racha, int xp) async =>
      _pedir('POST', '/comunidad/publicaciones', {
        'logro': {'racha': racha, 'xp': xp},
      });

  Future<void> reportar(String publicacionId, String motivo) async => _pedir(
    'POST',
    '/comunidad/publicaciones/${publicacionId.replaceFirst('srv-', '')}/reportes',
    {'motivo': motivo},
  );

  Future<List<ReportePublicacion>> reportesPendientes() async {
    final d = await _pedir('GET', '/admin/reportes') as List;
    return [
      for (final r in d.cast<Map<String, dynamic>>())
        ReportePublicacion(
          id: 'srv-${r['id']}',
          publicacionId: 'srv-${r['publicacion_id']}',
          texto: r['texto'] as String? ?? '',
          motivo: r['motivo'] as String? ?? '',
          fecha: (r['fecha'] as String? ?? '').split('T').first,
        ),
    ];
  }

  Future<void> resolverReporte(String reporteId, bool ocultar) async => _pedir(
    'POST',
    '/admin/reportes/${reporteId.replaceFirst('srv-', '')}/resolver',
    {'accion': ocultar ? 'ocultar' : 'mantener'},
  );
}
