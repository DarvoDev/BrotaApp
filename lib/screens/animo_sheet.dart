import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';

/// CU-05: chequeo rápido de ánimo y energía.
/// Devuelve true si el Usuario guardó; false si eligió «Ahora no» o cerró.
Future<bool> mostrarChequeoAnimo(BuildContext context) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ChequeoAnimo(),
  );
  return r ?? false;
}

class _ChequeoAnimo extends StatefulWidget {
  const _ChequeoAnimo();

  @override
  State<_ChequeoAnimo> createState() => _ChequeoAnimoState();
}

class _ChequeoAnimoState extends State<_ChequeoAnimo> {
  int? _animo;
  int? _energia;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    // A2: si ya hay registro hoy, se parte de él para actualizarlo.
    final r = BrotaScope.of(context).animoDeHoy;
    _animo = r?.animo;
    _energia = r?.energia;
  }

  Future<void> _guardar() async {
    final nav = Navigator.of(context);
    await BrotaScope.of(context).registrarAnimo(_animo!, _energia!);
    nav.pop(true);
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
              '¿Cómo te sientes hoy?',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'No hay respuesta incorrecta. Con esto ajusto tus metas de hoy.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            const Text('Ánimo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < iconosAnimo.length; i++)
                  Expanded(
                    child: _Opcion(
                      icono: iconosAnimo[i],
                      nombre: nombresAnimo[i],
                      elegida: _animo == i + 1,
                      alTocar: () => setState(() => _animo = i + 1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Energía', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < iconosEnergia.length; i++)
                  Expanded(
                    child: _Opcion(
                      icono: iconosEnergia[i],
                      nombre: nombresEnergia[i],
                      elegida: _energia == i + 1,
                      alTocar: () => setState(() => _energia = i + 1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Ahora no'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _animo != null && _energia != null ? _guardar : null,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.nombre,
    required this.elegida,
    required this.alTocar,
  });

  final String icono;
  final String nombre;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        selected: elegida,
        label: nombre,
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: elegida ? e.primaryContainer : e.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: elegida ? e.primary : e.outlineVariant,
                width: 2,
              ),
            ),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Text(icono, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 2),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: elegida ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
