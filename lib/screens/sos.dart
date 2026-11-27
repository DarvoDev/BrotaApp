import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/catalogo.dart';
import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';

/// CU-13 Activar botón SOS emocional. Todo el contenido es local: funciona
/// sin conexión (RNF-03) y las llamadas usan el marcador del dispositivo.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.irAInicio});

  final VoidCallback irAInicio;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _respira = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  String? _errorContacto;
  bool _acompanar = false;

  @override
  void dispose() {
    _respira.dispose();
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  String _soloNumero(String t) => t.replaceAll(RegExp(r'[^\d+]'), '');

  /// Pasos 3 a 7: una sola confirmación, se abre el marcador o la
  /// mensajería, se registra el uso y al volver se acompaña.
  Future<void> _conectar({
    required String nombre,
    required String telefono,
    required bool mensaje,
  }) async {
    final estado = BrotaScope.of(context);
    final numero = _soloNumero(telefono);
    final accion = mensaje ? 'Enviar mensaje' : 'Llamar';
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(mensaje ? '¿Escribirle a $nombre?' : '¿Llamar a $nombre?'),
        content: Text(
          mensaje
              ? 'Se abrirá tu app de mensajes con este texto listo para enviar:\n\n«$mensajeSos»'
              : 'Se abrirá el teléfono con el número $telefono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    if (si != true) return; // A3: salir sin elegir no deja registro.

    final uri = mensaje
        ? Uri.parse('sms:$numero?body=${Uri.encodeComponent(mensajeSos)}')
        : Uri(scheme: 'tel', path: numero);
    bool abierto;
    try {
      abierto = await launchUrl(uri);
    } catch (_) {
      abierto = false;
    }
    await estado.activarSOS(
      mensaje ? 'mensaje a contacto' : 'llamada: $nombre',
    );
    if (!mounted) return;
    if (abierto) {
      setState(() => _acompanar = true);
    } else {
      await _mostrarNumero(nombre, telefono, mensaje);
    }
  }

  /// E1/E2/E3: sin llamadas, sin permiso o falló el envío → número a la
  /// vista para copiarlo o marcarlo a mano.
  Future<void> _mostrarNumero(String nombre, String telefono, bool mensaje) {
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          mensaje ? 'No pude abrir tus mensajes' : 'No pude abrir el teléfono',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje
                  ? 'Puedes llamar a $nombre o marcar desde otro teléfono:'
                  : 'Este dispositivo no pudo iniciar la llamada. Marca desde cualquier teléfono:',
            ),
            const SizedBox(height: 10),
            SelectableText(
              telefono,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () async {
              final mensajes = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: _soloNumero(telefono)),
              );
              if (c.mounted) Navigator.pop(c);
              mensajes.showSnackBar(
                const SnackBar(content: Text('Número copiado')),
              );
            },
            child: const Text('Copiar número'),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarContacto() async {
    final nombre = _nombre.text.trim();
    final telefono = _telefono.text.trim();
    if (nombre.isEmpty || _soloNumero(telefono).length < 3) {
      setState(() => _errorContacto = 'Escribe un nombre y un teléfono');
      return;
    }
    final mensajes = ScaffoldMessenger.of(context);
    await BrotaScope.of(context).agregarContacto(nombre, telefono);
    _nombre.clear();
    _telefono.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _errorContacto = null);
    mensajes.showSnackBar(
      SnackBar(content: Text('$nombre ya es tu contacto de confianza 💚')),
    );
  }

  Future<void> _quitarContacto(ContactoConfianza c) async {
    final estado = BrotaScope.of(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Quitar a ${c.nombre}?'),
        content: const Text('Dejará de aparecer en tu pantalla de S.O.S.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Quitar contacto'),
          ),
        ],
      ),
    );
    if (si == true) await estado.eliminarContacto(c);
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text(
          'S.O.S',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: e.error,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'No estás solo/a. Respira, estamos contigo.',
          style: TextStyle(color: e.onSurfaceVariant),
        ),
        if (_acompanar) ...[
          const SizedBox(height: 12),
          Tarjeta(
            color: e.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pedir ayuda fue un paso valiente 💛',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Aquí sigo contigo. Si más tarde te nace, hay una actividad ligera esperándote, sin ninguna prisa.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.irAInicio,
                    child: const Text('Ver actividad ligera'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const TituloSeccion('Ayuda inmediata'),
        for (final r in recursosAyuda)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FilaAyuda(
              icono: r.esEmergencia ? Icons.emergency : Icons.support_agent,
              color: r.esEmergencia ? e.error : e.primary,
              titulo: r.nombre,
              detalle: r.descripcion,
              alLlamar: () => _conectar(
                nombre: r.nombre,
                telefono: r.telefono,
                mensaje: false,
              ),
            ),
          ),
        const TituloSeccion('Tus contactos de confianza'),
        if (estado.contactos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Aún no agregas a nadie. Puedes hacerlo ahora o después; las líneas de arriba siempre están.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
          ),
        for (final c in estado.contactos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FilaAyuda(
              icono: Icons.person,
              color: e.primary,
              titulo: c.nombre,
              detalle: c.telefono,
              alLlamar: () => _conectar(
                nombre: c.nombre,
                telefono: c.telefono,
                mensaje: false,
              ),
              alEscribir: () => _conectar(
                nombre: c.nombre,
                telefono: c.telefono,
                mensaje: true,
              ),
              alQuitar: () => _quitarContacto(c),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  isDense: true,
                  errorText: _errorContacto,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  isDense: true,
                ),
                onSubmitted: (_) => _agregarContacto(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _agregarContacto,
            icon: const Icon(Icons.add),
            label: const Text('Agregar contacto'),
          ),
        ),
        const TituloSeccion('Respira conmigo'),
        Center(
          child: SizedBox(
            height: 170,
            child: Center(
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.25).animate(
                  CurvedAnimation(parent: _respira, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.primaryContainer,
                  ),
                  child: AnimatedBuilder(
                    animation: _respira,
                    builder: (_, _) => Text(
                      _respira.status == AnimationStatus.forward
                          ? 'Inhala…'
                          : 'Exhala…',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'Brota acompaña, pero no sustituye la atención profesional.',
          textAlign: TextAlign.center,
          style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }
}

class _FilaAyuda extends StatelessWidget {
  const _FilaAyuda({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    required this.alLlamar,
    this.alEscribir,
    this.alQuitar,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String detalle;
  final VoidCallback alLlamar;
  final VoidCallback? alEscribir;
  final VoidCallback? alQuitar;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icono, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      detalle,
                      style: TextStyle(fontSize: 13, color: e.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (alQuitar != null)
                IconButton(
                  onPressed: alQuitar,
                  tooltip: 'Quitar contacto',
                  icon: Icon(Icons.close, size: 20, color: e.onSurfaceVariant),
                ),
              if (alEscribir == null)
                FilledButton(
                  onPressed: alLlamar,
                  style: FilledButton.styleFrom(backgroundColor: color),
                  child: const Text('Llamar'),
                ),
            ],
          ),
          if (alEscribir != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: alEscribir,
                      icon: const Icon(Icons.sms_outlined, size: 18),
                      label: const Text('Mensaje'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: alLlamar,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Llamar'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
