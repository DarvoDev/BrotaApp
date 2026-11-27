import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-11 Consultar recursos de ayuda.
/// Directorio local: disponible sin conexión. El 911 va siempre primero.
class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  void _avisar(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _llamar(BuildContext context, RecursoAyuda r) async {
    final numero = r.telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(
      scheme: 'tel',
      path: numero.isEmpty ? r.telefono.trim() : numero,
    );
    final aviso =
        'No pude abrir el teléfono. Puedes copiar el número y marcarlo a mano.';
    try {
      final abierto = await launchUrl(uri);
      if (!abierto && context.mounted) _avisar(context, aviso);
    } catch (_) {
      if (context.mounted) _avisar(context, aviso);
    }
  }

  Future<void> _copiar(BuildContext context, RecursoAyuda r) async {
    final numero = r.telefono.replaceAll(RegExp(r'[^\d+]'), '');
    await Clipboard.setData(
      ClipboardData(text: numero.isEmpty ? r.telefono.trim() : numero),
    );
    if (context.mounted) _avisar(context, 'Número de ${r.nombre} copiado');
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final recursos = [...estado.recursos]
      ..sort(
        (a, b) => (b.esEmergencia ? 1 : 0).compareTo(a.esEmergencia ? 1 : 0),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Recursos de ayuda')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const Text(
              'Estamos contigo',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Pedir ayuda es un paso valiente. Aquí tienes líneas que pueden escucharte.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              color: e.primaryContainer,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disponible sin conexión',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Estos números viven en tu dispositivo: puedes consultarlos aunque '
                    'no tengas internet. Si tú o alguien más está en peligro, llama al 911.',
                  ),
                ],
              ),
            ),
            TituloSeccion('Directorio de ayuda'),
            for (final r in recursos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            r.esEmergencia
                                ? Icons.emergency
                                : Icons.support_agent,
                            color: r.esEmergencia ? e.error : e.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.descripcion,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: e.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.telefono,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _llamar(context, r),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Llamar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _copiar(context, r),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copiar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Brota acompaña, pero no sustituye la atención profesional.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
