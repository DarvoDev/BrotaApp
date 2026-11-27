import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-06 Explorar catálogo de microactividades.
/// El catálogo solo se consulta: agregar una meta no modifica el catálogo,
/// que lo administra el Administrador (CU-18).
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _busqueda = TextEditingController();

  /// 0 = Todos; 1, 2 y 3 = ligero, medio y alto.
  int _esfuerzo = 0;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  List<Microactividad> _filtrar(List<Microactividad> catalogo) {
    final texto = _busqueda.text.trim().toLowerCase();
    return catalogo.where((m) {
      final porTexto = texto.isEmpty || m.titulo.toLowerCase().contains(texto);
      final porEsfuerzo = _esfuerzo == 0 || m.esfuerzo == _esfuerzo;
      return porTexto && porEsfuerzo;
    }).toList();
  }

  Future<void> _agregar(Microactividad m) async {
    await BrotaScope.of(context).agregarMetaDelCatalogo(m.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('«${m.titulo}» ya está en tus misiones de hoy 🌱')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final resultados = _filtrar(estado.catalogo);
    final filtros = ['Todos', ...nombresEsfuerzo];

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const Text(
              'Microactividades',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Elige algo pequeño, sin prisa ni nota. Sumar un pasito ya es avanzar.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Buscar microactividad',
                hintText: 'Ej. respirar, caminar…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _busqueda.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Nivel de esfuerzo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < filtros.length; i++)
                  ChoiceChip(
                    label: Text(filtros[i]),
                    selected: _esfuerzo == i,
                    onSelected: (_) => setState(() => _esfuerzo = i),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${resultados.length} ${resultados.length == 1 ? 'resultado' : 'resultados'}',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
            TituloSeccion('Para elegir'),
            if (resultados.isEmpty)
              Tarjeta(
                child: Text(
                  'No encontré nada con ese texto. Prueba otra palabra o cambia el esfuerzo; '
                  'está bien no encontrar nada perfecto.',
                  style: TextStyle(color: e.onSurfaceVariant),
                ),
              ),
            for (final m in resultados)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${m.duracionMin} min · ${nombresEsfuerzo[m.esfuerzo - 1]} · '
                        '+${m.calcularXP()} Exp',
                        style: TextStyle(fontSize: 13, color: e.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: estado.metasTotalesHoy.any((x) => x.id == m.id)
                            ? const OutlinedButton(
                                onPressed: null,
                                child: Text('Ya está en tus metas'),
                              )
                            : FilledButton.tonal(
                                onPressed: () => _agregar(m),
                                child: const Text('Añadir a hoy'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Agregar una actividad no cambia el catálogo: solo la pone en tus metas de hoy.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
