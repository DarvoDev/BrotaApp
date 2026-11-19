import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../state/brota_state.dart';
import '../theme.dart';

/// CU-01 a CU-04: cuenta, inicio de sesión, avatar y mascota.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const _avatares = ['🌱', '🌿', '🍀', '🌻', '🌸', '🌳'];
  static const _mascotas = ['🐶', '🐱', '🐰', '🐢'];

  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _fechaNac = TextEditingController();
  final _nombreMascota = TextEditingController();

  bool _registrando = false;
  bool _esAdmin = false;
  bool _cargando = false;
  String? _error;

  late String _avatar;
  late String _mascota;

  @override
  void initState() {
    super.initState();
    final estado = BrotaScope.of(context);
    _avatar = estado.avatar;
    _mascota = estado.mascota;
    _nombreMascota.text = estado.mascotaNombre;
  }

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    _nombre.dispose();
    _apellidos.dispose();
    _fechaNac.dispose();
    _nombreMascota.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _cambiarModo(bool registrando) {
    setState(() {
      _registrando = registrando;
      _error = null;
    });
  }

  /// Tras crear cuenta o entrar, los selectores reflejan lo guardado.
  void _sincronizarPerfil() {
    final estado = BrotaScope.of(context);
    _avatar = estado.avatar;
    _mascota = estado.mascota;
    _nombreMascota.text = estado.mascotaNombre;
  }

  Future<void> _entrar() async {
    if (_cargando) return;
    final estado = BrotaScope.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    final correo = _correo.text.trim();
    final password = _password.text;

    if (correo.isEmpty || !correo.contains('@') || password.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    final ok = await estado.iniciarSesion(correo, password);
    if (!mounted) return;
    setState(() => _cargando = false);
    if (!ok) {
      const mensaje = 'Correo o contraseña incorrectos';
      setState(() => _error = mensaje);
      _avisar(mensaje);
      return;
    }
    _sincronizarPerfil();
    Navigator.of(context).pop();
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '¡Qué gusto verte de nuevo, ${estado.nombreUsuario}! 🌱',
          ),
        ),
      );
  }

  Future<void> _registrarse() async {
    if (_cargando) return;
    final estado = BrotaScope.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    final error = estado.validarRegistro(
      correo: _correo.text,
      password: _password.text,
      nombre: _nombre.text,
    );
    if (error != null) {
      setState(() => _error = error);
      _avisar(error);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    final ok = await estado.registrarse(
      correo: _correo.text,
      password: _password.text,
      nombre: _nombre.text,
      apellidos: _apellidos.text,
      fechaNac: _fechaNac.text,
      rol: _esAdmin ? Rol.administrador : Rol.usuario,
    );
    if (!mounted) return;
    setState(() => _cargando = false);
    if (!ok) {
      _avisar(
        'No pude crear la cuenta. Revisa los datos e inténtalo de nuevo.',
      );
      return;
    }
    _sincronizarPerfil();
    Navigator.of(context).pop();
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '¡Tu cuenta ya está lista! Bienvenida o bienvenido a Brota 🌿',
          ),
        ),
      );
  }

  Future<void> _invitado() async {
    final estado = BrotaScope.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    await estado.continuarComoInvitado();
    if (!mounted) return;
    Navigator.of(context).pop();
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Sigues como invitado o invitada. Brota te acompaña igual 💚',
          ),
        ),
      );
  }

  Future<void> _guardarCambios() async {
    final estado = BrotaScope.of(context);
    final nombre = _nombreMascota.text.trim().isEmpty
        ? 'Brotito'
        : _nombreMascota.text.trim();
    await estado.personalizarAvatar(_avatar);
    await estado.elegirMascota(_mascota, nombre);
    if (!mounted) return;
    _nombreMascota.text = estado.mascotaNombre;
    _avisar('Listo, tus compañeros ya están actualizados ✨');
  }

  Future<void> _cerrarSesion() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tus hábitos y tu progreso se quedan guardados en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    await BrotaScope.of(context).cerrarSesion();
    if (!mounted) return;
    setState(() {
      _error = null;
      _registrando = false;
      _esAdmin = false;
      _correo.clear();
      _password.clear();
    });
    _avisar('Sesión cerrada. Hasta pronto 🌱');
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            Text(
              estado.tieneCuenta
                  ? 'Hola, ${estado.nombreUsuario} 👋'
                  : 'Tu espacio en Brota 🌱',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              estado.tieneCuenta
                  ? 'Aquí puedes cambiar tus compañeros de camino.'
                  : 'Entra, crea tu cuenta o simplemente empieza a brotar.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (estado.tieneCuenta)
              _buildCuenta(estado, e)
            else
              _buildAcceso(e),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceso(ColorScheme e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Modo de acceso',
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Iniciar sesión')),
              ButtonSegment(value: true, label: Text('Crear cuenta')),
            ],
            selected: {_registrando},
            onSelectionChanged: (s) => _cambiarModo(s.first),
          ),
        ),
        const SizedBox(height: 12),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _registrando
                    ? 'Crea tu cuenta'
                    : 'Bienvenida o bienvenido de nuevo',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _registrando
                    ? 'Tu cuenta se guarda solo en este dispositivo, sin culpas y sin prisa.'
                    : 'Entra con el correo que usaste al crear tu cuenta.',
                style: TextStyle(color: e.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'tu@correo.com',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: _registrando
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) => _registrando ? _registrarse() : _entrar(),
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              if (_registrando) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: '¿Cómo te llamas?',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _apellidos,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Apellidos (opcional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _fechaNac,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _registrarse(),
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento (opcional)',
                    hintText: 'AAAA-MM-DD',
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Registrarme como parte del equipo Brota',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _esAdmin,
                    onChanged: (v) => setState(() => _esAdmin = v),
                    title: const Text('Soy del equipo Brota (administrador)'),
                    subtitle: const Text('Solo para probar la administración.'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: e.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Semantics(
                label: _registrando ? 'Crear cuenta' : 'Entrar',
                button: true,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _cargando
                        ? null
                        : _registrando
                        ? _registrarse
                        : _entrar,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_registrando ? 'Crear cuenta' : 'Entrar'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _invitado,
          icon: const Icon(Icons.person_outline),
          label: const Text('Continuar como invitado'),
        ),
      ],
    );
  }

  Widget _buildCuenta(BrotaState estado, ColorScheme e) {
    final cuenta = estado.cuenta!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(estado.avatar, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cuenta.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Dato(label: 'Correo', valor: cuenta.correo),
              if (cuenta.apellidos.isNotEmpty)
                _Dato(label: 'Apellidos', valor: cuenta.apellidos),
              if (cuenta.fechaNac.isNotEmpty)
                _Dato(label: 'Nacimiento', valor: cuenta.fechaNac),
              _Dato(label: 'Rol', valor: cuenta.rol.texto),
              const SizedBox(height: 6),
              Text(
                'Nivel ${estado.nivel} · ${estado.xpTotal} Exp',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
        TituloSeccion('Elige tu avatar'),
        Tarjeta(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in _avatares)
                Semantics(
                  label: 'Avatar $emoji',
                  button: true,
                  selected: _avatar == emoji,
                  child: ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 21)),
                    selected: _avatar == emoji,
                    onSelected: (_) => setState(() => _avatar = emoji),
                  ),
                ),
            ],
          ),
        ),
        TituloSeccion('Tu mascota'),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final emoji in _mascotas)
                    Semantics(
                      label: 'Mascota $emoji',
                      button: true,
                      selected: _mascota == emoji,
                      child: ChoiceChip(
                        label: Text(
                          emoji,
                          style: const TextStyle(fontSize: 21),
                        ),
                        selected: _mascota == emoji,
                        onSelected: (_) => setState(() => _mascota = emoji),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombreMascota,
                textCapitalization: TextCapitalization.words,
                maxLength: 24,
                decoration: const InputDecoration(
                  labelText: 'Nombre de tu mascota',
                  hintText: 'Ej. Brotito',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _guardarCambios,
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _cerrarSesion,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: valor),
        ],
      ),
    ),
  );
}
