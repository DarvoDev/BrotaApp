import 'package:flutter/material.dart';

import '../main.dart';
import '../models/modelos.dart';
import '../state/brota_state.dart';
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

/// Pestaña «Más»: puerta de entrada al resto de casos de uso (CU-01 a CU-19).
class MasScreen extends StatelessWidget {
  const MasScreen({super.key});

  void _abrir(BuildContext context, Widget destino) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destino));
  }

  Future<void> _sincronizar(BuildContext context, BrotaState estado) async {
    await estado.sincronizar();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Todo está al día en este dispositivo')),
    );
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
                          estado.hayCambiosPendientes
                              ? '$pendientes cambio(s) por confirmar'
                              : 'Todo está al día en este dispositivo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus datos se guardan cifrados aquí. Sincronizar solo confirma '
                    'los cambios locales: no hay servidor ni copias en la nube.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  BarraProgreso(estado.xpEnNivel / xpPorNivel),
                  const SizedBox(height: 6),
                  Text(
                    'Nivel ${estado.nivel} · ${estado.xpEnNivel}/$xpPorNivel Exp',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _sincronizar(context, estado),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sincronizar ahora'),
                  ),
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
                    subtitulo: 'Muro anónimo local (CU-14)',
                    alTocar: () => _abrir(context, const ComunidadScreen()),
                  ),
                  _Entrada(
                    icono: Icons.admin_panel_settings_outlined,
                    titulo: 'Administración',
                    subtitulo: 'Catálogo y contenidos (CU-18/CU-19)',
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
