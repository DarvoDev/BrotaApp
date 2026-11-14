import 'package:shared_preferences/shared_preferences.dart';

/// Guardado local del estado de la app (offline primero, RNF-03 / RNF-07).
abstract class Almacen {
  Future<String?> leer();
  Future<void> guardar(String datos);
}

class AlmacenPrefs implements Almacen {
  static const _clave = 'brota_v1';

  @override
  Future<String?> leer() async =>
      (await SharedPreferences.getInstance()).getString(_clave);

  @override
  Future<void> guardar(String datos) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _clave,
      datos,
    );
    if (!ok) throw Exception('No se pudo guardar');
  }
}

/// En memoria, para pruebas.
class AlmacenMemoria implements Almacen {
  String? datos;

  @override
  Future<String?> leer() async => datos;

  @override
  Future<void> guardar(String d) async => datos = d;
}
