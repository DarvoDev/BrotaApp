/// Clasificador de frases por diccionario de palabras clave.
///
/// Decide si una frase es motivadora, neutra, no apta o de riesgo, y si su
/// estilo es implícito (describe el proceso, no ordena ni evalúa a la
/// persona) o explícito («¡Tú puedes!»). Lo usan:
/// - el Administrador al validar mensajes (CU-19): solo entran motivadoras;
/// - los mensajes del día (CU-12): se prefieren los de estilo implícito;
/// - la comunidad (CU-14): las frases predefinidas ya pasaron el filtro.
///
/// Algoritmo (idéntico en el backend):
/// 1. Normalizar: minúsculas, sin acentos, todo lo que no sea letra o número
///    se vuelve espacio.
/// 2. Buscar los términos de más a menos palabras. Cada palabra del texto
///    solo puede usarse una vez, así «no tienes que» no cuenta también como
///    «tienes que». Un término con * coincide con el inicio de una palabra.
/// 3. riesgo → 'riesgo'; ofensiva → 'no_apta'; si no, se suman los pesos:
///    ≥ 2 → 'motivadora', ≤ −1 → 'no_apta', en otro caso → 'neutra'.
library;

part 'diccionario.g.dart';

enum CategoriaFrase { motivadora, neutra, noApta, riesgo }

extension TextoCategoriaFrase on CategoriaFrase {
  String get texto => switch (this) {
    CategoriaFrase.motivadora => 'Motivadora',
    CategoriaFrase.neutra => 'Neutra',
    CategoriaFrase.noApta => 'No apta',
    CategoriaFrase.riesgo => 'Riesgo',
  };
}

class Coincidencia {
  const Coincidencia(this.termino, this.categoria, this.peso);

  final String termino;
  final String categoria;
  final int peso;
}

class Clasificacion {
  const Clasificacion({
    required this.categoria,
    required this.implicita,
    required this.puntaje,
    required this.coincidencias,
  });

  final CategoriaFrase categoria;

  /// true si no contiene exhortaciones explícitas («tú puedes», «ánimo»…).
  final bool implicita;
  final int puntaje;
  final List<Coincidencia> coincidencias;

  bool get esMotivadora => categoria == CategoriaFrase.motivadora;
  String get estilo => implicita ? 'implícito' : 'explícito';
}

class _Categoria {
  const _Categoria(this.nombre, this.peso, this.terminos);

  final String nombre;
  final int peso;
  final List<String> terminos;
}

class _Termino {
  _Termino(this.texto, this.categoria, this.peso) : palabras = texto.split(' ');

  final String texto;
  final String categoria;
  final int peso;
  final List<String> palabras;

  bool coincideEn(List<String> w, int i) {
    for (var k = 0; k < palabras.length; k++) {
      final p = palabras[k];
      final ok = p.endsWith('*')
          ? w[i + k].startsWith(p.substring(0, p.length - 1))
          : w[i + k] == p;
      if (!ok) return false;
    }
    return true;
  }
}

class ClasificadorFrases {
  ClasificadorFrases._();

  static final List<_Termino> _terminos = () {
    final lista = <_Termino>[
      for (final c in _categorias)
        for (final t in c.terminos) _Termino(t, c.nombre, c.peso),
    ];
    // sort estable: a igual número de palabras se respeta el orden del archivo.
    final indexados = lista.asMap().entries.toList()
      ..sort((a, b) {
        final d = b.value.palabras.length - a.value.palabras.length;
        return d != 0 ? d : a.key - b.key;
      });
    return [for (final e in indexados) e.value];
  }();

  static const Map<String, String> _sinAcento = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  static List<String> normalizar(String texto) {
    final b = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      final c = _sinAcento[ch] ?? ch;
      final u = c.codeUnitAt(0);
      final valido = (u >= 97 && u <= 122) || (u >= 48 && u <= 57);
      b.write(valido && c.length == 1 ? c : ' ');
    }
    return b.toString().split(' ').where((p) => p.isNotEmpty).toList();
  }

  static Clasificacion clasificar(String texto) {
    final w = normalizar(texto);
    final usada = List<bool>.filled(w.length, false);
    final hallados = <Coincidencia>[];
    for (final t in _terminos) {
      final n = t.palabras.length;
      for (var i = 0; i + n <= w.length; i++) {
        var libre = true;
        for (var k = 0; k < n; k++) {
          if (usada[i + k]) libre = false;
        }
        if (!libre || !t.coincideEn(w, i)) continue;
        for (var k = 0; k < n; k++) {
          usada[i + k] = true;
        }
        hallados.add(Coincidencia(t.texto, t.categoria, t.peso));
        break;
      }
    }
    final cats = {for (final h in hallados) h.categoria};
    final puntaje = hallados.fold(0, (s, h) => s + h.peso);
    final CategoriaFrase categoria;
    if (cats.contains('riesgo')) {
      categoria = CategoriaFrase.riesgo;
    } else if (cats.contains('ofensiva')) {
      categoria = CategoriaFrase.noApta;
    } else if (puntaje >= _motivadoraMinimo) {
      categoria = CategoriaFrase.motivadora;
    } else if (puntaje <= _noAptaMaximo) {
      categoria = CategoriaFrase.noApta;
    } else {
      categoria = CategoriaFrase.neutra;
    }
    return Clasificacion(
      categoria: categoria,
      implicita: !cats.contains('exhortacion_explicita'),
      puntaje: puntaje,
      coincidencias: hallados,
    );
  }
}
