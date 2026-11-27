import '../models/modelos.dart';

/// CatalogoMicroactividades (RF-05): actividades físicas ligeras y graduales.
/// En el producto final lo mantiene el Administrador (CU-18); aquí va incluido
/// en la app para que funcione sin conexión.
class CatalogoMicroactividades {
  static final List<Microactividad> todas = [
    Microactividad(
      id: 'm-agua',
      titulo: 'Tomar un vaso de agua',
      esfuerzo: 1,
      duracionMin: 1,
    ),
    Microactividad(
      id: 'm-respirar',
      titulo: 'Respirar profundo 1 minuto',
      esfuerzo: 1,
      duracionMin: 1,
    ),
    Microactividad(
      id: 'm-estirar',
      titulo: 'Estirar brazos y cuello',
      esfuerzo: 1,
      duracionMin: 2,
    ),
    Microactividad(
      id: 'm-ventana',
      titulo: 'Abrir la ventana y sentir el aire',
      esfuerzo: 1,
      duracionMin: 1,
    ),
    Microactividad(
      id: 'm-pie',
      titulo: 'Ponerte de pie y dar unos pasos',
      esfuerzo: 1,
      duracionMin: 2,
    ),
    Microactividad(
      id: 'm-caminar10',
      titulo: 'Caminar 10 minutos',
      esfuerzo: 2,
      duracionMin: 10,
    ),
    Microactividad(
      id: 'm-estiramientos',
      titulo: 'Estiramientos suaves 5 minutos',
      esfuerzo: 2,
      duracionMin: 5,
    ),
    Microactividad(
      id: 'm-ordenar',
      titulo: 'Ordenar un rincón pequeño',
      esfuerzo: 2,
      duracionMin: 5,
    ),
    Microactividad(
      id: 'm-escaleras',
      titulo: 'Subir y bajar escaleras una vez',
      esfuerzo: 2,
      duracionMin: 3,
    ),
    Microactividad(
      id: 'm-caminar20',
      titulo: 'Caminar 20 minutos al aire libre',
      esfuerzo: 3,
      duracionMin: 20,
    ),
    Microactividad(
      id: 'm-rutina',
      titulo: 'Rutina de movimiento de 15 minutos',
      esfuerzo: 3,
      duracionMin: 15,
    ),
    Microactividad(
      id: 'm-bailar',
      titulo: 'Bailar tres canciones',
      esfuerzo: 3,
      duracionMin: 10,
    ),
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
    id: 'r-911',
    nombre: 'Emergencias 911',
    telefono: '911',
    descripcion: 'Si tú o alguien más está en peligro ahora',
    esEmergencia: true,
    categoria: 'Emergencia',
  ),
  RecursoAyuda(
    id: 'r-vida',
    nombre: 'Línea de la Vida',
    telefono: '8009112000',
    descripcion: 'Atención psicológica gratuita, 24 horas · 800 911 2000',
    categoria: 'Apoyo psicológico',
  ),
  RecursoAyuda(
    id: 'r-salud',
    nombre: 'Servicio de Salud Mental (SSM)',
    telefono: '8005019000',
    descripcion: 'Orientación y servicios de salud mental en México',
    categoria: 'Apoyo psicológico',
  ),
];

/// Mensaje predefinido que se envía al contacto de confianza (CU-13, paso 5).
const String mensajeSos =
    'Hola, no me estoy sintiendo bien y me vendría bien hablar contigo. '
    '¿Puedes llamarme cuando veas esto?';

// ------------------------------------------- mensajes motivacionales ----
//
// Criterio del equipo: los mensajes motivan de manera IMPLÍCITA. Describen
// lo que pasó (un paso, un descanso, el jardín que crece) en lugar de dar
// órdenes («¡tienes que…!») o evaluar a la persona («¡eres increíble!»).
// Todos pasan el diccionario de palabras clave como «motivadora» y con
// estilo «implícito» (ver test/clasificador_test.dart).

/// Frases cortas de la pantalla Rachas.
const List<String> frasesMotivacionales = [
  'Cada paso pequeño suma, aunque hoy no se note 🌱',
  'Descansar también cuenta 🌙',
  'Tu jardín crece a tu ritmo ✨',
  'Volver ya es avanzar 💛',
];

/// Mensajes validados que alimentan CU-12 y que CU-19 puede administrar.
const List<MensajeValidado> mensajesPorDefecto = [
  MensajeValidado(
    id: 'msg-1',
    texto: 'Cada paso pequeño suma, aunque hoy no se note 🌱',
    categoria: 'Aliento',
    validadoPor: 'Equipo Brota',
  ),
  MensajeValidado(
    id: 'msg-2',
    texto: 'Descansar también cuenta. Tu progreso sigue aquí 🌙',
    categoria: 'Descanso',
    validadoPor: 'Equipo Brota',
  ),
  MensajeValidado(
    id: 'msg-3',
    texto: 'No tienes que hacerlo perfecto; empezar ya cambió el día 💛',
    categoria: 'Aliento',
    validadoPor: 'Equipo Brota',
  ),
  MensajeValidado(
    id: 'msg-4',
    texto: 'Pedir ayuda es un paso valiente, no una debilidad ✨',
    categoria: 'Ayuda',
    validadoPor: 'Equipo Brota',
  ),
  MensajeValidado(
    id: 'msg-5',
    texto: 'El jardín crece a tu ritmo, no al de nadie más 🌼',
    categoria: 'Aliento',
    validadoPor: 'Equipo Brota',
  ),
  MensajeValidado(
    id: 'msg-6',
    texto: 'Moverte un poco también es cuidarte 🚶',
    categoria: 'Movimiento',
    validadoPor: 'Equipo Brota',
  ),
];

/// Lo que «dice» la mascota según su estado: motivación implícita, sin
/// reproches. Nunca muere ni pierde nivel.
const Map<EstadoMascota, List<String>> frasesMascota = {
  EstadoMascota.feliz: [
    'Movió la cola cuando terminaste 🐾',
    'Se quedó tomando el sol en tu jardín ☀️',
    'Te trajo una hoja nueva 🍃',
  ],
  EstadoMascota.somnolienta: [
    'Está tomando una siesta. Despierta con cualquier pasito 💤',
    'Bostezó y se acomodó junto a las flores 🌙',
  ],
  EstadoMascota.triste: [
    'Te extrañaba. ¿Hacemos algo pequeño juntos? 🌱',
    'Guardó tu lugar en el jardín. Aquí sigue todo 💛',
  ],
};

/// Aviso implícito al completar una actividad (CU-09): cuenta lo que pasó en
/// el jardín en lugar de un «¡bien hecho!» genérico.
const List<String> avisosCompletar = [
  'Brotito estiró sus hojas',
  'Cayó una gota de rocío en tu jardín',
  'Una semilla nueva empezó a brotar',
  'El jardín se ve un poco más verde',
];

// --------------------------------------------- comunidad moderada --------

/// Frases predefinidas del muro (CU-14). No hay texto libre: así se evita
/// contenido dañino (riesgo «comunidad tóxica»). Todas son «motivadora».
const List<FraseMuro> frasesMuro = [
  FraseMuro(id: 'f-1', texto: 'Hoy di un paso pequeño 🌱'),
  FraseMuro(id: 'f-2', texto: 'Volví después de un descanso 💛'),
  FraseMuro(id: 'f-3', texto: 'Hoy me tomé un rato para descansar 🌙'),
  FraseMuro(id: 'f-4', texto: 'Si hoy cuesta, aquí seguimos juntos ✨'),
  FraseMuro(id: 'f-5', texto: 'Poco a poco también se avanza 🌼'),
  FraseMuro(id: 'f-6', texto: 'Respiré y lo intenté de nuevo 🍃'),
];

/// Publicaciones anónimas semilla del muro de aliento (CU-14).
const List<Publicacion> publicacionesPorDefecto = [
  Publicacion(
    id: 'pub-1',
    contenido: 'Hoy di un paso pequeño 🌱',
    fecha: '2026-11-10',
  ),
  Publicacion(
    id: 'pub-2',
    contenido: 'Volví después de un descanso 💛',
    fecha: '2026-11-11',
  ),
];

// ------------------------------------------------ tienda del jardín ------

/// Catálogo de la tienda (precios propuestos, por confirmar). Se paga con
/// semillas: 1 semilla por cada Exp ganada. Comprar no baja el nivel.
const List<Decoracion> decoracionesTienda = [
  Decoracion(id: 'd-tulipan', emoji: '🌷', nombre: 'Tulipán', precio: 20),
  Decoracion(id: 'd-girasol', emoji: '🌻', nombre: 'Girasol', precio: 25),
  Decoracion(id: 'd-hongo', emoji: '🍄', nombre: 'Hongo', precio: 30),
  Decoracion(
    id: 'd-piedra',
    emoji: '🪨',
    nombre: 'Piedra con musgo',
    precio: 30,
  ),
  Decoracion(id: 'd-mariposa', emoji: '🦋', nombre: 'Mariposa', precio: 40),
  Decoracion(id: 'd-nido', emoji: '🪺', nombre: 'Nido', precio: 45),
  Decoracion(id: 'd-banca', emoji: '🪑', nombre: 'Banca', precio: 60),
  Decoracion(id: 'd-farol', emoji: '🏮', nombre: 'Farol', precio: 70),
  Decoracion(id: 'd-fuente', emoji: '⛲', nombre: 'Fuente', precio: 80),
  Decoracion(id: 'd-arcoiris', emoji: '🌈', nombre: 'Arcoíris', precio: 120),
];

Decoracion? decoracionPorId(String id) {
  for (final d in decoracionesTienda) {
    if (d.id == id) return d;
  }
  return null;
}
