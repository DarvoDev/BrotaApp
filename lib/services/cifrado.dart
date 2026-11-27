import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cifrado local ligero de los datos sensibles (RNF-02).
///
/// Construye un cifrado de flujo con HMAC-SHA256: la clave se deriva con
/// SHA-256, cada bloque de la secuencia sale de HMAC(clave, nonce|contador) y
/// se usa XOR sobre los bytes del texto. El resultado lleva el nonce y un HMAC
/// de integridad, codificados en base64.
///
/// Es una protección de almacenamiento en el dispositivo, no un sustituto de
/// un llavero del sistema; la clave vive en la app porque Brota no tiene
/// servidor. Aun así evita que el ánimo y el uso del S.O.S. se lean como texto.
class CifradoLocal {
  CifradoLocal._();

  static List<int> _clave(String secreto) =>
      sha256.convert(utf8.encode(secreto)).bytes;

  static Uint8List _secuencia(List<int> clave, List<int> nonce, int longitud) {
    final salida = BytesBuilder();
    final hmac = Hmac(sha256, clave);
    var bloque = 0;
    while (salida.length < longitud) {
      final contador = Uint8List(4)
        ..buffer.asByteData().setUint32(0, bloque, Endian.big);
      salida.add(hmac.convert([...nonce, ...contador]).bytes);
      bloque++;
    }
    return salida.takeBytes();
  }

  static String cifrar(String texto, {required String clave}) {
    final nonce = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    final llave = _clave(clave);
    final datos = utf8.encode(texto);
    final flujo = _secuencia(llave, nonce, datos.length);
    final cifrado = Uint8List.fromList([
      for (var i = 0; i < datos.length; i++) datos[i] ^ flujo[i],
    ]);
    final etiqueta = Hmac(sha256, llave).convert([...nonce, ...cifrado]).bytes;
    return base64.encode([...nonce, ...etiqueta, ...cifrado]);
  }

  static String descifrar(String texto, {required String clave}) {
    final bytes = base64.decode(texto);
    if (bytes.length < 44) throw const FormatException('Cifrado inválido');
    final nonce = bytes.sublist(0, 12);
    final etiqueta = bytes.sublist(12, 44);
    final cifrado = bytes.sublist(44);
    final llave = _clave(clave);
    final esperada = Hmac(sha256, llave).convert([...nonce, ...cifrado]).bytes;
    for (var i = 0; i < etiqueta.length; i++) {
      if (etiqueta[i] != esperada[i]) {
        throw const FormatException('No se pudo descifrar');
      }
    }
    final flujo = _secuencia(llave, nonce, cifrado.length);
    final plano = Uint8List.fromList([
      for (var i = 0; i < cifrado.length; i++) cifrado[i] ^ flujo[i],
    ]);
    return utf8.decode(plano);
  }
}
