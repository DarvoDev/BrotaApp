import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-14: muro de aliento anónimo y local, sin servidor.
class ComunidadScreen extends StatefulWidget {
  const ComunidadScreen({super.key});

  @override
  State<ComunidadScreen> createState() => _ComunidadScreenState();
}

class _ComunidadScreenState extends State<ComunidadScreen> {
  static const int _maximo = 240;
  final TextEditingController _control = TextEditingController();

  @override
  void initState() {
    super.initState();
    _control.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    final estado = BrotaScope.of(context);
    try {
      await estado.publicarAliento(_control.text);
      if (!mounted) return;
      _control.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu aliento ya está en el muro 💚')),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _copiarLogro() {
    final estado = BrotaScope.of(context);
    Clipboard.setData(ClipboardData(text: estado.logroCompartible));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logro copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Comunidad y aliento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            Tarjeta(
              color: e.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Un muro para acompañarnos 🌱',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Comunidad anónima local: nadie ve tu nombre ni tus datos; '
                    'no hay servidor. Lo que publicas se queda en este dispositivo.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Deja un aliento'),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _control,
                    maxLength: _maximo,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Escribe un mensaje amable',
                      hintText: 'Un pasito a la vez también es avanzar 🌱',
                      alignLabelWithHint: true,
                    ),
                  ),
                  BarraProgreso(_control.text.length / _maximo),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _publicar,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Publicar aliento'),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Tu logro para compartir'),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(estado.logroCompartible),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _copiarLogro,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copiar/logro'),
                    ),
                  ),
                ],
              ),
            ),
            TituloSeccion(
              'Muro de aliento',
              accion: Text(
                '${estado.publicaciones.length}',
                style: TextStyle(color: e.onSurfaceVariant),
              ),
            ),
            if (estado.publicaciones.isEmpty)
              Tarjeta(
                child: Text(
                  'Aún no hay mensajes. Puedes escribir el primero 💛',
                  style: TextStyle(color: e.onSurfaceVariant),
                ),
              )
            else
              for (final publicacion in estado.publicaciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tarjeta(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                publicacion.autor,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              fechaCorta(diaDeClave(publicacion.fecha)),
                              style: TextStyle(
                                fontSize: 11,
                                color: e.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(publicacion.contenido),
                        if (publicacion.esLogro) ...[
                          const SizedBox(height: 8),
                          Text(
                            '✨ Logro compartido',
                            style: TextStyle(
                              fontSize: 12,
                              color: e.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 6),
            Text(
              'Comparte desde el corazón: aquí nadie lleva la cuenta de quién es quién.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
