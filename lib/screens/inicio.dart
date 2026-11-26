import 'package:flutter/material.dart';

import '../data/catalogo.dart';
import '../main.dart';
import '../models/modelos.dart';
import '../state/brota_state.dart';
import '../theme.dart';
import 'animo_sheet.dart';
import 'nueva_tarea.dart';
import 'riesgo.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.irASos});

  final VoidCallback irASos;

  /// CU-09: completar (o desmarcar) una actividad y avisar la recompensa.
  void _alternar(BuildContext context, BrotaState estado, Actividad a) {
    final mensajes = ScaffoldMessenger.of(context);
    if (estado.completadaHoy(a)) {
      estado.desmarcarActividad(a);
      return;
    }
    final r = estado.completarActividad(a);
    if (r == null) return;
    // Motivación implícita: se cuenta lo que pasó en el jardín.
    final aviso = avisosCompletar[estado.cumplimientos.length % avisosCompletar.length];
    final String texto;
    if (r.subioNivel) {
      texto = 'Brotito creció al nivel ${r.nivel} 🎉';
    } else if (r.subioMascota) {
      texto = '${estado.mascotaNombre} creció al nivel ${r.nivelMascota} 🐾';
    } else {
      texto = '$aviso 🌿 +${r.xp} Exp';
    }
    mensajes
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(texto)),
      );
  }

  Future<void> _eliminar(
    BuildContext context,
    BrotaState estado,
    TareaPersonalizada t,
  ) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Quitar esta tarea?'),
        content: Text('«${t.titulo}» dejará de aparecer. La Exp que ya ganaste se queda contigo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitar tarea')),
        ],
      ),
    );
    if (si == true) await estado.eliminarTarea(t);
  }

  @override
  Widget build(BuildContext context) {
    final estado = BrotaScope.of(context);
    final e = Theme.of(context).colorScheme;
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? 'Buenos días'
        : hora < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    final cierre = estado.mensajeCierre;
    final animo = estado.animoDeHoy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
      children: [
        Text(saludo, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(estado.mensajeDelDia, style: TextStyle(color: e.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Dato(
                icono: Image.asset(
                  'lib/assets/images/Racha.gif',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                valor: estado.racha.dias == 1 ? '1 día' : '${estado.racha.dias} días',
                detalle: 'de racha',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Dato(
                icono: Image.asset(
                  'lib/assets/images/Escudo.jpg',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                valor: estado.racha.congelamientos == 1
                    ? '1 escudo'
                    : '${estado.racha.congelamientos} escudos',
                detalle: 'se renuevan el lunes',
              ),
            ),
          ],
        ),
        if (estado.falloGuardado) ...[
          const SizedBox(height: 12),
          Tarjeta(
            child: Text(
              'No pude guardar en este dispositivo. Puedes seguir usando la app; '
              'lo intento de nuevo con tu siguiente cambio.',
              style: TextStyle(color: e.onSurfaceVariant),
            ),
          ),
        ],
        if (cierre != null) ...[
          const SizedBox(height: 12),
          _AvisoCierre(cierre: cierre, estado: estado),
        ],
        if (estado.riesgoAltoHoy) ...[
          const SizedBox(height: 12),
          _AvisoRiesgo(estado: estado),
        ],
        if (estado.reaccionesNuevas.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ReaccionesRecibidas(estado: estado),
        ],
        if (estado.sugerirRecursos) ...[
          const SizedBox(height: 12),
          Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Han sido días pesados 💛',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No tienes que cargarlo a solas. Hay personas que pueden escucharte, gratis y a cualquier hora.',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: irASos,
                  child: const Text('Ver líneas de ayuda'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Tarjeta(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Text(
                animo == null ? '🌤️' : iconosAnimo[animo.animo - 1],
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  animo == null
                      ? '¿Cómo te sientes hoy?'
                      : 'Hoy: ${nombresAnimo[animo.animo - 1].toLowerCase()} · energía ${nombresEnergia[animo.energia - 1].toLowerCase()}',
                ),
              ),
              TextButton(
                onPressed: () => mostrarChequeoAnimo(context),
                child: Text(animo == null ? 'Registrar' : 'Cambiar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Tarjeta(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  emojiBrotito(estado.nivel),
                  key: ValueKey(emojiBrotito(estado.nivel)),
                  style: const TextStyle(fontSize: 76),
                ),
              ),
              Text(
                'Brotito · Nivel ${estado.nivel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              BarraProgreso(estado.xpEnNivel / xpPorNivel),
              const SizedBox(height: 6),
              Text(
                '${estado.xpEnNivel} / $xpPorNivel Exp',
                style: TextStyle(color: e.onSurfaceVariant, fontSize: 14),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    emojiMascota(estado.mascota, estado.estadoMascota),
                    style: const TextStyle(fontSize: 30),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${estado.mascotaNombre} · Nivel ${estado.nivelMascota}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          estado.fraseMascota,
                          style: TextStyle(color: e.onSurfaceVariant, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CompaneroFantasma(estado: estado),
        const TituloSeccion('Misiones de hoy'),
        Tarjeta(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              for (final m in estado.metasHoy)
                _FilaActividad(
                  actividad: m,
                  detalle: '${m.duracionMin} min',
                  hecha: estado.completadaHoy(m),
                  alTocar: () => _alternar(context, estado, m),
                ),
            ],
          ),
        ),
        TituloSeccion(
          'Tus tareas',
          accion: TextButton.icon(
            onPressed: () => mostrarNuevaTarea(context),
            icon: const Icon(Icons.add),
            label: const Text('Nueva tarea'),
          ),
        ),
        Tarjeta(
          padding: estado.tareas.isEmpty
              ? const EdgeInsets.all(14)
              : const EdgeInsets.symmetric(horizontal: 4),
          child: estado.tareas.isEmpty
              ? Text(
                  'Aquí van tus propios hábitos. Agrega el primero con «Nueva tarea».',
                  style: TextStyle(color: e.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final t in estado.tareas)
                      _FilaActividad(
                        actividad: t,
                        detalle: '${t.categoria} · ${nombresEsfuerzo[t.esfuerzo - 1].toLowerCase()}',
                        hecha: estado.completadaHoy(t),
                        alTocar: () => _alternar(context, estado, t),
                        alEliminar: () => _eliminar(context, estado, t),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.valor, required this.detalle});

  final Widget icono;
  final String valor;
  final String detalle;

  @override
  Widget build(BuildContext context) => Tarjeta(
    child: Row(
      children: [
        icono,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(
                detalle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// CU-10, paso 6: mensaje sin culpa tras uno o más días de descanso.
class _AvisoCierre extends StatelessWidget {
  const _AvisoCierre({required this.cierre, required this.estado});

  final MensajeCierre cierre;
  final BrotaState estado;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    final String texto;
    if (cierre.reiniciada) {
      final r = estado.proximaRenovacion;
      texto =
          'Tu racha empieza de nuevo, y está bien. Tu nivel, tu Exp y Brotito '
          'siguen exactamente igual. Tus escudos se renuevan el lunes ${r.day}/${r.month}.';
    } else {
      final escudos = cierre.escudosUsados == 1
          ? 'Usé 1 escudo'
          : 'Usé ${cierre.escudosUsados} escudos';
      final dias = cierre.rachaDias == 1 ? '1 día' : '${cierre.rachaDias} días';
      texto = '$escudos y tu racha de $dias sigue a salvo. No perdiste nada.';
    }
    return Tarjeta(
      color: e.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descansar también cuenta 🌙',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(texto),
          const SizedBox(height: 4),
          const Text('Si hoy te nace, abajo hay una misión ligera esperándote.'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: estado.descartarMensajeCierre,
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaActividad extends StatelessWidget {
  const _FilaActividad({
    required this.actividad,
    required this.detalle,
    required this.hecha,
    required this.alTocar,
    this.alEliminar,
  });

  final Actividad actividad;
  final String detalle;
  final bool hecha;
  final VoidCallback alTocar;
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(value: hecha, onChanged: (_) => alTocar()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actividad.titulo,
                    style: TextStyle(
                      decoration: hecha ? TextDecoration.lineThrough : null,
                      color: hecha ? e.onSurfaceVariant : null,
                    ),
                  ),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 12.5, color: e.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 8, right: alEliminar == null ? 12 : 0),
              child: Text(
                '+${actividad.calcularXP()} Exp',
                style: TextStyle(fontSize: 13.5, color: e.onSurfaceVariant),
              ),
            ),
            if (alEliminar != null)
              IconButton(
                onPressed: alEliminar,
                tooltip: 'Quitar tarea',
                icon: Icon(Icons.close, size: 20, color: e.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}


/// Perceptrón: aviso amable cuando predijo riesgo ALTO para hoy (CU-20).
class _AvisoRiesgo extends StatelessWidget {
  const _AvisoRiesgo({required this.estado});

  final BrotaState estado;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Tarjeta(
      color: e.secondary.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hoy, misiones más ligeras 🌤️',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Por cómo han ido tus últimos días, Brota preparó misiones cortas '
            'para que tu racha y tu mascota estén a salvo. Si te nace más, el '
            'catálogo sigue abierto.',
          ),
          const SizedBox(height: 4),
          Text(
            'No es un diagnóstico: solo ajusta la dificultad dentro de la app.',
            style: TextStyle(color: e.onSurfaceVariant, fontSize: 12.5),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RiesgoScreen()),
              ),
              child: const Text('¿Cómo lo decide?'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reacciones que llegaron del compañero fantasma.
class _ReaccionesRecibidas extends StatelessWidget {
  const _ReaccionesRecibidas({required this.estado});

  final BrotaState estado;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    final nuevas = estado.reaccionesNuevas;
    final simulada = nuevas.any((i) => i.simulada);
    return Tarjeta(
      color: e.primaryContainer,
      child: Row(
        children: [
          const Text('💌', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in nuevas)
                  Text(
                    'Alguien te mandó: ${reaccionesFantasma[i.reaccion] ?? i.reaccion}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (simulada)
                  Text(
                    'Señal de ejemplo: sin servidor conectado.',
                    style: TextStyle(color: e.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: estado.marcarReaccionesVistas,
            child: const Text('Gracias'),
          ),
        ],
      ),
    );
  }
}

/// Compañero fantasma anónimo: no es un chat, solo señales y reacciones
/// predefinidas, sin perfiles ni comparación.
class _CompaneroFantasma extends StatelessWidget {
  const _CompaneroFantasma({required this.estado});

  final BrotaState estado;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    final senales = estado.senalesFantasma;
    if (senales.isEmpty) {
      return Tarjeta(
        child: Row(
          children: [
            const Text('🌍', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cuando alguien en el mundo complete su misión, te aviso aquí.',
                style: TextStyle(color: e.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    final s = senales.first;
    final hace = s.haceMinutos < 60
        ? 'hace ${s.haceMinutos} min'
        : 'hace ${s.haceMinutos ~/ 60} h';
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌍', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alguien en el mundo completó su misión de hoy · $hace',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final r in reaccionesFantasma.entries)
                ActionChip(
                  label: Text(r.value),
                  onPressed: () async {
                    await estado.reaccionarASenal(s, r.key);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text('Enviaste «${r.value}» 💚')),
                      );
                  },
                ),
            ],
          ),
          if (senales.length > 1 || s.simulada) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (senales.length > 1) '${senales.length - 1} persona(s) más también avanzaron hoy.',
                if (s.simulada) 'Señales de ejemplo: sin servidor conectado.',
              ].join(' '),
              style: TextStyle(color: e.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
