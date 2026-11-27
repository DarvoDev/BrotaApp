import 'package:flutter/material.dart';
import 'models/modelos.dart';

/// Paleta del prototipo «Brotito · App de apoyo emocional.html».
ThemeData temaBrota(Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  const principal = Color(0xFF5F9F84);
  final fondo = oscuro ? const Color(0xFF1C2421) : const Color(0xFFF4F1EA);
  final tarjeta = oscuro ? const Color(0xFF26312D) : Colors.white;
  final tinta = oscuro ? const Color(0xFFE8EFE9) : const Color(0xFF2D3A35);
  final suave = oscuro ? const Color(0xFFA2B1A9) : const Color(0xFF6B7A73);
  final principalSuave = oscuro
      ? const Color(0xFF2F4A3E)
      : const Color(0xFFDCEFE5);
  final linea = oscuro ? const Color(0xFF364540) : const Color(0xFFE4E0D6);

  final esquema = ColorScheme(
    brightness: brillo,
    primary: principal,
    onPrimary: Colors.white,
    primaryContainer: principalSuave,
    onPrimaryContainer: tinta,
    secondary: const Color(0xFFF2B872),
    onSecondary: const Color(0xFF2D3A35),
    error: const Color(0xFFD9534F),
    onError: Colors.white,
    surface: fondo,
    onSurface: tinta,
    onSurfaceVariant: suave,
    surfaceContainerLowest: tarjeta,
    surfaceContainer: tarjeta,
    surfaceContainerHigh: tarjeta,
    outline: suave,
    outlineVariant: linea,
  );

  return ThemeData(
    colorScheme: esquema,
    scaffoldBackgroundColor: fondo,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tarjeta,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: linea),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: linea),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tarjeta,
      indicatorColor: principalSuave,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Tarjeta del prototipo: fondo claro, borde fino y esquinas de 18 px.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.color, this.padding});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? e.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: e.outlineVariant),
      ),
      child: child,
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        ?accion,
      ],
    ),
  );
}

class BarraProgreso extends StatelessWidget {
  const BarraProgreso(this.valor, {super.key});

  final double valor;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: valor.clamp(0, 1)),
        duration: const Duration(milliseconds: 400),
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 14,
          backgroundColor: e.outlineVariant,
          color: e.primary,
        ),
      ),
    );
  }
}

/// Etapa de Brotito según el nivel (evolución visual, CU-09b).
String emojiBrotito(int nivel) {
  if (nivel <= 2) return '🌱';
  if (nivel <= 5) return '🪴';
  if (nivel <= 9) return '🌳';
  return '🌸';
}

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String fechaCorta(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

/// La mascota cambia de ánimo, pero nunca muere ni pierde nivel.
String emojiMascota(String mascota, EstadoMascota estado) => switch (estado) {
  EstadoMascota.feliz => mascota,
  EstadoMascota.somnolienta => '$mascota💤',
  EstadoMascota.triste => '$mascota💧',
};

/// Muestra una mascota guardada como emoji o como imagen de assets.
Widget widgetMascota(
  String mascota,
  EstadoMascota estado, {
  double tamano = 30,
}) {
  final esImagen = mascota.startsWith('lib/assets/');

  if (!esImagen) {
    return Text(
      emojiMascota(mascota, estado),
      style: TextStyle(fontSize: tamano),
    );
  }

  final indicador = switch (estado) {
    EstadoMascota.feliz => null,
    EstadoMascota.somnolienta => '💤',
    EstadoMascota.triste => '💧',
  };

  return SizedBox(
    width: tamano,
    height: tamano,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(
            mascota,
            width: tamano,
            height: tamano,
            fit: BoxFit.contain,
          ),
        ),
        if (indicador != null)
          Positioned(
            right: -tamano * 0.12,
            bottom: -tamano * 0.12,
            child: Text(indicador, style: TextStyle(fontSize: tamano * 0.38)),
          ),
      ],
    ),
  );
}
