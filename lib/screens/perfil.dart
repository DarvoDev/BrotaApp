import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const _avatares = [
    'lib/assets/images/Brote.jpg',
    'lib/assets/images/Hoja.jpg',
    'lib/assets/images/Trebol.jpg',
    'lib/assets/images/Girasol.jpg',
    'lib/assets/images/Cerezo.jpg',
    'lib/assets/images/Arbol.jpg',
  ];
  static const _mascotas = [
    'lib/assets/images/Perro.jpg',
    'lib/assets/images/Gato.jpg',
    'lib/assets/images/Conejo.jpg',
    'lib/assets/images/Tortuga.jpg',
  ];

  final _correo = TextEditingController();
  final _password = TextEditingController();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _fechaNac = TextEditingController();
  final _nombreMascota = TextEditingController();

  bool _registrando = false;
  bool _esAdmin = false;
  bool _aceptaPrivacidad = false;
  bool _consentimientoTutor = false;
  bool _cargando = false;
  String? _error;

  late String _avatar;
  late String _mascota;

  @override
  void initState() {
    super.initState();
    final estado = BrotaScope.read(context);
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
      fechaNac: _fechaIso,
      aceptaPrivacidad: _aceptaPrivacidad,
      consentimientoTutor: _consentimientoTutor,
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
      fechaNac: _fechaIso,
      aceptaPrivacidad: _aceptaPrivacidad,
      consentimientoTutor: _consentimientoTutor,
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
        SnackBar(
          content: Text(
            estado.fueraDeRangoObjetivo
                ? 'Tu cuenta está lista 🌿 Brota está pensada para personas de '
                      '13 a 35 años, pero puedes usarla igual.'
                : '¡Tu cuenta ya está lista! Bienvenida o bienvenido a Brota 🌿',
          ),
        ),
      );
  }

  /// La persona escribe DD-MM-AAAA; la app y el servidor guardan AAAA-MM-DD.
  String get _fechaIso => fechaIsoDesde(_fechaNac.text);

  /// Menores de 18 (y de 13 o más) necesitan consentimiento del tutor.
  bool get _esMenor {
    final edad = BrotaScope.of(context).edadDe(_fechaIso);
    return edad != null && edad >= edadMinima && edad < edadMayoria;
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: DateTime(hoy.year - 18, hoy.month, hoy.day),
      firstDate: DateTime(hoy.year - 100),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (f == null) return;
    setState(() => _fechaNac.text = fechaParaMostrar(claveDia(f)));
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [_FormatoFecha()],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _registrarse(),
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    hintText: 'DD-MM-AAAA',
                    helperText: 'Brota es para personas de 13 años o más',
                    suffixIcon: IconButton(
                      tooltip: 'Elegir fecha',
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: _elegirFecha,
                    ),
                  ),
                ),
                if (_esMenor) ...[
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _consentimientoTutor,
                    onChanged: (v) =>
                        setState(() => _consentimientoTutor = v ?? false),
                    title: const Text(
                      'Mi madre, padre o tutor leyó el aviso de privacidad y '
                      'está de acuerdo con que use Brota',
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _aceptaPrivacidad,
                  onChanged: (v) =>
                      setState(() => _aceptaPrivacidad = v ?? false),
                  title: const Text('Leí y acepto el aviso de privacidad'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => mostrarAvisoPrivacidad(context),
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text('Leer aviso de privacidad'),
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
                  estado.avatar.endsWith('.jpg')
                      ? Image.asset(estado.avatar, width: 90, height: 90)
                      : Text(
                          estado.avatar,
                          style: const TextStyle(fontSize: 34),
                        ),
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
                _Dato(
                  label: 'Nacimiento',
                  valor: fechaParaMostrar(cuenta.fechaNac),
                ),
              _Dato(label: 'Rol', valor: cuenta.rol.texto),
              const SizedBox(height: 6),
              Text(
                'Avatar nivel ${estado.nivel} · ${estado.mascotaNombre} nivel '
                '${estado.nivelMascota} · ${estado.xpTotal} Exp',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
              ),
              if (estado.fueraDeRangoObjetivo) ...[
                const SizedBox(height: 6),
                Text(
                  'Brota está pensada para personas de 13 a 35 años. Puedes '
                  'usarla igual; algunos textos quizá no te queden del todo.',
                  style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => mostrarAvisoPrivacidad(context),
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: const Text('Aviso de privacidad'),
                ),
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
              for (final avatar in _avatares)
                ChoiceChip(
                  label:
                      avatar.endsWith('.jpg') ||
                          avatar.endsWith('.png') ||
                          avatar.endsWith('.webp')
                      ? Image.asset(avatar, width: 90, height: 90)
                      : Text(avatar, style: const TextStyle(fontSize: 21)),
                  selected: _avatar == avatar,
                  onSelected: (_) => setState(() => _avatar = avatar),
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
                  for (final mascota in _mascotas)
                    Semantics(
                      label: 'Mascota $mascota',
                      button: true,
                      selected: _mascota == mascota,
                      child: ChoiceChip(
                        label: mascota.startsWith('lib/assets/')
                            ? Image.asset(
                                mascota,
                                width: 90,
                                height: 90,
                                fit: BoxFit.contain,
                              )
                            : Text(
                                mascota,
                                style: const TextStyle(fontSize: 21),
                              ),
                        selected: _mascota == mascota,
                        onSelected: (_) => setState(() => _mascota = mascota),
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

/// Aviso de privacidad simplificado (riesgo «menores de edad»). Se muestra
/// al registrarse y desde Mi perfil.
Future<void> mostrarAvisoPrivacidad(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text('Aviso de privacidad'),
    content: const SingleChildScrollView(
      child: Text(
        'Quién usa tus datos: el equipo de Brota (proyecto escolar, BUAP).\n\n'
        'Qué datos: correo, nombre, fecha de nacimiento, tu ánimo y energía '
        'diarios, las actividades que completas y tus contactos de confianza.\n\n'
        'Para qué: mostrar tu progreso, ajustar la dificultad de tus misiones y '
        'que el botón S.O.S. funcione. El modelo de riesgo no diagnostica '
        'ninguna condición de salud.\n\n'
        'Dónde se guardan: cifrados en tu dispositivo. Si conectas un servidor, '
        'viajan por HTTPS y se guardan cifrados; la contraseña solo se guarda '
        'como hash. Tus contactos de confianza y el uso del S.O.S. nunca salen '
        'del dispositivo.\n\n'
        'Lo que nunca hacemos: vender datos, mostrar tu nombre en la comunidad '
        'ni compararte con otras personas.\n\n'
        'Menores de 18 años: se necesita el consentimiento de madre, padre o '
        'tutor. Menores de 13 años no pueden registrarse.\n\n'
        'Tus derechos: puedes exportar tu historial en PDF, cerrar sesión o '
        'borrar la app y sus datos cuando quieras.',
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Entendido'),
      ),
    ],
  ),
);

/// «25122000» → «25-12-2000»: solo dígitos y los guiones se ponen solos.
class _FormatoFecha extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final digitos = nuevo.text.replaceAll(RegExp(r'\D'), '');
    final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) b.write('-');
      b.write(d[i]);
    }
    final texto = b.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// «25-12-2000» (o con / o .) → «2000-12-25». Vacío si no es una fecha real.
String fechaIsoDesde(String texto) {
  final m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(
    texto.trim(),
  );
  if (m == null) return '';
  final dia = int.parse(m[1]!), mes = int.parse(m[2]!), anio = int.parse(m[3]!);
  final f = DateTime(anio, mes, dia);
  if (f.year != anio || f.month != mes || f.day != dia) return '';
  return claveDia(f);
}

/// «2000-12-25» → «25-12-2000».
String fechaParaMostrar(String iso) {
  final f = DateTime.tryParse(iso);
  if (f == null) return iso;
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}-${dos(f.month)}-${f.year}';
}
