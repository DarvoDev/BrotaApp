import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../state/brota_state.dart';
import '../theme.dart';

/// CU-15: panel de progreso y CU-17: exportación del historial en PDF.
class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  bool _exportando = false;

  Future<void> _exportar(BrotaState estado) async {
    setState(() => _exportando = true);
    try {
      final bytes = await estado.exportarPdf();
      if (!mounted) return;
      final kb = (bytes.length / 1024).round();
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Tu historial'),
          content: Text('Historial listo ($kb KB)'),
          actions: [
            TextButton.icon(
              onPressed: () => _compartir(c, bytes),
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: estado.logroCompartible));
                Navigator.pop(c);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Resumen copiado al portapapeles'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar resumen'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pude exportar el historial: $error')),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _compartir(BuildContext dialogContext, Uint8List bytes) async {
    Navigator.pop(dialogContext);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: 'brota_historial.pdf',
              mimeType: 'application/pdf',
            ),
          ],
          fileNameOverrides: const ['brota_historial.pdf'],
          subject: 'Mi progreso en Brota',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el PDF: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de progreso')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tu camino, sin prisa',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  fechaCorta(estado.hoy),
                  style: TextStyle(color: e.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              estado.mensajeDelDia,
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nivel ${estado.nivel}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${estado.xpTotal} Exp total',
                        style: TextStyle(
                          color: e.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BarraProgreso(estado.xpEnNivel / xpPorNivel),
                  const SizedBox(height: 6),
                  Text(
                    '${estado.xpEnNivel} de $xpPorNivel Exp para el siguiente nivel',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Tu constancia'),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    icono: '🔥',
                    valor: '${estado.racha.dias}',
                    detalle: estado.racha.dias == 1
                        ? 'día de racha'
                        : 'días de racha',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    icono: '🏆',
                    valor: '${estado.rachaMaxima}',
                    detalle: 'mejor racha',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    icono: '✅',
                    valor: '${estado.diasActivos}',
                    detalle: 'días con actividad',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    icono: '📈',
                    valor:
                        '${estado.porcentajeCumplimiento.toStringAsFixed(0)}%',
                    detalle: 'de cumplimiento',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    icono: '💛',
                    valor: estado.animoPromedio.toStringAsFixed(1),
                    detalle: 'ánimo promedio de 5',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    icono: '🛡️',
                    valor: '${estado.racha.congelamientos}',
                    detalle: 'escudos disponibles',
                  ),
                ),
              ],
            ),
            const TituloSeccion('Exp de los últimos 7 días'),
            Tarjeta(
              child: _GraficoXP(
                valores: estado.xpDeLosUltimos(7),
                hoy: estado.hoy,
              ),
            ),
            const TituloSeccion('Tu historial'),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Puedes guardar tu recorrido en un PDF y compartirlo '
                    'sin exponer tus datos personales.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _exportando ? null : () => _exportar(estado),
                    icon: _exportando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _exportando
                          ? 'Preparando historial…'
                          : 'Exportar historial PDF',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Cada día cuenta, incluso los que fueron más suaves.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
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

class _GraficoXP extends StatelessWidget {
  const _GraficoXP({required this.valores, required this.hoy});

  final List<int> valores;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    final mayor = valores.fold<int>(0, (m, v) => v > m ? v : m);
    final tope = mayor == 0 ? 1 : mayor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < valores.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 90,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Tooltip(
                      message: '${valores[i]} Exp',
                      child: Container(
                        width: 24,
                        height: 6 + (valores[i] * 78 / tope),
                        decoration: BoxDecoration(
                          color: valores[i] > 0 ? e.primary : e.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'LMXJVSD'[sumarDias(hoy, i - (valores.length - 1)).weekday -
                      1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == valores.length - 1
                        ? FontWeight.w800
                        : FontWeight.w400,
                    color: e.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${valores[i]}',
                  style: TextStyle(fontSize: 11, color: e.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
