import 'dart:typed_data';

/// Genera un PDF válido sin dependencias externas (CU-17, RNF-06 ≤ 2 MB).
///
/// Usa Helvetica (fuente base de PDF), codificación WinAnsi para caracteres
/// españoles y una tabla xref con desplazamientos reales. Emojis se omiten
/// porque no pertenecen a WinAnsi.
class PdfHistorial {
  PdfHistorial._();

  static const int _maxLineas = 1800;

  static List<int> _winAnsi(String s) => [
    for (final c in s.runes)
      c <= 255 ? c : 0x3F, // '?' para lo que no esté en WinAnsi
  ];

  static Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);

  static String _escapar(String s) =>
      s.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  /// Devuelve los bytes del PDF. [lineas] son párrafos ya redactados.
  static Future<Uint8List> generar(
    String titulo,
    List<String> lineas, {
    String subtitulo = '',
  }) async {
    final cuerpo = <String>[
      'BT',
      '/F1 17 Tf',
      '14 TL',
      '48 790 Td',
      '(${_escapar(titulo)}) Tj',
      'T*',
    ];
    if (subtitulo.isNotEmpty) {
      cuerpo
        ..add('/F1 10 Tf')
        ..add('(${_escapar(subtitulo)}) Tj')
        ..add('T*')
        ..add('/F1 11 Tf');
    } else {
      cuerpo.add('/F1 11 Tf');
    }
    for (final linea in lineas.take(_maxLineas)) {
      if (linea.isEmpty) {
        cuerpo.add('T*');
        continue;
      }
      cuerpo.add('(${_escapar(linea)}) Tj');
      cuerpo.add('T*');
    }
    cuerpo.add('ET');

    final contenido = (BytesBuilder()..add(_ascii(cuerpo.join('\n'))))
        .takeBytes();

    final objetos = <List<int>>[
      _ascii('<< /Type /Catalog /Pages 2 0 R >>'),
      _ascii('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      _ascii(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      ),
      _ascii(
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding >>',
      ),
      (BytesBuilder()
            ..add(_ascii('<< /Length ${contenido.length} >>\nstream\n'))
            ..add(contenido)
            ..add(_ascii('\nendstream')))
          .takeBytes(),
    ];

    final pdf = BytesBuilder()..add(_ascii('%PDF-1.4\n'));
    final desplazamientos = <int>[0];
    for (var i = 0; i < objetos.length; i++) {
      desplazamientos.add(pdf.length);
      pdf
        ..add(_ascii('${i + 1} 0 obj\n'))
        ..add(objetos[i])
        ..add(_ascii('\nendobj\n'));
    }
    final xref = pdf.length;
    final bufXref = StringBuffer('xref\n0 ${objetos.length + 1}\n');
    bufXref.writeln('0000000000 65535 f ');
    for (final d in desplazamientos.skip(1)) {
      bufXref.writeln('${d.toString().padLeft(10, '0')} 00000 n ');
    }
    bufXref.writeln(
      'trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF',
    );
    pdf.add(_ascii(bufXref.toString()));
    final bytes = pdf.takeBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('El PDF supera el límite de 2 MB');
    }
    return bytes;
  }

  /// Convierte el texto a bytes WinAnsi, útil para probar la codificación.
  static List<int> codificar(String s) => _winAnsi(s);
}
