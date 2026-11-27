/// Perceptrón predictor de riesgo de procrastinación (elemento innovador).
///
/// Una sola neurona lineal: z = w·x + b. Si z > 0 el riesgo de no cumplir la
/// rutina mañana es ALTO; si no, BAJO. Aprende en el propio dispositivo con la
/// regla del perceptrón cada vez que se cierra un día y ya se sabe si hubo
/// actividad. Dart puro: sin librerías, sin internet.
///
/// Límite ético: no diagnostica depresión ni ninguna condición de salud
/// mental. Solo predice un patrón de conducta de corto plazo para adaptar la
/// dificultad de las misiones dentro de la app.
///
/// El mismo modelo (entradas, pesos iniciales y regla) está en el backend
/// (`app/perceptron.py` en Backend-Brota) para que ambos den el mismo resultado.
class PerceptronRiesgo {
  PerceptronRiesgo({List<double>? pesos, double? sesgo, this.ejemplos = 0})
    : pesos = List.of(pesos ?? pesosIniciales),
      sesgo = sesgo ?? sesgoInicial;

  /// Nombres legibles de las 8 entradas, en el orden del vector x.
  static const List<String> nombresEntradas = [
    'Constancia de los últimos 7 días',
    'Hora promedio de cumplimiento',
    'Escudos usados esta semana',
    'Mañana es fin de semana',
    'Interacciones con el compañero fantasma',
    'Último ánimo registrado',
    'Última energía registrada',
    'Hubo actividad hoy',
  ];

  /// Pesos de arranque en frío (propuesta del equipo, por confirmar): más
  /// constancia, ánimo, energía, compañía y actividad hoy bajan el riesgo;
  /// cumplir tarde, gastar escudos y el fin de semana lo suben.
  static const List<double> pesosIniciales = [
    -1.2,
    0.4,
    0.6,
    0.3,
    -0.4,
    -0.8,
    -0.6,
    -1.0,
  ];
  static const double sesgoInicial = 1.4;

  /// Tasa de aprendizaje η.
  static const double tasa = 0.1;

  final List<double> pesos;
  double sesgo;

  /// Días con los que ya aprendió (solo informativo).
  int ejemplos;

  double puntaje(List<double> x) {
    assert(x.length == pesos.length);
    var z = sesgo;
    for (var i = 0; i < x.length; i++) {
      z += pesos[i] * x[i];
    }
    return z;
  }

  /// true = riesgo ALTO.
  bool predecir(List<double> x) => puntaje(x) > 0;

  /// Regla del perceptrón: w ← w + η(y − ŷ)x ; b ← b + η(y − ŷ).
  /// `huboRiesgo` es la respuesta real: true si NO hubo actividad ese día.
  /// Devuelve true si el modelo se equivocó (y por tanto ajustó sus pesos).
  bool aprender(List<double> x, {required bool huboRiesgo}) {
    final y = huboRiesgo ? 1 : 0;
    final yHat = predecir(x) ? 1 : 0;
    final error = y - yHat;
    ejemplos++;
    if (error == 0) return false;
    for (var i = 0; i < pesos.length; i++) {
      pesos[i] += tasa * error * x[i];
    }
    sesgo += tasa * error;
    return true;
  }

  void reiniciar() {
    pesos
      ..clear()
      ..addAll(pesosIniciales);
    sesgo = sesgoInicial;
    ejemplos = 0;
  }

  Map<String, dynamic> toJson() => {
    'pesos': pesos,
    'sesgo': sesgo,
    'ejemplos': ejemplos,
  };

  factory PerceptronRiesgo.fromJson(Map<String, dynamic> j) => PerceptronRiesgo(
    pesos: ((j['pesos'] as List?) ?? pesosIniciales)
        .map((v) => (v as num).toDouble())
        .toList(),
    sesgo: (j['sesgo'] as num?)?.toDouble(),
    ejemplos: j['ejemplos'] as int? ?? 0,
  );
}

/// Datos de comportamiento con los que se arma el vector de entradas.
/// Se separa del estado para poder probar el cálculo sin la app.
class DatosRiesgo {
  const DatosRiesgo({
    required this.diasActivos7,
    required this.horasCumplimiento7,
    required this.escudosSemana,
    required this.mananaEsFinDeSemana,
    required this.interaccionesFantasma7,
    required this.ultimoAnimo,
    required this.ultimaEnergia,
    required this.activoHoy,
  });

  /// Días con al menos un cumplimiento en los 7 días que terminan hoy (0–7).
  final int diasActivos7;

  /// Hora (0–23) de cada cumplimiento de esos 7 días.
  final List<int> horasCumplimiento7;
  final int escudosSemana;
  final bool mananaEsFinDeSemana;
  final int interaccionesFantasma7;

  /// 1–5, o null si no hay registro.
  final int? ultimoAnimo;

  /// 1–3, o null si no hay registro.
  final int? ultimaEnergia;
  final bool activoHoy;

  /// Vector x con todas las entradas normalizadas entre 0 y 1.
  List<double> get entradas {
    final hora = horasCumplimiento7.isEmpty
        ? 0.5
        : horasCumplimiento7.reduce((a, b) => a + b) /
              horasCumplimiento7.length /
              23;
    return [
      (diasActivos7 / 7).clamp(0, 1).toDouble(),
      hora.clamp(0, 1).toDouble(),
      escudosSemana >= 1 ? 1.0 : 0.0,
      mananaEsFinDeSemana ? 1.0 : 0.0,
      (interaccionesFantasma7 / 7).clamp(0, 1).toDouble(),
      ultimoAnimo == null ? 0.5 : (ultimoAnimo! - 1) / 4,
      ultimaEnergia == null ? 0.5 : (ultimaEnergia! - 1) / 2,
      activoHoy ? 1.0 : 0.0,
    ];
  }
}

/// Predicción guardada para un día concreto.
class PrediccionRiesgo {
  const PrediccionRiesgo({
    required this.dia,
    required this.alto,
    required this.puntaje,
    required this.entradas,
  });

  /// Día para el que se predice (aaaa-mm-dd).
  final String dia;
  final bool alto;
  final double puntaje;
  final List<double> entradas;

  String get texto => alto ? 'ALTO' : 'BAJO';

  Map<String, dynamic> toJson() => {
    'dia': dia,
    'alto': alto,
    'puntaje': puntaje,
    'entradas': entradas,
  };

  factory PrediccionRiesgo.fromJson(Map<String, dynamic> j) => PrediccionRiesgo(
    dia: j['dia'] as String,
    alto: j['alto'] as bool,
    puntaje: (j['puntaje'] as num).toDouble(),
    entradas: ((j['entradas'] as List?) ?? [])
        .map((v) => (v as num).toDouble())
        .toList(),
  );
}
