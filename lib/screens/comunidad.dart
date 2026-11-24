import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalogo.dart';
import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-14 Compartir logros y aliento, y CU-23 Reportar publicación.
/// El muro es anónimo y moderado: solo frases predefinidas o logros, sin
/// texto libre ni perfiles; cualquier publicación se puede reportar.
class ComunidadScreen extends StatefulWidget {
  const ComunidadScreen({super.key});

  @override
  State<ComunidadScreen> createState() => _ComunidadScreenState();
}

class _ComunidadScreenState extends State<ComunidadScreen> {
  String? _frase;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BrotaScope.of(context).cargarComunidad();
    });
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _publicar() async {
    final id = _frase;
    if (id == null) {
      _avisar('Elige una frase para publicar');
      return;
    }
    await BrotaScope.of(context).publicarFrase(id);
    if (!mounted) return;
    setState(() => _frase = null);
    _avisar('Tu aliento ya está en el muro 💚');
  }

  Future<void> _publicarLogro() async {
    await BrotaScope.of(context).publicarLogro();
    if (!mounted) return;
    _avisar('Tu logro ya está en el muro, sin tu nombre ✨');
  }

  void _copiarLogro() {
    final estado = BrotaScope.of(context);
    Clipboard.setData(ClipboardData(text: estado.logroCompartible));
    _avisar('Logro copiado al portapapeles');
  }

  Future<void> _reportar(Publicacion p) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '¿Por qué quieres reportarla?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final m in motivosReporte)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(m),
                onTap: () => Navigator.pop(c, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (motivo == null || !mounted) return;
    await BrotaScope.of(context).reportarPublicacion(p, motivo);
    if (!mounted) return;
    _avisar('Gracias. La ocultamos para ti y el equipo la revisará');
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final visibles = estado.publicacionesVisibles;

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
                    estado.conectado
                        ? 'Muro compartido y anónimo: nadie ve tu nombre. Solo se '
                              'publican frases amables ya revisadas, y cualquier '
                              'mensaje se puede reportar.'
                        : 'Muro anónimo en este dispositivo (sin servidor '
                              'conectado). Solo se publican frases amables ya '
                              'revisadas, y cualquier mensaje se puede reportar.',
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
                  Text(
                    'Elige una frase. No hay texto libre para que el muro siga '
                    'siendo un lugar seguro.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in frasesMuro)
                        ChoiceChip(
                          label: Text(f.texto),
                          selected: _frase == f.id,
                          onSelected: (s) =>
                              setState(() => _frase = s ? f.id : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _frase == null ? null : _publicar,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _copiarLogro,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copiar logro'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _publicarLogro,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Publicar en el muro'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TituloSeccion(
              'Muro de aliento',
              accion: Text(
                '${visibles.length}',
                style: TextStyle(color: e.onSurfaceVariant),
              ),
            ),
            if (visibles.isEmpty)
              Tarjeta(
                child: Text(
                  'Aún no hay mensajes. Puedes dejar el primero 💛',
                  style: TextStyle(color: e.onSurfaceVariant),
                ),
              )
            else
              for (final publicacion in visibles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Tarjeta(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
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
                            IconButton(
                              tooltip: 'Reportar publicación',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _reportar(publicacion),
                              icon: Icon(
                                Icons.flag_outlined,
                                size: 18,
                                color: e.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(publicacion.contenido),
                        ),
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
              'Aquí nadie lleva la cuenta de quién es quién.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
