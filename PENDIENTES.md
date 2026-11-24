# Brota — Pendientes para alinear la app con el planteamiento

Revisión del 23/11/2026 de la app (`brota_app`, commit `ec12964` del 18/11/2026) contra:

- `Arquitectura de proyecto.pdf` (Fase 1: RF-01..16, RNF-01..07)
- `Equipo1_Fase2_Modelado.pdf` (actores, CU-01..19)
- `Modelo E-R Brota.pdf`
- `Protocolo_metrica.docx`
- `Documentación.docx` (19/11/2026)

**Estado actual:** RF-01..16 y CU-01..19 implementados; `flutter analyze` sin problemas; 31 pruebas pasan. Los pendientes son diferencias con lo que describe la documentación, no errores del código.

> Los valores marcados como **(propuesta)** no están en la documentación y deben confirmarse con el equipo.

## Estado al 23/11/2026 (versión 1.1.0)

| # | Pendiente | Estado |
|---|---|---|
| 1 | Perceptrón de riesgo | ✅ `lib/logic/perceptron.dart`, CU-20, pantalla «Cómo decide Brota» |
| 2 | Compañero fantasma | ✅ Real con servidor; señales de ejemplo marcadas como tales sin servidor |
| 3 | Moderación | ✅ Solo frases predefinidas, «Reportar», revisión del Administrador (CU-23/24) |
| 4 | Escudos | ✅ 1 por semana |
| 5 | Tienda del jardín | ✅ Semillas separadas de la XP, 10 decoraciones |
| 6 | Estados de la mascota | ✅ Feliz / somnolienta (1 día) / triste (2+ días) |
| 7 | Edad y privacidad | ✅ Fecha obligatoria, < 13 bloqueado, 13–17 con consentimiento, aviso de privacidad. **Decisión:** > 35 solo se avisa |
| 8 | Servidor | ✅ **Opción a):** [Backend-Brota](https://github.com/DarvoDev/Backend-Brota) (FastAPI + PostgreSQL + Caddy HTTPS en Docker), JWT, sync con UUID sin duplicados |
| 9 | Notificaciones e iOS | ✅ Notificaciones locales en Android. iOS queda como trabajo futuro (requiere Mac) |
| 10 | Detalles menores | ✅ Niveles separados (100/150), ícono, minSdk 26, «Copiar logro» |
| — | Planteamiento | ✅ Diccionario de palabras clave y mensajes implícitos (`docs/diccionario_motivacional.json`) |

Pruebas: 51 automáticas en verde + 1 de extremo a extremo contra el servidor en Docker (`test/e2e_backend_test.dart`).

---

## 1. Perceptrón predictor de riesgo de procrastinación

**Planteamiento:** `Documentación.docx` lo presenta como el elemento innovador y diferenciador principal: predice si mañana el riesgo de no cumplir la rutina es ALTO o BAJO y, si es ALTO, simplifica las misiones del día siguiente.
**App actual:** las metas se ajustan solo con reglas fijas (`_generarMetas` en `lib/state/brota_state.dart`); el README dice "Sin IA".

**Arreglo:**
- Nueva clase `PerceptronRiesgo` en Dart puro (sin librerías ni internet): suma ponderada de entradas + sesgo → ALTO o BAJO.
- Entradas (las que lista la documentación):
  - % de días con actividad en los últimos 7 días
  - hora promedio de cumplimiento
  - escudos usados en la semana
  - día de la semana
  - interacciones con el compañero fantasma
  - último ánimo y energía registrados
- Entrenamiento local con la regla de aprendizaje del perceptrón: cada día cerrado es un ejemplo (¿completó alguna actividad o no?). Mientras haya pocos datos se usan pesos iniciales fijos **(propuesta)**.
- Si el riesgo es ALTO: las metas de mañana se simplifican (solo esfuerzo ligero) y se muestra un aviso amable.
- El aviso incluye el límite ético: no diagnostica depresión ni ninguna condición, solo predice un patrón de conducta de corto plazo.
- Corregir el README ("Sin IA" deja de ser cierto).

## 2. Compañero fantasma anónimo

**Planteamiento:** no es un chat. La app avisa "alguien en el mundo completó su misión de hoy" y permite responder con reacciones predefinidas ("¡Bien hecho!", "¡Tú puedes!", "Sigue así"), que también se pueden recibir de vuelta. Sin perfiles públicos ni comparación.
**App actual:** no existe; la comunidad es un muro de texto libre.

**Arreglo:**
- Tarjeta en Inicio/Comunidad: "🌍 Alguien en el mundo completó su misión de hoy" con los 3 botones de reacción.
- Al completar metas, el usuario recibe reacciones de vuelta ("Alguien te mandó: ¡Tú puedes!").
- Sin servidor, los avisos los simula la app con horarios aleatorios. Documentarlo así en el código y en el README; no presentarlo como real.
- Las interacciones alimentan una de las entradas del perceptrón (punto 1).

## 3. Moderación de la comunidad

**Planteamiento (riesgos iniciales):** "Comunidad tóxica o con mensajes dañinos. Mitigación: moderación, reportes, mensajes predefinidos."
**App actual:** texto libre de hasta 240 caracteres, sin reportes ni filtro (`publicarAliento`).

**Arreglo:**
- El muro solo acepta mensajes de aliento elegidos de una lista predefinida.
- Botón "Reportar" en cada publicación: la oculta para el usuario y la manda a una lista de revisión en el panel de administrador.

## 4. Escudos por semana

**Planteamiento:** el usuario gana 1 corazón/escudo por semana.
**App actual:** `congelamientosPorSemana = 2` en `lib/models/modelos.dart` (era una propuesta de la Fase 2 que no se confirmó).

**Arreglo:** cambiar a 1 y ajustar las pruebas de CU-10.

## 5. Tienda del jardín

**Planteamiento:** la XP de cada hábito funciona como moneda para comprar artículos o mejoras del jardín.
**App actual:** se dejó fuera a propósito (comentario en `lib/screens/jardin.dart:10`).

**Arreglo:**
- Separar la XP total (define el nivel y nunca baja) de "semillas" gastables, que se ganan con la XP de cada actividad, para que comprar no baje el nivel.
- Catálogo de 8–10 decoraciones (flores, banca, fuente, etc.) que se colocan en el jardín. Precios **(propuesta)**.
- Todo se obtiene jugando: sin micropagos (restricción de la documentación).

## 6. Estados de ánimo de la mascota

**Planteamiento:** si el usuario no cumple sus hábitos, la mascota se ve triste o somnolienta, pero nunca muere ni retrocede de forma permanente.
**App actual:** la mascota siempre está feliz.

**Arreglo:**
- Feliz: completó algo hoy.
- Somnolienta: 1 día sin actividad **(propuesta)**.
- Triste: 2 o más días sin actividad **(propuesta)**.
- Nunca muere ni pierde nivel; los textos son siempre amables ("Te extrañaba, ¿hacemos algo pequeño?").

## 7. Edad, consentimiento y aviso de privacidad

**Planteamiento:** usuarios de 13 a 35 años; para menores, aviso de privacidad y consentimiento parental.
**App actual:** fecha de nacimiento opcional y sin validar; no hay aviso de privacidad ni consentimiento.

**Arreglo:**
- Fecha de nacimiento obligatoria al registrarse.
- Menores de 13 años: no pueden registrarse (mensaje respetuoso).
- Mayores de 35: bloquear o solo avisar **(por decidir)**.
- De 13 a 17 años: casilla obligatoria de consentimiento de madre, padre o tutor.
- Pantalla de aviso de privacidad para todos al registrarse.

## 8. Servidor (arquitectura de tres capas) — decisión del equipo

**Planteamiento:** cliente-servidor en tres capas con API REST, HTTPS y JWT; tecnologías previstas Flutter, Firebase y Python. RNF-07 pide sincronizar con el servidor al recuperar la conexión, sin duplicar registros.
**App actual:** todo es local; la "sincronización" es una cola sin servidor real (`sincronizar()`).

**Opciones:**
- a) Implementar un backend (por ejemplo Firebase, o una API en Python) con autenticación y sincronización real.
- b) Ajustar la documentación para indicar que el prototipo es solo local y que el servidor queda como trabajo futuro.

## 9. Plataformas y notificaciones — decisión del equipo

- **RF-07 / actor "Servicio de notificaciones":** los recordatorios solo aparecen al abrir la app; no hay notificaciones push. Arreglo posible: `flutter_local_notifications` (notificaciones locales en Android, sin servidor).
- **RNF-04 (iOS 13+):** no existe la carpeta `ios`. Se puede generar con Flutter, pero compilar y probar requiere una Mac. Alternativa: dejar iOS como trabajo futuro en la documentación.

## 10. Detalles menores

- **Niveles separados (RF-08):** el RF dice "subir de nivel al avatar y a la mascota"; la app usa un solo nivel compartido. Separar: avatar cada 100 XP, mascota cada 150 XP **(propuesta)**.
- **Ícono:** la app usa el ícono por defecto de Flutter; cambiarlo por `Equipo1_Brota_Logo.png` en Android y web.
- **Android 8+:** fijar `minSdk = 26` en `android/app/build.gradle.kts` (hoy usa `flutter.minSdkVersion`).
- **Texto:** el botón "Copiar/logro" de Comunidad debe decir "Copiar logro".

---

## Al terminar los arreglos

- [x] Pruebas nuevas para cada punto implementado.
- [x] `flutter analyze` sin problemas y `flutter test` en verde.
- [x] Actualizar `README.md` y `docs/Plan_de_Pruebas_Brota.docx`.
- [x] Reconstruir el APK: `docs/Brota-v1.1.0.apk`.
- [x] Un commit con los cambios.

## Valores por confirmar con el equipo

| Valor | Propuesta |
|---|---|
| Pesos iniciales del perceptrón | Fijos, definidos al implementarlo |
| Precios de la tienda | Por definir al implementarla |
| Días para mascota somnolienta / triste | 1 / 2 o más |
| XP por nivel de la mascota | 150 (avatar: 100) |
| Usuarios mayores de 35 años | Bloquear o solo avisar |
| Servidor (punto 8) | Implementar o dejar como trabajo futuro |
| Notificaciones e iOS (punto 9) | Implementar o dejar como trabajo futuro |
