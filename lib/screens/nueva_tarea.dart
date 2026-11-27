import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';

/// CU-07 Crear tarea personalizada, con CU-07a (categoría y esfuerzo).
Future<void> mostrarNuevaTarea(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _NuevaTarea(),
);

class _NuevaTarea extends StatefulWidget {
  const _NuevaTarea();

  @override
  State<_NuevaTarea> createState() => _NuevaTareaState();
}

class _NuevaTareaState extends State<_NuevaTarea> {
  final _titulo = TextEditingController();
  String _categoria = categoriasTarea.first;
  int _esfuerzo = 1;
  String? _error;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final estado = BrotaScope.of(context);
    final error = estado.validarTitulo(_titulo.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final nav = Navigator.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    final t = await estado.crearTarea(_titulo.text, _categoria, _esfuerzo);
    nav.pop();
    mensajes.showSnackBar(
      SnackBar(content: Text('«${t.titulo}» ya está en tus tareas 🌱')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nueva tarea',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Un hábito o rutina tuya. Mientras más pequeña, más fácil empezar.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titulo,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre de la tarea',
                hintText: 'Ej. Tender la cama',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _crear(),
            ),
            const SizedBox(height: 8),
            const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final c in categoriasTarea)
                  ChoiceChip(
                    label: Text(c),
                    selected: _categoria == c,
                    onSelected: (_) => setState(() => _categoria = c),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Nivel de esfuerzo',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < nombresEsfuerzo.length; i++)
                    ButtonSegment(value: i + 1, label: Text(nombresEsfuerzo[i])),
                ],
                selected: {_esfuerzo},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _esfuerzo = s.first),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cada vez que la completes: +${10 * _esfuerzo} Exp',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _crear,
                child: const Text('Crear tarea'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
