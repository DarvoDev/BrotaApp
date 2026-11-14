import 'package:flutter/material.dart';

import '../data/catalogo.dart';
import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// Pantalla Rachas del prototipo: muestra el resultado de CU-10.
/// Los ❤️ del HTML pasan a ser 🛡️ escudos = congelamientos de la Fase 2.
class RachasScreen extends StatelessWidget {
  const RachasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final hoy = estado.hoy;
    final lunes = lunesDe(hoy);
    final semana = [for (var i = 0; i < 7; i++) sumarDias(lunes, i)];
    final activos = semana.where(estado.huboActividad).length;
    final escudos = estado.racha.congelamientos;
    final renueva = estado.proximaRenovacion;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Rachas', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
            ),
            Text(fechaCorta(hoy), style: TextStyle(color: e.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 12),
        Tarjeta(
          color: e.primaryContainer,
          child: Text(
            frasesMotivacionales[hoy.day % frasesMotivacionales.length],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 54, height: 1.1)),
            Text(
              '${estado.racha.dias}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.1),
            ),
            Text(estado.racha.dias == 1 ? 'día de racha' : 'días de racha'),
          ],
        ),
        const SizedBox(height: 20),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tus escudos', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < congelamientosPorSemana; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Opacity(
                        opacity: i < escudos ? 1 : 0.25,
                        child: const Text('🛡️', style: TextStyle(fontSize: 30)),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$escudos de $congelamientosPorSemana disponibles',
                      style: TextStyle(color: e.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Si un día no puedes con nada, un escudo cuida tu racha por ti. '
                'Vuelves a tener $congelamientosPorSemana el lunes ${renueva.day}/${renueva.month}. '
                'Y pase lo que pase, tu nivel y tu Exp no bajan.',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tu semana', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _Dia(
                      letra: 'LMXJVSD'[i],
                      activo: estado.huboActividad(semana[i]),
                      descanso: estado.fueDescanso(semana[i]),
                      esHoy: semana[i] == hoy,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                activos == 0
                    ? 'La semana apenas empieza. Una sola misión ya cuenta.'
                    : activos == 1
                    ? 'Te moviste 1 día esta semana. Eso ya es avanzar.'
                    : 'Te moviste $activos días esta semana.',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                '✓ día con actividad   🌙 día de descanso',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.letra,
    required this.activo,
    required this.descanso,
    required this.esHoy,
  });

  final String letra;
  final bool activo;
  final bool descanso;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          letra,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: esHoy ? FontWeight.w800 : FontWeight.w400,
            color: esHoy ? e.onSurface : e.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo ? e.primary : Colors.transparent,
            border: Border.all(
              color: activo || esHoy ? e.primary : e.outlineVariant,
              width: 2,
            ),
          ),
          child: activo
              ? Icon(Icons.check, size: 20, color: e.onPrimary)
              : descanso
              ? const Text('🌙', style: TextStyle(fontSize: 16))
              : null,
        ),
      ],
    );
  }
}
