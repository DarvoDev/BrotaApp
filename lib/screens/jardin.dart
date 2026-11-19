import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// Jardín del prototipo HTML: aquí se ve crecer a Brotito y a la mascota
/// con la XP ganada (CU-09b). La tienda y las monedas del prototipo no
/// corresponden a ningún RF y quedan fuera.
class JardinScreen extends StatefulWidget {
  const JardinScreen({super.key});

  @override
  State<JardinScreen> createState() => _JardinScreenState();
}

class _JardinScreenState extends State<JardinScreen> {
  static const _frases = [
    '¡Guau! Te quiere mucho 🐾',
    'Está feliz de verte 🥰',
    'Quiere jugar contigo ⚽',
  ];
  String _texto = 'Toca a tu mascota para darle cariño';

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final oscuro = e.brightness == Brightness.dark;
    final cielo = oscuro ? const Color(0xFF2C4455) : const Color(0xFFCFE8F5);
    final pasto = oscuro ? const Color(0xFF3D5A36) : const Color(0xFFB9DCA6);
    final faltan = xpPorNivel - estado.xpEnNivel;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
      children: [
        const Text('Tu jardín', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          'Crece contigo, a tu ritmo. Aquí nada se marchita.',
          style: TextStyle(color: e.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Container(
                height: 170,
                color: cielo,
                child: const Stack(
                  children: [
                    Positioned(left: 28, top: 20, child: Text('☁️', style: TextStyle(fontSize: 46))),
                    Positioned(left: 190, top: 70, child: Text('☁️', style: TextStyle(fontSize: 40))),
                    Positioned(right: 14, top: 10, child: Text('☀️', style: TextStyle(fontSize: 44))),
                  ],
                ),
              ),
              Container(
                height: 170,
                color: pasto,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(emojiBrotito(estado.nivel), style: const TextStyle(fontSize: 84)),
                    Semantics(
                      button: true,
                      label: 'Acariciar a tu mascota',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(
                          () => _texto = _frases[Random().nextInt(_frases.length)],
                        ),
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.4),
                            border: Border.all(color: e.onSurface, width: 2),
                          ),
                          child: Text(estado.mascota, style: const TextStyle(fontSize: 40)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${estado.mascotaNombre} dice: $_texto',
          textAlign: TextAlign.center,
          style: TextStyle(color: e.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brotito y tu mascota · Nivel ${estado.nivel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              BarraProgreso(estado.xpEnNivel / xpPorNivel),
              const SizedBox(height: 6),
              Text(
                'Faltan $faltan Exp para el nivel ${estado.nivel + 1}. '
                'Llevas ${estado.xpTotal} Exp en total, y esa nunca se pierde.',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
