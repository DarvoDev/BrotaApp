import 'package:flutter/material.dart';

import 'screens/animo_sheet.dart';
import 'screens/inicio.dart';
import 'screens/jardin.dart';
import 'screens/mas.dart';
import 'screens/rachas.dart';
import 'screens/sos.dart';
import 'services/almacen.dart';
import 'services/credenciales.dart';
import 'services/notificaciones.dart';
import 'state/brota_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final estado = BrotaState(
    almacen: AlmacenPrefs(),
    notificador: NotificadorLocal(),
    credenciales: CredencialesSeguras(),
  );
  await estado.iniciar();
  runApp(BrotaApp(estado: estado));
}

/// Da acceso al estado desde cualquier pantalla y la redibuja cuando cambia.
class BrotaScope extends InheritedNotifier<BrotaState> {
  const BrotaScope({
    super.key,
    required BrotaState estado,
    required super.child,
  }) : super(notifier: estado);

  static BrotaState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrotaScope>()!.notifier!;

  /// Lee el estado sin suscribirse: se puede usar en initState() y callbacks.
  static BrotaState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BrotaScope>()!.notifier!;
}

class BrotaApp extends StatelessWidget {
  const BrotaApp({super.key, required this.estado});

  final BrotaState estado;

  @override
  Widget build(BuildContext context) => BrotaScope(
    estado: estado,
    child: MaterialApp(
      title: 'Brota',
      debugShowCheckedModeBanner: false,
      theme: temaBrota(Brightness.light),
      darkTheme: temaBrota(Brightness.dark),
      home: const Principal(),
    ),
  );
}

class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> with WidgetsBindingObserver {
  static const _sos = 4;
  int _pestana = 0;
  bool _preguntando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _chequeoDelDia());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app quedó abierta de un día para otro, al volver se cierra el
    // día anterior y se pide el chequeo del nuevo.
    if (state == AppLifecycleState.resumed) _chequeoDelDia();
  }

  /// CU-05, paso 1: primera apertura del día.
  Future<void> _chequeoDelDia() async {
    if (!mounted || _preguntando) return;
    final estado = BrotaScope.of(context);
    await estado.abrirDia();
    if (!mounted || !estado.debePreguntarAnimo) return;
    _preguntando = true;
    final guardo = await mostrarChequeoAnimo(context);
    _preguntando = false;
    if (!guardo) await estado.omitirAnimo();
  }

  void _ir(int i) => setState(() => _pestana = i);

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    final pantalla = switch (_pestana) {
      0 => InicioScreen(irASos: () => _ir(_sos)),
      1 => const JardinScreen(),
      2 => const RachasScreen(),
      3 => const MasScreen(),
      _ => SosScreen(irAInicio: () => _ir(0)),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: pantalla,
          ),
        ),
      ),
      // El botón SOS está visible en todas las pantallas (CU-13, precondición 1).
      floatingActionButton: _pestana == _sos
          ? null
          : FloatingActionButton(
              onPressed: () => _ir(_sos),
              backgroundColor: e.error,
              foregroundColor: e.onError,
              shape: const CircleBorder(),
              tooltip: 'Ayuda inmediata',
              child: const Text(
                'S.O.S',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: _ir,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park),
            label: 'Jardín',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Rachas',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
          NavigationDestination(
            icon: Icon(Icons.sos_outlined),
            selectedIcon: Icon(Icons.sos),
            label: 'S.O.S',
          ),
        ],
      ),
    );
  }
}
