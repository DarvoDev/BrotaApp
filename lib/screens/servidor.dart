import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

/// Servidor opcional (arquitectura de tres capas: app → API REST → base de
/// datos). Conecta la cuenta local con Backend-Brota para sincronizar sin
/// duplicados (RNF-07), usar el compañero fantasma real y el muro compartido.
class ServidorScreen extends StatefulWidget {
  const ServidorScreen({super.key});

  @override
  State<ServidorScreen> createState() => _ServidorScreenState();
}

class _ServidorScreenState extends State<ServidorScreen> {
  final _url = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    final estado = BrotaScope.of(context);
    _url.text = estado.servidorUrl.isEmpty
        ? 'http://10.0.2.2:8000'
        : estado.servidorUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _conectar() async {
    setState(() {
      _cargando = true;
      _mensaje = null;
    });
    final error = await BrotaScope.of(
      context,
    ).conectarServidor(_url.text, _password.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _mensaje = error ?? 'Conectado. Tus cambios se enviarán solos 🌱';
    });
    _password.clear();
  }

  Future<void> _sincronizar() async {
    setState(() => _cargando = true);
    final r = await BrotaScope.of(context).sincronizar();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _mensaje = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Servidor y sincronización')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            Text(
              'Brota funciona completa sin internet. Si conectas el servidor '
              'del equipo, tus datos se respaldan cifrados y puedes ver a otras '
              'personas reales en el compañero fantasma y el muro.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Tarjeta(
              color: e.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estado.conectado ? 'Conectado a ${estado.servidorUrl}' : 'Sin servidor conectado',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${estado.cambiosPendientes.length} cambio(s) pendientes'
                    '${estado.ultimaSincronizacion == null ? '' : ' · última vez ${estado.ultimaSincronizacion!.substring(0, 16).replaceFirst('T', ' ')}'}',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!estado.tieneCuenta)
              Tarjeta(
                child: Text(
                  'Primero crea tu cuenta en «Mi perfil». Se usa el mismo correo '
                  'y contraseña en el servidor.',
                  style: TextStyle(color: e.onSurfaceVariant),
                ),
              )
            else if (!estado.conectado)
              Tarjeta(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Dirección del servidor',
                        helperText: 'Emulador: http://10.0.2.2:8000 · producción: https://…',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de ${estado.cuenta!.correo}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _cargando ? null : _conectar,
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                      label: const Text('Conectar'),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _cargando ? null : _sincronizar,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sincronizar ahora'),
                  ),
                  OutlinedButton(
                    onPressed: _cargando ? null : estado.desconectarServidor,
                    child: const Text('Desconectar'),
                  ),
                ],
              ),
            if (_mensaje != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_mensaje!)),
            ],
            const SizedBox(height: 16),
            Text(
              'Seguridad: la sesión usa un token JWT; la contraseña viaja solo '
              'para iniciar sesión y el servidor guarda únicamente su hash. Tu '
              'ánimo se guarda cifrado. Tus contactos de confianza y el uso del '
              'S.O.S. nunca salen del dispositivo.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
