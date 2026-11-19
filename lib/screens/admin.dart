import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../state/brota_state.dart';
import '../theme.dart';

/// CU-18 y CU-19: mantener catálogo, mensajes validados y directorio.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _microTitulo = TextEditingController();
  final _microDuracion = TextEditingController(text: '5');
  int _esfuerzo = 1;

  final _mensajeTexto = TextEditingController();
  final _mensajeCategoria = TextEditingController(text: 'Aliento');

  final _recursoNombre = TextEditingController();
  final _recursoTelefono = TextEditingController();
  final _recursoDescripcion = TextEditingController();
  final _recursoCategoria = TextEditingController(text: 'Ayuda');
  bool _esEmergencia = false;

  @override
  void dispose() {
    _microTitulo.dispose();
    _microDuracion.dispose();
    _mensajeTexto.dispose();
    _mensajeCategoria.dispose();
    _recursoNombre.dispose();
    _recursoTelefono.dispose();
    _recursoDescripcion.dispose();
    _recursoCategoria.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<bool> _confirmar(String titulo, String contenido) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(contenido),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return si == true;
  }

  Future<void> _agregarMicroactividad(BrotaState estado) async {
    final titulo = _microTitulo.text.trim();
    final duracion = int.tryParse(_microDuracion.text.trim());
    if (titulo.isEmpty) {
      _avisar('Escribe el nombre de la microactividad');
      return;
    }
    if (duracion == null || duracion < 1) {
      _avisar('Escribe una duración en minutos mayor que cero');
      return;
    }
    try {
      await estado.agregarMicroactividad(
        titulo: titulo,
        esfuerzo: _esfuerzo,
        duracionMin: duracion,
      );
      if (!mounted) return;
      _microTitulo.clear();
      _microDuracion.text = '5';
      _avisar('«$titulo» ya está en el catálogo 🌱');
    } on StateError {
      _avisar('Esta sección es solo del equipo Brota');
    }
  }

  Future<void> _eliminarMicroactividad(
    BrotaState estado,
    Microactividad m,
  ) async {
    final si = await _confirmar(
      '¿Eliminar microactividad?',
      '«${m.titulo}» dejará de proponerse en las metas.',
    );
    if (!si) return;
    try {
      await estado.eliminarMicroactividad(m.id);
      _avisar('Microactividad eliminada');
    } on StateError {
      _avisar('Esta sección es solo del equipo Brota');
    }
  }

  Future<void> _agregarMensaje(BrotaState estado) async {
    final texto = _mensajeTexto.text.trim();
    if (texto.isEmpty) {
      _avisar('Escribe el mensaje de aliento');
      return;
    }
    final categoria = _mensajeCategoria.text.trim().isEmpty
        ? 'Aliento'
        : _mensajeCategoria.text.trim();
    try {
      await estado.agregarMensaje(texto: texto, categoria: categoria);
      if (!mounted) return;
      _mensajeTexto.clear();
      _avisar('Mensaje validado y listo para compartir 💚');
    } on StateError {
      _avisar('Esta sección es solo del equipo Brota');
    }
  }

  Future<void> _eliminarMensaje(BrotaState estado, MensajeValidado m) async {
    final si = await _confirmar(
      '¿Eliminar mensaje?',
      'El mensaje «${m.texto}» dejará de mostrarse.',
    );
    if (!si) return;
    try {
      await estado.eliminarMensaje(m.id);
      _avisar('Mensaje eliminado');
    } on StateError {
      _avisar('Esta sección es solo del equipo Brota');
    }
  }

  Future<void> _agregarRecurso(BrotaState estado) async {
    final nombre = _recursoNombre.text.trim();
    final telefono = _recursoTelefono.text.trim();
    if (nombre.isEmpty || telefono.isEmpty) {
      _avisar('Escribe el nombre y el teléfono del recurso');
      return;
    }
    final categoria = _recursoCategoria.text.trim().isEmpty
        ? 'Ayuda'
        : _recursoCategoria.text.trim();
    try {
      await estado.agregarRecurso(
        nombre: nombre,
        telefono: telefono,
        descripcion: _recursoDescripcion.text,
        esEmergencia: _esEmergencia,
        categoria: categoria,
      );
      if (!mounted) return;
      _recursoNombre.clear();
      _recursoTelefono.clear();
      _recursoDescripcion.clear();
      _esEmergencia = false;
      setState(() {});
      _avisar('«$nombre» ya está en el directorio 📞');
    } on StateError {
      _avisar('Esta sección es solo del equipo Brota');
    }
  }

  Future<void> _eliminarRecurso(BrotaState estado, RecursoAyuda r) async {
    final si = await _confirmar(
      '¿Eliminar recurso?',
      '«${r.nombre}» dejará de aparecer en el directorio de ayuda.',
    );
    if (!si) return;
    try {
      await estado.eliminarRecurso(r.id);
      _avisar('Recurso eliminado');
    } on StateError {
      _avisar('Esta sección es solo del equipo Brota');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Brota')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const Text(
              'Herramientas del equipo',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Pequeños ajustes para que Brota siga acompañando bien.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (!estado.esAdmin)
              Tarjeta(
                color: e.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Esta sección es solo del equipo Brota',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Las metas, los mensajes y el directorio se mantienen '
                      'aquí con mucho cuidado. Si necesitas algo, escribe al '
                      'equipo y lo revisamos sin prisa 🌿',
                    ),
                  ],
                ),
              )
            else ...[
              _titulo('Microactividades', e),
              _seccionMicroactividades(estado, e),
              _titulo('Mensajes validados', e),
              _seccionMensajes(estado, e),
              _titulo('Directorio de ayuda', e),
              _seccionRecursos(estado, e),
            ],
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto, ColorScheme e) => TituloSeccion(
    texto,
    accion: Text(
      'Equipo Brota',
      style: TextStyle(fontSize: 12, color: e.onSurfaceVariant),
    ),
  );

  Widget _seccionMicroactividades(BrotaState estado, ColorScheme e) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          estado.catalogo.isEmpty
              ? Text(
                  'Todavía no hay microactividades. Agrega la primera 🌱',
                  style: TextStyle(color: e.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final m in estado.catalogo)
                      _FilaAdmin(
                        titulo: m.titulo,
                        detalle:
                            '${nombresEsfuerzo[m.esfuerzo - 1]} · ${m.duracionMin} min · +${m.calcularXP()} Exp',
                        etiquetaEliminar: 'Eliminar microactividad ${m.titulo}',
                        alEliminar: () => _eliminarMicroactividad(estado, m),
                      ),
                  ],
                ),
          const Divider(height: 22),
          const Text(
            'Agregar microactividad',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _microTitulo,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Estirar los hombros',
            ),
          ),
          const SizedBox(height: 6),
          const Text('Esfuerzo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Semantics(
            label: 'Nivel de esfuerzo de la microactividad',
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < nombresEsfuerzo.length; i++)
                    ButtonSegment(
                      value: i + 1,
                      label: Text(nombresEsfuerzo[i]),
                    ),
                ],
                selected: {_esfuerzo},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _esfuerzo = s.first),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _microDuracion,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duración en minutos',
              hintText: 'Ej. 5',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _agregarMicroactividad(estado),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionMensajes(BrotaState estado, ColorScheme e) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          estado.mensajes.isEmpty
              ? Text(
                  'Aún no hay mensajes. Escribe el primero 💛',
                  style: TextStyle(color: e.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final m in estado.mensajes)
                      _FilaAdmin(
                        titulo: m.texto,
                        detalle:
                            '${m.categoria} · validado por ${m.validadoPor}',
                        etiquetaEliminar: 'Eliminar mensaje ${m.texto}',
                        alEliminar: () => _eliminarMensaje(estado, m),
                      ),
                  ],
                ),
          const Divider(height: 22),
          const Text(
            'Agregar mensaje',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mensajeTexto,
            maxLines: 3,
            maxLength: 240,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Texto del mensaje',
              hintText: 'Un pasito a la vez también es avanzar 🌱',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _mensajeCategoria,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              hintText: 'Ej. Aliento',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _agregarMensaje(estado),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionRecursos(BrotaState estado, ColorScheme e) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          estado.recursos.isEmpty
              ? Text(
                  'Todavía no hay recursos en el directorio 📞',
                  style: TextStyle(color: e.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final r in estado.recursos)
                      _FilaAdmin(
                        titulo: r.nombre,
                        detalle:
                            '${r.telefono} · ${r.categoria}${r.esEmergencia ? ' · EMERGENCIA' : ''}',
                        etiquetaEliminar: 'Eliminar recurso ${r.nombre}',
                        alEliminar: () => _eliminarRecurso(estado, r),
                      ),
                  ],
                ),
          const Divider(height: 22),
          const Text(
            'Agregar recurso',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _recursoNombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recursoTelefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              hintText: 'Ej. 800 000 0000',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recursoDescripcion,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recursoCategoria,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              hintText: 'Ej. Ayuda',
            ),
          ),
          Semantics(
            label: 'Marcar como recurso de emergencia',
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _esEmergencia,
              onChanged: (v) => setState(() => _esEmergencia = v ?? false),
              title: const Text('Es emergencia'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _agregarRecurso(estado),
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaAdmin extends StatelessWidget {
  const _FilaAdmin({
    required this.titulo,
    required this.detalle,
    required this.etiquetaEliminar,
    required this.alEliminar,
  });

  final String titulo;
  final String detalle;
  final String etiquetaEliminar;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: e.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: etiquetaEliminar,
            child: IconButton(
              onPressed: alEliminar,
              tooltip: etiquetaEliminar,
              icon: Icon(Icons.close, size: 20, color: e.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
