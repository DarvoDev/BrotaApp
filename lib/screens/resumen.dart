import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-16: resumen semanal navegable, con lenguaje sin juicio.
class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  late DateTime _inicio = lunesDe(BrotaScope.of(context).hoy);

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final resumen = estado.resumenSemanal(inicio: _inicio);
    final inicio = diaDeClave(resumen['inicio'] as String);
    final fin = diaDeClave(resumen['fin'] as String);
    final dias = (resumen['dias'] as List).cast<Map<String, dynamic>>();
    final activos = resumen['activos'] as int;
    final descansos = resumen['descansos'] as int;
    final xp = resumen['xp'] as int;
    final animo = (resumen['animoPromedio'] as num).toDouble();
    final lunesActual = lunesDe(estado.hoy);
    final puedeAvanzar = !sumarDias(_inicio, 7).isAfter(lunesActual);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen semanal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            const Text(
              'Tu semana',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Mira lo que hiciste, sin exigencias.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        setState(() => _inicio = sumarDias(_inicio, -7)),
                    tooltip: 'Semana anterior',
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Del ${fechaCorta(inicio)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'al ${fechaCorta(fin)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: e.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: puedeAvanzar
                        ? () => setState(() => _inicio = sumarDias(_inicio, 7))
                        : null,
                    tooltip: 'Semana siguiente',
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Día a día'),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < dias.length; i++)
                        Expanded(
                          child: _Dia(
                            letra: 'LMXJVSD'[i],
                            numero: diaDeClave(dias[i]['dia'] as String).day,
                            simbolo: dias[i]['actividad'] as bool
                                ? '✓'
                                : (dias[i]['descanso'] as bool ? '🌙' : '·'),
                            esHoy:
                                diaDeClave(dias[i]['dia'] as String) ==
                                estado.hoy,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '✓ actividad   🌙 descanso   · pendiente',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            const TituloSeccion('En números'),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    icono: '⚡',
                    valor: '$xp Exp',
                    detalle: 'ganados esta semana',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    icono: '✅',
                    valor: '$activos de 7',
                    detalle: 'días con actividad',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    icono: '🌙',
                    valor: '$descansos',
                    detalle: 'días de descanso',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    icono: '💛',
                    valor: animo.toStringAsFixed(1),
                    detalle: 'ánimo promedio de 5',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Días con actividad: $activos de 7',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  BarraProgreso(activos / 7),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              color: e.primaryContainer,
              child: const Text(
                'Descansar también cuenta 🌙',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.letra,
    required this.numero,
    required this.simbolo,
    required this.esHoy,
  });

  final String letra;
  final int numero;
  final String simbolo;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          letra,
          style: TextStyle(
            fontSize: 12,
            fontWeight: esHoy ? FontWeight.w800 : FontWeight.w400,
            color: e.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: esHoy ? e.primaryContainer : Colors.transparent,
            border: Border.all(
              color: esHoy ? e.primary : e.outlineVariant,
              width: esHoy ? 2 : 1,
            ),
          ),
          child: Text(
            simbolo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$numero',
          style: TextStyle(fontSize: 11, color: e.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.valor,
    required this.detalle,
  });

  final String icono;
  final String valor;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Tarjeta(
      child: Row(
        children: [
          Text(icono, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detalle,
                  style: TextStyle(color: e.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
