import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

const List<String> _nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const List<int> _todosLosDias = [1, 2, 3, 4, 5, 6, 7];

/// CU-08 Configurar recordatorios amables.
/// Los avisos se muestran al abrir la app: no hay servicio en segundo plano
/// ni notificaciones push.
class RecordatoriosScreen extends StatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  State<RecordatoriosScreen> createState() => _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends State<RecordatoriosScreen> {
  final _titulo = TextEditingController();
  TimeOfDay _hora = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _dias = {..._todosLosDias};
  bool _activo = true;
  String? _editandoId;
  String? _error;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  String _hora24() =>
      '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  static String _resumenDias(List<int> dias) {
    if (dias.isEmpty) return 'sin días elegidos';
    if (dias.length == 7) return 'todos los días';
    final ordenados = dias.toList()..sort();
    return ordenados.map((d) => _nombresDias[d - 1]).join(', ');
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(context: context, initialTime: _hora);
    if (elegida == null || !mounted) return;
    setState(() => _hora = elegida);
  }

  void _precarregar(Recordatorio r) {
    setState(() {
      _titulo.text = r.titulo;
      _hora = TimeOfDay(hour: r.horaMinutos ~/ 60, minute: r.horaMinutos % 60);
      _dias = r.diasSemana.toSet();
      _activo = r.activo;
      _editandoId = r.id;
      _error = null;
    });
  }

  void _limpiar() {
    setState(() {
      _titulo.clear();
      _hora = const TimeOfDay(hour: 9, minute: 0);
      _dias = {..._todosLosDias};
      _activo = true;
      _editandoId = null;
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _guardar() async {
    final texto = _titulo.text.trim();
    if (texto.isEmpty) {
      setState(() => _error = 'Escribe un nombre para tu aviso');
      return;
    }
    if (_dias.isEmpty) {
      setState(() => _error = 'Elige al menos un día de la semana');
      return;
    }
    final esNuevo = _editandoId == null;
    final estado = BrotaScope.of(context);
    await estado.guardarRecordatorio(
      Recordatorio(
        id: _editandoId ?? 'r-${DateTime.now().microsecondsSinceEpoch}',
        titulo: texto,
        horaMinutos: _hora.hour * 60 + _hora.minute,
        diasSemana: _dias.toList()..sort(),
        activo: _activo,
      ),
    );
    if (!mounted) return;
    _limpiar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(esNuevo ? 'Aviso guardado ⏰' : 'Aviso actualizado ⏰')),
    );
  }

  Future<void> _eliminar(Recordatorio r) async {
    await BrotaScope.of(context).eliminarRecordatorio(r.id);
    if (!mounted) return;
    if (_editandoId == r.id) _limpiar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Aviso eliminado')));
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final suave = estado.modoRecordatorioSuave;

    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            const Text(
              'Avisos amables',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text('Un aviso para volver a ti, sin presión.'),
            const SizedBox(height: 12),
            Tarjeta(
              color: e.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Así funcionan', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    suave
                        ? 'Bajamos el ritmo de los avisos estos días; solo un recordatorio suave, sin acumular avisos.'
                        : 'Avisos discretos, en la hora que elijas; no interrumpen y funcionan sin conexión.',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El aviso se muestra al abrir la app; no es una notificación push '
                    '(no hay servicio en segundo plano).',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            TituloSeccion(
              _editandoId == null ? 'Nuevo recordatorio' : 'Editar recordatorio',
            ),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titulo,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: '¿Qué quieres recordar?',
                      hintText: 'Ej. Respirar un minuto',
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hora: ${_hora24()}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _elegirHora,
                        icon: const Icon(Icons.access_time, size: 18),
                        label: const Text('Elegir hora'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Días de la semana', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        ChoiceChip(
                          label: Text(_nombresDias[d - 1]),
                          selected: _dias.contains(d),
                          onSelected: (_) => setState(() {
                            if (_dias.contains(d)) {
                              _dias.remove(d);
                            } else {
                              _dias.add(d);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: _activo,
                    onChanged: (v) => setState(() => _activo = v ?? true),
                    title: const Text('Activo'),
                    subtitle: const Text('Si lo desactivas, no aparecerá al abrir la app.'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _guardar,
                          child: Text(
                            _editandoId == null
                                ? 'Guardar recordatorio'
                                : 'Guardar cambios',
                          ),
                        ),
                      ),
                      if (_editandoId != null) ...[
                        const SizedBox(width: 8),
                        TextButton(onPressed: _limpiar, child: const Text('Cancelar')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            TituloSeccion('Tus recordatorios'),
            if (estado.recordatorios.isEmpty)
              Tarjeta(
                child: Text(
                  'Aún no tienes avisos. Puedes crear uno arriba, o dejar que el día '
                  'te encuentre sin alarmas. Tú decides.',
                  style: TextStyle(color: e.onSurfaceVariant),
                ),
              ),
            for (final r in estado.recordatorios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tarjeta(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.titulo,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.horaTexto} · ${_resumenDias(r.diasSemana)}',
                              style: TextStyle(fontSize: 13, color: e.onSurfaceVariant),
                            ),
                            if (!r.activo)
                              Text(
                                'Desactivado',
                                style: TextStyle(fontSize: 12, color: e.error),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _precarregar(r),
                        tooltip: 'Editar aviso',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        onPressed: () => _eliminar(r),
                        tooltip: 'Eliminar aviso',
                        icon: Icon(Icons.delete_outline, size: 20, color: e.error),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Puedes cambiar o quitar tus avisos cuando quieras. Sin culpa.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
