import 'dart:math';

import 'package:flutter/material.dart';

import '../data/catalogo.dart';
import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// Jardín: aquí se ven crecer Brotito (nivel del avatar) y la mascota (su
/// propio nivel), con las decoraciones compradas en la tienda. La mascota
/// cambia de ánimo según la actividad reciente, pero nunca muere ni pierde
/// nivel.
class JardinScreen extends StatefulWidget {
  const JardinScreen({super.key});

  @override
  State<JardinScreen> createState() => _JardinScreenState();
}

class _JardinScreenState extends State<JardinScreen> {
  String? _texto;

  Future<void> _comprar(Decoracion d) async {
    final estado = BrotaScope.of(context);
    final error = await estado.comprarDecoracion(d.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? '${d.emoji} ${d.nombre} ya está en tu jardín'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final oscuro = e.brightness == Brightness.dark;
    final dormida = estado.estadoMascota != EstadoMascota.feliz;
    final cielo = dormida
        ? (oscuro ? const Color(0xFF26364A) : const Color(0xFFB9C9DD))
        : (oscuro ? const Color(0xFF2C4455) : const Color(0xFFCFE8F5));
    final pasto = oscuro ? const Color(0xFF3D5A36) : const Color(0xFFB9DCA6);
    final faltan = xpPorNivel - estado.xpEnNivel;
    final faltanMascota = xpPorNivelMascota - estado.xpEnNivelMascota;
    final decoraciones = [
      for (final id in estado.decoracionesCompradas)
        if (decoracionPorId(id) != null) decoracionPorId(id)!,
    ];
    final frase = _texto ?? estado.fraseMascota;

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
                height: 150,
                color: cielo,
                child: Stack(
                  children: [
                    const Positioned(left: 28, top: 20, child: Text('☁️', style: TextStyle(fontSize: 46))),
                    const Positioned(left: 190, top: 64, child: Text('☁️', style: TextStyle(fontSize: 40))),
                    Positioned(
                      right: 14,
                      top: 10,
                      child: Text(dormida ? '🌙' : '☀️', style: const TextStyle(fontSize: 44)),
                    ),
                  ],
                ),
              ),
              Container(
                height: 190,
                color: pasto,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(emojiBrotito(estado.nivel), style: const TextStyle(fontSize: 80)),
                        Semantics(
                          button: true,
                          label: 'Acariciar a tu mascota',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              final lista = frasesMascota[estado.estadoMascota]!;
                              setState(() => _texto = lista[Random().nextInt(lista.length)]);
                            },
                            child: Container(
                              width: 88,
                              height: 88,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.4),
                                border: Border.all(color: e.onSurface, width: 2),
                              ),
                              child: Text(
                                emojiMascota(estado.mascota, estado.estadoMascota),
                                style: const TextStyle(fontSize: 34),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (decoraciones.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final d in decoraciones)
                              Text(d.emoji, style: const TextStyle(fontSize: 26)),
                          ],
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
          '${estado.mascotaNombre}: $frase',
          textAlign: TextAlign.center,
          style: TextStyle(color: e.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brotito (tu avatar) · Nivel ${estado.nivel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              BarraProgreso(estado.xpEnNivel / xpPorNivel),
              const SizedBox(height: 6),
              Text(
                'Faltan $faltan Exp para el nivel ${estado.nivel + 1}.',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Text(
                '${estado.mascotaNombre} (tu mascota) · Nivel ${estado.nivelMascota}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              BarraProgreso(estado.xpEnNivelMascota / xpPorNivelMascota),
              const SizedBox(height: 6),
              Text(
                'Faltan $faltanMascota Exp para el nivel ${estado.nivelMascota + 1}. '
                'Llevas ${estado.xpTotal} Exp en total, y esa nunca se pierde.',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
        TituloSeccion(
          'Tienda del jardín',
          accion: Text(
            '🌰 ${estado.semillas} semillas',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          'Cada Exp que ganas también te da una semilla. Comprar no baja tu '
          'nivel, y todo se consigue jugando: aquí no hay pagos.',
          style: TextStyle(color: e.onSurfaceVariant, fontSize: 13.5),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            for (final d in decoracionesTienda)
              _ArticuloTienda(
                decoracion: d,
                comprada: estado.tieneDecoracion(d.id),
                alcanza: estado.semillas >= d.precio,
                alComprar: () => _comprar(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _ArticuloTienda extends StatelessWidget {
  const _ArticuloTienda({
    required this.decoracion,
    required this.comprada,
    required this.alcanza,
    required this.alComprar,
  });

  final Decoracion decoracion;
  final bool comprada;
  final bool alcanza;
  final VoidCallback alComprar;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Tarjeta(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(decoracion.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  decoracion.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: comprada
                ? Text('✓ En tu jardín', style: TextStyle(color: e.primary, fontWeight: FontWeight.w600))
                : FilledButton.tonal(
                    onPressed: alComprar,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      foregroundColor: alcanza ? null : e.onSurfaceVariant,
                    ),
                    child: Text('🌰 ${decoracion.precio}'),
                  ),
          ),
        ],
      ),
    );
  }
}
