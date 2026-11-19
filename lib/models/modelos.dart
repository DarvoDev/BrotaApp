// Modelo de dominio de Brota.
// Sigue el diagrama de clases v1 (Equipo1_DiagramaClases_v1): mismos nombres
// de clases, atributos y operaciones, en la medida que los cinco casos de uso
// implementados los necesitan.

/// XP necesaria para subir un nivel (igual que el prototipo HTML: 100 Exp).
const int xpPorNivel = 100;

/// Congelamientos ("escudos") por semana. Propuesta de la Fase 2, CU-10.
const int congelamientosPorSemana = 2;

/// Rol de la cuenta: el administrador mantiene catálogo y mensajes (CU-18/19).
enum Rol { usuario, administrador }

extension NombreRol on Rol {
  String get texto =>
      this == Rol.administrador ? 'Administrador' : 'Usuario';
}

// ---------------------------------------------------------------- fechas ---

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime sumarDias(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Clave 'aaaa-mm-dd' con la que se guarda todo lo que pertenece a un día.
String claveDia(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime diaDeClave(String c) {
  final p = c.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime lunesDe(DateTime d) => sumarDias(soloDia(d), -(d.weekday - 1));

// ----------------------------------------------------------- actividades ---

/// Actividad (abstracta): algo que el Usuario puede completar para ganar XP.
abstract class Actividad {
  Actividad({required this.id, required this.titulo, required this.esfuerzo});

  final String id;
  final String titulo;

  /// Nivel de esfuerzo: 1 ligero, 2 medio, 3 alto.
  final int esfuerzo;

  int calcularXP();
}

/// Actividad física ligera y gradual del catálogo predefinido (RF-05).
class Microactividad extends Actividad {
  Microactividad({
    required super.id,
    required super.titulo,
    required super.esfuerzo,
    required this.duracionMin,
  });

  final int duracionMin;

  @override
  int calcularXP() => 5 + 5 * esfuerzo; // 10, 15, 20

  Microactividad copiaCon({
    String? tituloNuevo,
    int? esfuerzoNuevo,
    int? duracionNueva,
  }) => Microactividad(
    id: id,
    titulo: tituloNuevo ?? titulo,
    esfuerzo: esfuerzoNuevo ?? esfuerzo,
    duracionMin: duracionNueva ?? duracionMin,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'esfuerzo': esfuerzo,
    'duracionMin': duracionMin,
  };

  factory Microactividad.fromJson(Map<String, dynamic> j) => Microactividad(
    id: j['id'] as String,
    titulo: j['titulo'] as String,
    esfuerzo: j['esfuerzo'] as int,
    duracionMin: j['duracionMin'] as int,
  );
}

/// Hábito o rutina creada por el Usuario (RF-06, CU-07).
class TareaPersonalizada extends Actividad {
  TareaPersonalizada({
    required super.id,
    required super.titulo,
    required super.esfuerzo,
    required this.categoria,
  });

  final String categoria;

  @override
  int calcularXP() => 10 * esfuerzo; // 10, 20, 30

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'esfuerzo': esfuerzo,
    'categoria': categoria,
  };

  factory TareaPersonalizada.fromJson(Map<String, dynamic> j) =>
      TareaPersonalizada(
        id: j['id'] as String,
        titulo: j['titulo'] as String,
        esfuerzo: j['esfuerzo'] as int,
        categoria: j['categoria'] as String,
      );
}

const List<String> categoriasTarea = [
  'Movimiento',
  'Autocuidado',
  'Estudio',
  'Hogar',
  'Social',
  'Otro',
];

const List<String> nombresEsfuerzo = ['Ligero', 'Medio', 'Alto'];

/// Clase de asociación Usuario–Actividad: una actividad completada un día.
class Cumplimiento {
  Cumplimiento({
    required this.dia,
    required this.actividadId,
    required this.titulo,
    required this.xpOtorgada,
  });

  final String dia;
  final String actividadId;
  final String titulo;
  final int xpOtorgada;

  Map<String, dynamic> toJson() => {
    'dia': dia,
    'actividadId': actividadId,
    'titulo': titulo,
    'xp': xpOtorgada,
  };

  factory Cumplimiento.fromJson(Map<String, dynamic> j) => Cumplimiento(
    dia: j['dia'] as String,
    actividadId: j['actividadId'] as String,
    titulo: j['titulo'] as String,
    xpOtorgada: j['xp'] as int,
  );
}

// ----------------------------------------------------------------- ánimo ---

/// Chequeo rápido del día (RF-04, CU-05).
class RegistroAnimo {
  RegistroAnimo({required this.dia, required this.animo, required this.energia})
    : assert(animo >= 1 && animo <= 5),
      assert(energia >= 1 && energia <= 3);

  final String dia;

  /// 1 (muy mal) a 5 (muy bien).
  final int animo;

  /// 1 (baja), 2 (media), 3 (alta).
  final int energia;

  /// Con ánimo o energía bajos el sistema propone metas más ligeras.
  bool esBajo() => animo <= 2 || energia == 1;

  bool esAlto() => animo >= 4 && energia == 3;

  Map<String, dynamic> toJson() => {
    'dia': dia,
    'animo': animo,
    'energia': energia,
  };

  factory RegistroAnimo.fromJson(Map<String, dynamic> j) => RegistroAnimo(
    dia: j['dia'] as String,
    animo: j['animo'] as int,
    energia: j['energia'] as int,
  );
}

const List<String> iconosAnimo = ['😞', '😕', '😐', '🙂', '😄'];
const List<String> nombresAnimo = ['Muy mal', 'Mal', 'Regular', 'Bien', 'Muy bien'];
const List<String> iconosEnergia = ['🪫', '🔋', '⚡'];
const List<String> nombresEnergia = ['Baja', 'Media', 'Alta'];

// ----------------------------------------------------------------- racha ---

/// Racha flexible con congelamientos (RF-09, CU-10).
class Racha {
  Racha({this.dias = 0, this.congelamientos = congelamientosPorSemana});

  int dias;
  int congelamientos;

  /// Consume un congelamiento si hay; la racha se conserva.
  bool aplicarCongelamiento() {
    if (congelamientos <= 0) return false;
    congelamientos--;
    return true;
  }

  void reiniciar() => dias = 0;

  Map<String, dynamic> toJson() => {
    'dias': dias,
    'congelamientos': congelamientos,
  };

  factory Racha.fromJson(Map<String, dynamic> j) => Racha(
    dias: j['dias'] as int,
    congelamientos: j['congelamientos'] as int,
  );
}

/// Resultado del cierre automático de uno o más días sin actividad.
/// Se muestra al abrir la app como mensaje sin culpa (CU-10, paso 6).
class MensajeCierre {
  MensajeCierre({
    required this.reiniciada,
    required this.escudosUsados,
    required this.rachaDias,
  });

  /// true: no quedaban congelamientos y la racha volvió a 0 (flujo A2).
  final bool reiniciada;
  final int escudosUsados;

  /// Días de racha que se conservaron (o que tenía antes de reiniciarse).
  final int rachaDias;

  Map<String, dynamic> toJson() => {
    'reiniciada': reiniciada,
    'escudosUsados': escudosUsados,
    'rachaDias': rachaDias,
  };

  factory MensajeCierre.fromJson(Map<String, dynamic> j) => MensajeCierre(
    reiniciada: j['reiniciada'] as bool,
    escudosUsados: j['escudosUsados'] as int,
    rachaDias: j['rachaDias'] as int,
  );
}

// ------------------------------------------------------------------- SOS ---

class ContactoConfianza {
  ContactoConfianza({required this.nombre, required this.telefono});

  final String nombre;
  final String telefono;

  Map<String, dynamic> toJson() => {'nombre': nombre, 'telefono': telefono};

  factory ContactoConfianza.fromJson(Map<String, dynamic> j) =>
      ContactoConfianza(
        nombre: j['nombre'] as String,
        telefono: j['telefono'] as String,
      );
}

/// Línea de atención o número de emergencia del directorio (RF-10).
/// El directorio fijo viene en catalogo.dart y el Administrador puede
/// ampliarlo en CU-19.
class RecursoAyuda {
  const RecursoAyuda({
    required this.nombre,
    required this.telefono,
    required this.descripcion,
    this.esEmergencia = false,
    this.id = '',
    this.categoria = 'Ayuda',
  });

  final String id;
  final String nombre;
  final String telefono;
  final String descripcion;
  final bool esEmergencia;
  final String categoria;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'descripcion': descripcion,
    'esEmergencia': esEmergencia,
    'categoria': categoria,
  };

  factory RecursoAyuda.fromJson(Map<String, dynamic> j) => RecursoAyuda(
    id: j['id'] as String? ?? '',
    nombre: j['nombre'] as String,
    telefono: j['telefono'] as String,
    descripcion: j['descripcion'] as String? ?? '',
    esEmergencia: j['esEmergencia'] as bool? ?? false,
    categoria: j['categoria'] as String? ?? 'Ayuda',
  );
}

/// Resultado de completar una actividad (CU-09, CU-09a, CU-09b).
class ResultadoCompletar {
  ResultadoCompletar({
    required this.xp,
    required this.subioNivel,
    required this.nivel,
  });

  final int xp;
  final bool subioNivel;
  final int nivel;
}

// ------------------------------------------------------- cuenta y perfil ---

/// Cuenta local (CU-01/CU-02). La contraseña nunca se guarda: solo su hash
/// con sal. `rol` distingue al Usuario del Administrador (CU-18/CU-19).
class Cuenta {
  Cuenta({
    required this.correo,
    required this.hash,
    required this.sal,
    required this.nombre,
    required this.apellidos,
    required this.fechaNac,
    this.rol = Rol.usuario,
  });

  final String correo;
  final String hash;
  final String sal;
  final String nombre;
  final String apellidos;
  final String fechaNac;
  final Rol rol;

  bool verificar(String password, String Function(String) hashear) =>
      hashear('$sal$password') == hash;

  Map<String, dynamic> toJson() => {
    'correo': correo,
    'hash': hash,
    'sal': sal,
    'nombre': nombre,
    'apellidos': apellidos,
    'fechaNac': fechaNac,
    'rol': rol.name,
  };

  factory Cuenta.fromJson(Map<String, dynamic> j) => Cuenta(
    correo: j['correo'] as String,
    hash: j['hash'] as String,
    sal: j['sal'] as String,
    nombre: j['nombre'] as String? ?? '',
    apellidos: j['apellidos'] as String? ?? '',
    fechaNac: j['fechaNac'] as String? ?? '',
    rol: Rol.values.firstWhere(
      (r) => r.name == j['rol'],
      orElse: () => Rol.usuario,
    ),
  );
}

// ----------------------------------------------------------- recordatorio ---

/// Aviso amable y configurable (CU-08). Se muestra al abrir la app: no
/// interrumpe y reduce su frecuencia cuando el usuario está de bajada.
class Recordatorio {
  Recordatorio({
    required this.id,
    required this.titulo,
    required this.horaMinutos,
    required this.diasSemana,
    this.activo = true,
  });

  final String id;
  final String titulo;
  final int horaMinutos;
  final List<int> diasSemana; // 1 = lunes ... 7 = domingo
  final bool activo;

  String get horaTexto =>
      '${'${horaMinutos ~/ 60}'.padLeft(2, '0')}:${'${horaMinutos % 60}'.padLeft(2, '0')}';

  bool aplicaHoy(DateTime dia) => diasSemana.contains(dia.weekday);

  Recordatorio copiaCon({
    String? tituloNuevo,
    int? horaNueva,
    List<int>? diasNuevos,
    bool? activoNuevo,
  }) => Recordatorio(
    id: id,
    titulo: tituloNuevo ?? titulo,
    horaMinutos: horaNueva ?? horaMinutos,
    diasSemana: diasNuevos ?? diasSemana,
    activo: activoNuevo ?? activo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'horaMinutos': horaMinutos,
    'diasSemana': diasSemana,
    'activo': activo,
  };

  factory Recordatorio.fromJson(Map<String, dynamic> j) => Recordatorio(
    id: j['id'] as String,
    titulo: j['titulo'] as String,
    horaMinutos: j['horaMinutos'] as int,
    diasSemana: ((j['diasSemana'] as List?) ?? []).cast<int>(),
    activo: j['activo'] as bool? ?? true,
  );
}

// ------------------------------------------------------------- mensajes ----

/// Mensaje de aliento revisado por el Administrador (CU-12, CU-19).
class MensajeValidado {
  const MensajeValidado({
    required this.id,
    required this.texto,
    required this.categoria,
    required this.validadoPor,
  });

  final String id;
  final String texto;
  final String categoria;
  final String validadoPor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'texto': texto,
    'categoria': categoria,
    'validadoPor': validadoPor,
  };

  factory MensajeValidado.fromJson(Map<String, dynamic> j) => MensajeValidado(
    id: j['id'] as String,
    texto: j['texto'] as String,
    categoria: j['categoria'] as String? ?? 'Aliento',
    validadoPor: j['validadoPor'] as String? ?? 'Equipo Brota',
  );
}

// ------------------------------------------------------------- comunidad ---

/// Mensaje anónimo de aliento (CU-14). Sin servidor: vive en el dispositivo,
/// por lo que es una comunidad simulada y sin exposición del usuario.
class Publicacion {
  const Publicacion({
    required this.id,
    required this.contenido,
    required this.fecha,
    this.autor = 'Alguien que también sigue',
    this.esLogro = false,
  });

  final String id;
  final String contenido;
  final String fecha;
  final String autor;
  final bool esLogro;

  Map<String, dynamic> toJson() => {
    'id': id,
    'contenido': contenido,
    'fecha': fecha,
    'autor': autor,
    'esLogro': esLogro,
  };

  factory Publicacion.fromJson(Map<String, dynamic> j) => Publicacion(
    id: j['id'] as String,
    contenido: j['contenido'] as String,
    fecha: j['fecha'] as String,
    autor: j['autor'] as String? ?? 'Alguien que también sigue',
    esLogro: j['esLogro'] as bool? ?? false,
  );
}

// --------------------------------------------------------- sincronización ---

/// Cambio local pendiente de subir cuando haya servidor (RNF-07).
class EntradaSincronizacion {
  EntradaSincronizacion({
    required this.id,
    required this.operacion,
    required this.fecha,
  });

  final String id;
  final String operacion;
  final String fecha;

  Map<String, dynamic> toJson() => {
    'id': id,
    'operacion': operacion,
    'fecha': fecha,
  };

  factory EntradaSincronizacion.fromJson(Map<String, dynamic> j) =>
      EntradaSincronizacion(
        id: j['id'] as String,
        operacion: j['operacion'] as String,
        fecha: j['fecha'] as String,
      );
}
