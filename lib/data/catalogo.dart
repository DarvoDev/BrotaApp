import '../models/modelos.dart';

/// CatalogoMicroactividades (RF-05): actividades físicas ligeras y graduales.
/// En el producto final lo mantiene el Administrador (CU-18); aquí va incluido
/// en la app para que funcione sin conexión.
class CatalogoMicroactividades {
  static final List<Microactividad> todas = [
    Microactividad(id: 'm-agua', titulo: 'Tomar un vaso de agua', esfuerzo: 1, duracionMin: 1),
    Microactividad(id: 'm-respirar', titulo: 'Respirar profundo 1 minuto', esfuerzo: 1, duracionMin: 1),
    Microactividad(id: 'm-estirar', titulo: 'Estirar brazos y cuello', esfuerzo: 1, duracionMin: 2),
    Microactividad(id: 'm-ventana', titulo: 'Abrir la ventana y sentir el aire', esfuerzo: 1, duracionMin: 1),
    Microactividad(id: 'm-pie', titulo: 'Ponerte de pie y dar unos pasos', esfuerzo: 1, duracionMin: 2),
    Microactividad(id: 'm-caminar10', titulo: 'Caminar 10 minutos', esfuerzo: 2, duracionMin: 10),
    Microactividad(id: 'm-estiramientos', titulo: 'Estiramientos suaves 5 minutos', esfuerzo: 2, duracionMin: 5),
    Microactividad(id: 'm-ordenar', titulo: 'Ordenar un rincón pequeño', esfuerzo: 2, duracionMin: 5),
    Microactividad(id: 'm-escaleras', titulo: 'Subir y bajar escaleras una vez', esfuerzo: 2, duracionMin: 3),
    Microactividad(id: 'm-caminar20', titulo: 'Caminar 20 minutos al aire libre', esfuerzo: 3, duracionMin: 20),
    Microactividad(id: 'm-rutina', titulo: 'Rutina de movimiento de 15 minutos', esfuerzo: 3, duracionMin: 15),
    Microactividad(id: 'm-bailar', titulo: 'Bailar tres canciones', esfuerzo: 3, duracionMin: 10),
  ];

  static List<Microactividad> buscar(int esfuerzo) =>
      todas.where((m) => m.esfuerzo == esfuerzo).toList();

  static Microactividad? porId(String id) {
    for (final m in todas) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Directorio fijo de ayuda (RF-10). La emergencia va siempre primero
/// (CU-13, flujo A4). Disponible sin conexión (RNF-03).
const List<RecursoAyuda> recursosAyuda = [
  RecursoAyuda(
    nombre: 'Emergencias 911',
    telefono: '911',
    descripcion: 'Si tú o alguien más está en peligro ahora',
    esEmergencia: true,
  ),
  RecursoAyuda(
    nombre: 'Línea de la Vida',
    telefono: '8009112000',
    descripcion: 'Atención psicológica gratuita, 24 horas · 800 911 2000',
  ),
];

/// Mensaje predefinido que se envía al contacto de confianza (CU-13, paso 5).
const String mensajeSos =
    'Hola, no me estoy sintiendo bien y me vendría bien hablar contigo. '
    '¿Puedes llamarme cuando veas esto?';

/// Frases del prototipo HTML (pantalla Rachas).
const List<String> frasesMotivacionales = [
  'Un pasito a la vez también es avanzar 🌱',
  'Hoy estás haciendo lo mejor que puedes 💛',
  'Descansar también cuenta 🌙',
  'Qué bueno que sigues aquí ✨',
];
