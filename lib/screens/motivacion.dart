import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-12 Ver mensajes motivacionales validados, agrupados por categoría.
class MotivacionScreen extends StatefulWidget {
  const MotivacionScreen({super.key});

  @override
  State<MotivacionScreen> createState() => _MotivacionScreenState();
}

class _MotivacionScreenState extends State<MotivacionScreen> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    final estado = BrotaScope.read(context);
    final mensajes = estado.mensajes;
    final diario = estado.mensajeMotivacionalDelDia;
    final i = mensajes.indexWhere((m) => m.id == diario.id);
    _indice = i >= 0 ? i : 0;
  }

  void _siguiente() {
    final total = BrotaScope.of(context).mensajes.length;
    if (total == 0) return;
    setState(() => _indice = (_indice + 1) % total);
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final mensajes = estado.mensajes;
    final destacado = mensajes.isEmpty
        ? estado.mensajeMotivacionalDelDia
        : mensajes[_indice % mensajes.length];

    final categorias = <String, List<MensajeValidado>>{};
    for (final m in mensajes) {
      categorias.putIfAbsent(m.categoria, () => <MensajeValidado>[]).add(m);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Motivación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const Text(
              'Un mensaje para ti',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Léelo despacio. Si hoy no te nace, vuelve mañana: sigues aquí.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              color: e.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('💛', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mensaje de hoy',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destacado.texto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Validado por: ${destacado.validadoPor}',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: mensajes.isEmpty ? null : _siguiente,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Otro mensaje'),
                    ),
                  ),
                ],
              ),
            ),
            TituloSeccion(
              'Todos los mensajes',
              accion: Text(
                '${mensajes.length} ${mensajes.length == 1 ? 'mensaje' : 'mensajes'}',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
              ),
            ),
            for (final entrada in categorias.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(label: Text(entrada.key)),
                    for (final m in entrada.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Tarjeta(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('«${m.texto}»'),
                              const SizedBox(height: 4),
                              Text(
                                'Validado por: ${m.validadoPor}',
                                style: TextStyle(
                                  color: e.onSurfaceVariant,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Estos mensajes fueron revisados con cariño. Puedes volver cuando lo necesites 🌱',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
