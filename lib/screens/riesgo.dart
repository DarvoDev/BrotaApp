import 'package:flutter/material.dart';

import '../logic/perceptron.dart';
import '../main.dart';
import '../state/brota_state.dart';
import '../theme.dart';

/// CU-20 Predecir riesgo y simplificar misiones: explica, con los números
/// reales, cómo decide el perceptrón. Transparencia para el usuario y para
/// la revisión del proyecto.
class RiesgoScreen extends StatelessWidget {
  const RiesgoScreen({super.key});

  Future<void> _reiniciar(BuildContext context) async {
    final estado = BrotaScope.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Volver a los pesos iniciales?'),
        content: const Text(
          'El modelo olvida lo que aprendió de tu ritmo. Tu progreso, racha y '
          'mascota no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (si == true) await estado.reiniciarModelo();
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final p = estado.perceptron;
    final hoy = estado.prediccionHoy;
    final manana = estado.pronosticoManana;

    Widget fila(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(a, style: const TextStyle(fontSize: 13.5))),
          Text(
            b,
            style: const TextStyle(
              fontSize: 13.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Cómo decide Brota')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const Text(
              'Perceptrón de riesgo',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Una neurona artificial muy simple que aprende tu ritmo en este '
              'dispositivo. Predice si mañana el riesgo de no cumplir la rutina '
              'es ALTO o BAJO; si es ALTO, las misiones del día siguiente se '
              'vuelven más ligeras.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              color: e.primaryContainer,
              child: Text(
                'Límite ético: no diagnostica depresión ni ninguna condición de '
                'salud mental. Solo adapta la dificultad dentro de la app.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const TituloSeccion('Predicciones'),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fila(
                    'Hoy',
                    hoy == null
                        ? 'Aún aprendiendo tu ritmo'
                        : '${hoy.texto} (z = ${hoy.puntaje.toStringAsFixed(2)})',
                  ),
                  fila(
                    'Mañana (en vivo)',
                    manana == null
                        ? 'Aún aprendiendo tu ritmo'
                        : '${manana.texto} (z = ${manana.puntaje.toStringAsFixed(2)})',
                  ),
                  fila('Días aprendidos', '${p.ejemplos}'),
                  const SizedBox(height: 6),
                  Text(
                    'Necesita ${BrotaState.diasMinimosRiesgo} días de uso antes de predecir. '
                    'El pronóstico de mañana cambia al completar actividades o '
                    'registrar tu ánimo.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Entradas, pesos y sesgo'),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Entrada',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          'x',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: e.onSurfaceVariant,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'peso',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: e.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  for (
                    var i = 0;
                    i < PerceptronRiesgo.nombresEntradas.length;
                    i++
                  )
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              PerceptronRiesgo.nombresEntradas[i],
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              manana == null
                                  ? '—'
                                  : manana.entradas[i].toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              p.pesos[i].toStringAsFixed(2),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: p.pesos[i] < 0 ? e.primary : e.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  fila('Sesgo b', p.sesgo.toStringAsFixed(2)),
                  const SizedBox(height: 8),
                  Text(
                    'z = w·x + b. Si z > 0 → ALTO. Peso negativo (verde) baja el '
                    'riesgo; positivo (rojo) lo sube. Al cerrar cada día el '
                    'modelo compara su predicción con lo que pasó y, si falló, '
                    'ajusta: w ← w + 0.1·(real − predicho)·x.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _reiniciar(context),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Volver a los pesos iniciales'),
            ),
          ],
        ),
      ),
    );
  }
}
