# Plan: siguientes funciones de Pergamino

Estado de partida (última versión en `main`): biblioteca con importación múltiple y
selección para borrar, lector de scroll continuo, subrayados y notas, marcadores,
búsqueda, tipografía en vivo, reloj opcional, barra de progreso con scroll rápido y
lectura en voz alta frase a frase (Piper y voces del sistema).

Cada función se puede activar o desactivar por separado. Cada fase termina con tests,
`flutter analyze` limpio y una instalación en el teléfono antes de pasar a la siguiente.

---

## Fase 0: panel «Funciones» (base de todo)

**Objetivo:** cada función nueva tiene su interruptor propio, para usar solo lo que
quieras y no ver botones que no usas.

- Enum `Feature` con una entrada por función: `clockExtras`, `backup`, `sleepTimer`,
  `libraryFilters`, `timeLeft`, `notesExport`, `voiceSkip`, `stats`, `gestures`, `paginated`.
- Estado guardado en `SharedPreferences` como un mapa `feature → bool`, en un nuevo
  `lib/data/features.dart`, con un provider igual que `settingsProvider`.
- Pantalla «Funciones» en la biblioteca (icono de ajustes). Cada fila tiene el nombre,
  una frase corta y un interruptor. Las funciones que dependen de otra (p. ej. «Gestos»
  con «Modo paginado») muestran el aviso «Requiere…».
- Cada función, al desactivarse, oculta su botón, su menú y su franja, pero **no borra datos**.
  Así puedes apagar la estadística y reactivarla sin perder el historial.
- Los valores por defecto se muestran en la fase 0 y se pueden cambiar (ver al final).

## Fase 1: reloj con batería y progreso

**Objetivo:** la franja superior muestra más datos, como el Kindle.

- Batería con `battery_plus`, actualizada al cambiar de minuto o cuando cambia el nivel,
  sin bucles.
- Progreso del libro (`_progress`) y capítulo actual (`_chapterIndexOf`).
- Ajustes en `ReaderSettings`: `clockItems` con `hora`, `batería`, `progreso`, `capítulo`.
  Cada elemento se activa con un chip en la hoja de tipografía.
- Archivos: `reader_clock.dart`, `reader_page.dart`, `settings.dart`, `typography_sheet.dart`.
- Tests: formato de batería (`87 %`), progreso y capítulo en la franja, ajustes en JSON.

## Fase 2: copia de seguridad en el dispositivo

**Objetivo:** guardar y restaurar todo en un archivo en tu teléfono, sin nube.

- Guarda `Pergamino-AAAA-MM-DD.pergamino` en la carpeta que elijas con el selector de
  Android (por defecto Descargas). El archivo es un ZIP con `backup.json` (ajustes,
  marcadores, subrayados, notas, progreso) y la carpeta `books/` con los `.md`.
- Restaurar: selector de archivos. Si un libro ya existe (mismo id o mismo título y
  tamaño), no se duplica. Marcadores y subrayados se fusionan por `id`.
- Versión del formato en `backup.json`. Si no coincide, se avisa y no se cambia nada.
- Opción «Copia automática semanal» dentro de la misma función. Guarda en la última
  carpeta usada y conserva solo las 3 más recientes.
- Aviso al exportar: el archivo contiene el texto de tus libros.
- Archivos: nuevo `lib/data/backup.dart`; menú «⋮» en `library_page.dart`.
- Tests: ida y vuelta (exportar → borrar todo → restaurar → mismos datos); versión
  desconocida se rechaza sin tocar nada; fusión sin duplicados; se conservan solo 3 copias.

## Fase 3: temporizador de sueño

**Objetivo:** la voz se detiene sola a los 15, 30, 45 o 60 minutos, o al terminar el capítulo.

- Icono de luna en el reproductor (`_Player`). Muestra la cuenta atrás `mm:ss` mientras
  está activo y se puede cancelar.
- En `read_aloud.dart`: al llegar al límite, la frase actual termina antes de parar,
  para no cortar una palabra.
- «Fin de capítulo»: se detiene al empezar el siguiente encabezado `#`/`##`.
- Tests con reloj inyectable: se detiene en el tiempo previsto y en el bloque correcto.

## Fase 4: ordenar y filtrar la biblioteca

- Orden: título A–Z, último leído, progreso, fecha de importación. Se recuerda la elección.
- Filtros: «Todos», «Leyendo» (1–99 %), «Sin empezar», «Terminados» (98 % o más).
- Un libro se puede marcar como terminado a mano desde la selección.
- Archivos: `library_page.dart`, `book_repository.dart`.
- Tests: cada filtro sobre una lista de ejemplo; el orden por título ignora mayúsculas y acentos.

## Fase 5: progreso por capítulo y tiempo restante

- Barra fina bajo cada capítulo en la hoja de capítulos (`reader_menu_sheet.dart`).
- Tiempo restante: palabras que faltan dividido entre tu velocidad. La velocidad se mide
  mientras lees y empieza en 220 palabras por minuto. Se muestra en la franja como «quedan ~35 min».
- Archivos: `reader_menu_sheet.dart`, `reader_clock.dart`, nuevo `lib/domain/reading_stats.dart`.
- Tests: estimación con datos conocidos; sin división entre cero al empezar un libro.

## Fase 6: exportar notas a Markdown y buscarlas

- Botón «Guardar como .md» en la pestaña «Notas». Usa `exportHighlights`, que ya existe
  en `highlights.dart`, y abre el diálogo para elegir dónde guardar.
- Campo de búsqueda encima de la lista de notas, que ignora acentos.
- Tests: el archivo sale con capítulos, citas y notas en orden; la búsqueda ignora acentos.

## Fase 7: saltar bloques en la voz

- Interruptores: «Leer tablas», «Leer código» (desactivados por defecto) y «Leer notas al pie»
  (activado por defecto).
- Se filtran los bloques antes de partirlos en frases, en `read_aloud.dart`, usando `blockParts`.
- Tests: con cada interruptor, el texto leído incluye o excluye el bloque correcto.

## Fase 8: estadísticas de lectura

**Objetivo:** saber cuánto lees, cuándo y qué libros, sin enviar nada fuera del teléfono.

- **Qué se registra:** sesiones con fecha, libro, minutos activos y palabras leídas
  (estimadas por el progreso). Se guarda en `stats.json` dentro de la app.
- **Qué cuenta como lectura:** solo el tiempo con el libro abierto y con actividad
  (scroll, toque o voz). Si pasan 2 minutos sin nada, la sesión se pausa. Se pausa
  también al salir de la app.
- **Qué se muestra** (pantalla «Estadísticas» desde la biblioteca):
  - Hoy, esta semana y este mes: minutos y palabras.
  - Racha de días seguidos.
  - Gráfica de barras de los últimos 14 días (con `fl_chart` o el mismo estilo del proyecto).
  - Libro más leído y tiempo por libro.
  - Tu velocidad real en palabras por minuto.
- **Meta diaria** opcional (por ejemplo 20 minutos). Se muestra en la pantalla de inicio de estadísticas.
- **Privacidad:** con la función desactivada no se registra nada nuevo. «Borrar estadísticas»
  está en la misma pantalla, con confirmación.
- Archivos: nuevo `lib/data/stats_repository.dart`, `lib/features/stats/stats_page.dart`,
  cambios en `reader_page.dart` para avisar de la actividad.
- Tests: minutos de hoy con una sesión que cruza la medianoche; pausa tras 2 minutos sin
  actividad; racha con días saltados; borrar deja todo en cero.

## Fase 9: gestos configurables

**Objetivo:** cada zona de la pantalla hace lo que tú quieras.

- Zonas: izquierda, centro y derecha, cada una con una acción:
  - **Sin acción**
  - **Mostrar / ocultar controles**
  - **Desplazar** hacia arriba o abajo (una pantalla)
  - **Página anterior / siguiente** (solo con modo paginado)
  - **Reproducir / pausar voz**
  - **Ajustar brillo** (arrastrar)
- Pantalla «Gestos» con una lista de zonas y un selector por zona. Hay un botón de
  «Restablecer» y una vista previa en miniatura con la zona resaltada al tocarla.
- Las zonas solo reaccionan a toques sencillos, así no interfieren con la selección
  de texto para subrayar.
- Archivos: `reader_page.dart` (un `GestureZones` que lee la configuración), nuevo
  `lib/features/reader/gesture_settings.dart`.
- Tests: cada acción se dispara en la zona correcta; el toque en el centro sigue
  mostrando controles con la configuración por defecto.

## Fase 10: modo paginado

**Objetivo:** leer por páginas, como un libro, además del scroll continuo.

Es la parte más difícil. El scroll se puede seguir usando; el modo paginado es una opción aparte.

- **Cómo se calculan las páginas:** cada bloque se mide con el mismo estilo y el mismo
  ancho que se usará en pantalla. Se llena una página hasta el alto disponible. Si un
  bloque no cabe, se parte en palabras con `TextPainter` (no se corta una palabra).
- **Caché:** las páginas se guardan por combinación de tamaño de fuente, interlineado,
  fuente, márgenes, ancho, alto y orientación. Se recalculan solo cuando cambia alguna.
- **Navegación:** `PageView` horizontal con animación, más las zonas de la fase 9.
- **Posición:** se guarda como índice de bloque y desplazamiento dentro del bloque. Así
  sobrevive a cambios de fuente. El progreso sigue siendo un porcentaje de bloques.
- **Voz y resaltado:** la frase que se lee cambia de página sola, como ya pasa con el scroll.
- **Subrayados y notas:** siguen funcionando, porque cada página usa el mismo `BlockCtx`.
- **Tablas e imágenes:** una tabla que no cabe en la página pasa a la siguiente entera.
  Si es más alta que la pantalla, se desplaza dentro de su página.
- **Prototipo antes de terminar:** primero se hace solo el cálculo de páginas con un libro
  de 1 MB y se mide el tiempo en el S24 Ultra. Si tarda más de 300 ms por capítulo, se
  revisa antes de seguir.
- Archivos: nuevo `lib/features/reader/pagination.dart`, nuevo `paged_reader.dart`,
  cambios en `reader_page.dart` y `settings.dart` (`readingMode: scroll | paginated`).
- Tests: el mismo libro y el mismo tamaño dan siempre las mismas páginas; al cambiar la
  fuente, la posición sigue apuntando al mismo párrafo; un bloque más alto que la página
  se parte sin perder palabras.

---

## Valores por defecto propuestos

| Función | Por defecto |
|---|---|
| Reloj con batería y progreso | Activada |
| Copia de seguridad (manual) | Activada |
| Copia automática semanal | Desactivada |
| Temporizador de sueño | Activada |
| Ordenar y filtrar | Activada |
| Progreso por capítulo y tiempo restante | Activada |
| Exportar notas a `.md` | Activada |
| Saltar bloques en la voz | Activada (solo notas al pie) |
| Estadísticas | Desactivada |
| Gestos configurables | Desactivada |
| Modo paginado | Desactivada |

## Decisiones pendientes

1. ¿Te sirven esos valores por defecto, o quieres cambiar alguno?
2. ¿Activamos las estadísticas por defecto o las dejamos apagadas hasta que las quieras?

## Verificación general

- `flutter analyze` y `flutter test` limpios en cada fase.
- Instalar la versión release en el teléfono (`flutter build apk --release --target-platform android-arm64`)
  y probar la función nueva en un libro de prueba.
- Probar primero en la variante «Pergamino Dev», sin tocar la biblioteca real.
- Cada fase se sube a `main` solo cuando la pruebes en tu teléfono.
