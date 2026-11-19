# Brota

Rutinas gamificadas que no castigan el fallo. App de hábitos para personas con procrastinación, aislamiento o depresión: Brotito, la planta-mascota, crece contigo, y si un día no puedes con nada, tu racha se protege sin culpa.

Proyecto de Proyectos I+D I (BUAP) — Equipo 1.

| Ánimo y metas | Completar actividad | Racha protegida | S.O.S. |
|---|---|---|---|
| ![](docs/capturas/cu05_3_metas_ajustadas.png) | ![](docs/capturas/cu09_1_completar_subir_nivel.png) | ![](docs/capturas/cu10_1_escudo_usado.png) | ![](docs/capturas/cu13_1_pantalla.png) |

## Sistema implementado (CU-01 a CU-19)

| CU | Nombre | RF |
|---|---|---|
| CU-01 | Registrarse (cuenta local, hash con sal y rol) | RF-01 |
| CU-02 | Iniciar sesión (modo invitado disponible) | RF-01 |
| CU-03 | Personalizar avatar | RF-02 |
| CU-04 | Elegir mascota de compañía y nombrarla | RF-03 |
| CU-05 / 05a | Registrar estado de ánimo diario / ajustar metas | RF-04 |
| CU-06 | Explorar catálogo de microactividades | RF-05 |
| CU-07 / 07a | Crear tarea personalizada (categoría y esfuerzo) | RF-06 |
| CU-08 | Configurar recordatorios amigables | RF-07 |
| CU-09 / 09a / 09b | Completar actividad, otorgar XP y subir de nivel | RF-08 |
| CU-10 | Proteger racha flexible (escudos semanales) | RF-09 |
| CU-11 | Consultar recursos de ayuda | RF-10 |
| CU-12 | Ver mensajes motivacionales | RF-11 |
| CU-13 | Botón S.O.S. emocional (911, Línea de la Vida, contactos) | RF-12 |
| CU-14 | Compartir logros y aliento (muro anónimo local) | RF-13 |
| CU-15 | Consultar panel de progreso | RF-14 |
| CU-16 | Ver resumen semanal | RF-15 |
| CU-17 | Exportar historial a PDF (≤ 2 MB) | RF-16 |
| CU-18 | Administrar catálogo de microactividades | RF-05 |
| CU-19 | Administrar mensajes validados y directorio de ayuda | RF-10, RF-11 |

## Características

- Funciona sin conexión: el estado se guarda **cifrado** en el dispositivo (`shared_preferences` + HMAC-SHA256).
- Android y web con un solo código Flutter.
- Sin IA: las metas se ajustan con reglas simples según ánimo y energía.
- Cola local de cambios pendientes de sincronización (RNF-07, sin servidor).
- PDF del historial generado localmente, sin dependencias externas.

## Estructura

```
lib/
  main.dart               arranque, navegación, botón S.O.S. global
  theme.dart              paleta y componentes
  models/modelos.dart     clases del dominio (diagrama de clases v1 + ampliaciones)
  data/catalogo.dart      catálogo, directorio de ayuda, mensajes y publicaciones
  state/brota_state.dart  lógica de los 19 casos de uso
  services/               almacen, cifrado y generación de PDF
  screens/                inicio, jardín, rachas, S.O.S., más, perfil,
                          catálogo, recordatorios, ayuda, motivación,
                          comunidad, progreso, resumen y administración
test/                     pruebas unitarias, de widget y de aceptación
docs/evidencias/          capturas de la ejecución de las pruebas
```

## Ejecutar

```
flutter pub get
flutter run -d chrome   # navegador
flutter run             # teléfono Android conectado
flutter test            # pruebas
```

> Brota acompaña, pero no sustituye la atención profesional. En una emergencia en México llama al 911 o a la Línea de la Vida: 800 911 2000.
