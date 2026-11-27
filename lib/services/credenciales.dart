import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda la contraseña del servidor para volver a iniciar sesión sola cuando
/// el token vence (dura 7 días) o cuando la cuenta se creó sin internet.
/// Así la persona nunca tiene que escribirla de nuevo.
abstract class Credenciales {
  Future<String?> leer();
  Future<void> guardar(String password);
  Future<void> borrar();
}

/// En el llavero del sistema: Android Keystore (cifrado por hardware cuando el
/// teléfono lo tiene). Nunca en shared_preferences ni en texto plano.
class CredencialesSeguras implements Credenciales {
  static const _clave = 'brota_servidor_password';
  static const _llavero = FlutterSecureStorage();

  @override
  Future<String?> leer() async {
    try {
      return await _llavero.read(key: _clave);
    } catch (_) {
      return null; // llavero no disponible: se pedirá la contraseña
    }
  }

  @override
  Future<void> guardar(String password) async {
    try {
      await _llavero.write(key: _clave, value: password);
    } catch (_) {
      // Sin llavero la app sigue funcionando; solo no podrá reconectarse sola.
    }
  }

  @override
  Future<void> borrar() async {
    try {
      await _llavero.delete(key: _clave);
    } catch (_) {}
  }
}

/// En memoria, para pruebas.
class CredencialesMemoria implements Credenciales {
  String? password;

  @override
  Future<String?> leer() async => password;

  @override
  Future<void> guardar(String p) async => password = p;

  @override
  Future<void> borrar() async => password = null;
}
