import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../theme.dart';
import 'admin.dart';
import 'ayuda.dart';
import 'catalogo_screen.dart';
import 'comunidad.dart';
import 'motivacion.dart';
import 'perfil.dart';
import 'progreso.dart';
import 'recordatorios.dart';
import 'resumen.dart';
import 'riesgo.dart';

/// Pestaña «Más»: puerta de entrada al resto de casos de uso (CU-01 a CU-19).
class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  void _abrir(BuildContext context, Widget destino) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final pendientes = estado.cambiosPendientes.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Tarjeta(
              color: e.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          estado.conectado
                              ? (estado.hayCambiosPendientes
                                    ? 'Conectado · respaldando $pendientes cambio(s)…'
                                    : 'Conectado')
                              : 'Todo está guardado en este dispositivo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    estado.conectado
                        ? 'Tus datos se guardan cifrados aquí y se respaldan solos '
                              'en la nube cuando hay internet.'
                        : estado.cuenta == null && estado.respaldoDisponible
                        ? 'Crea tu cuenta o inicia sesión en «Mi perfil» y tu '
                              'progreso se respaldará solo.'
                        : 'Tus datos se guardan cifrados aquí.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  BarraProgreso(estado.xpEnNivel / xpPorNivel),
                  const SizedBox(height: 6),
                  Text(
                    'Nivel ${estado.nivel} · ${estado.xpEnNivel}/$xpPorNivel Exp',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                  if (estado.necesitaReconectar) ...[
                    const SizedBox(height: 12),
                    const _Reconectar(),
                  ],
                ],
              ),
            ),
            const TituloSeccion('Tu cuenta y tu camino'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  _Entrada(
                    icono: Icons.person_outline,
                    titulo: 'Mi perfil',
                    subtitulo: 'Cuenta, avatar y mascota (CU-01 a CU-04)',
                    alTocar: () => _abrir(context, PerfilScreen()),
                  ),
                  _Entrada(
                    icono: Icons.insights_outlined,
                    titulo: 'Panel de progreso',
                    subtitulo: 'Nivel, Exp, rachas y gráfico (CU-15)',
                    alTocar: () => _abrir(context, const ProgresoScreen()),
                  ),
                  _Entrada(
                    icono: Icons.calendar_month_outlined,
                    titulo: 'Resumen semanal',
                    subtitulo: 'Tu semana, sin juicios (CU-16)',
                    alTocar: () => _abrir(context, const ResumenScreen()),
                  ),
                  _Entrada(
                    icono: Icons.psychology_alt_outlined,
                    titulo: 'Cómo decide Brota',
                    subtitulo: 'Perceptrón de riesgo y sus pesos (CU-20)',
                    alTocar: () => _abrir(context, const RiesgoScreen()),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Herramientas para ti'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  _Entrada(
                    icono: Icons.auto_stories_outlined,
                    titulo: 'Explorar catálogo',
                    subtitulo: 'Microactividades para elegir (CU-06)',
                    alTocar: () => _abrir(context, CatalogoScreen()),
                  ),
                  _Entrada(
                    icono: Icons.notifications_none,
                    titulo: 'Recordatorios amables',
                    subtitulo: 'Avisos suaves, sin presión (CU-08)',
                    alTocar: () => _abrir(context, RecordatoriosScreen()),
                  ),
                  _Entrada(
                    icono: Icons.favorite_border,
                    titulo: 'Recursos de ayuda',
                    subtitulo: 'Líneas y contactos de confianza (CU-11)',
                    alTocar: () => _abrir(context, AyudaScreen()),
                  ),
                  _Entrada(
                    icono: Icons.chat_bubble_outline,
                    titulo: 'Mensajes motivacionales',
                    subtitulo: 'Alientos revisados para ti (CU-12)',
                    alTocar: () => _abrir(context, MotivacionScreen()),
                  ),
                ],
              ),
            ),
            const TituloSeccion('Comunidad y administración'),
            Tarjeta(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  _Entrada(
                    icono: Icons.people_outline,
                    titulo: 'Comunidad y aliento',
                    subtitulo: 'Muro anónimo y moderado (CU-14, CU-23)',
                    alTocar: () => _abrir(context, const ComunidadScreen()),
                  ),
                  _Entrada(
                    icono: Icons.admin_panel_settings_outlined,
                    titulo: 'Administración',
                    subtitulo:
                        'Catálogo, contenidos y reportes (CU-18, CU-19, CU-24)',
                    alTocar: () => _abrir(context, AdminScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Brota acompaña, pero no sustituye la atención profesional.',
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Solo aparece si el respaldo se desconectó (registro sin internet o sesión
/// vencida): con la contraseña una vez basta.
class _Reconectar extends StatefulWidget {
  const _Reconectar();

  @override
  State<_Reconectar> createState() => _ReconectarState();
}

class _ReconectarState extends State<_Reconectar> {
  final _password = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _reconectar() async {
    if (_cargando || _password.text.isEmpty) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    final error = await BrotaScope.of(context).reconectar(_password.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = error;
    });
    if (error == null) _password.clear();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Escribe tu contraseña para seguir respaldando tu progreso.',
        style: TextStyle(fontSize: 13),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _password,
              obscureText: true,
              onSubmitted: (_) => _reconectar(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                errorText: _error,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _cargando ? null : _reconectar,
            child: const Text('Listo'),
          ),
        ],
      ),
    ],
  );
}

class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icono, color: e.primary),
      title: Text(titulo),
      subtitle: Text(subtitulo, style: TextStyle(color: e.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, size: 20, color: e.onSurfaceVariant),
      onTap: alTocar,
    );
  }
}
