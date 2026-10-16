# Recorrido del código para estudiantes

Actualización V9: [experiencia accesible, respuestas escritas y papelera recuperable](accessible-experience.md). La tabla `SessionTrash` se añade sin modificar los modelos históricos.

Estado actual: **VoiceToRead 0.1.0 (1), esquema V8**. Los números de build de las secciones heredadas indican hitos del código base. Ver [A mi ritmo y favoritas](at-my-pace.md) y [entrega/verificación](pace-checkpoint.md). Las secciones con otros números describen etapas anteriores.

## Build 22: entrada de voz procesada

`AppSettings.reduceBackgroundNoise` → `SessionCoordinator.applyCapturePreferences` → `CaptionViewModel.reduceBackgroundNoise` → `AudioCapturing.configureNoiseReduction` → `AudioCaptureService.start`. La configuración se realiza antes de crear el tap y leer el formato. `CaptureOptionsView` muestra preferencia futura y estado actual; `CaptionScreen.quickPreferences` ofrece el filtro antes de empezar. Consulta [ruido](noise-reduction.md) para el orden de llamadas, AGC, rutas y limitaciones.

## Mapa build 20: idioma, iPad y lectura accesible

| Responsabilidad | Archivo / punto de entrada |
| --- | --- |
| Preferencias de idioma/papel/renglones, con valores iniciales seguros | `Models/AppSettings.swift`: CaptureLanguage, ReaderPaper, ReaderSurface, ReaderPaperOptions |
| Configurar reconocimiento antes del primer inicio | `ViewModels/SessionCoordinator.swift`: applyCapturePreferences / changeCaptureLanguage |
| Evitar cambios durante pausa/reanudación | `ViewModels/CaptionViewModel.swift`: configureLanguage / canChooseCaptureOptions |
| Idioma en los dos motores | `Services/Speech`: SpeechTranscribing, LegacySpeechBackend, LegacySpeechTranscriber, AppleSpeechTranscriber |
| Origen/destino y JSON antiguo | `Models/SessionTranslation.swift`: TranslationSnapshot, IncrementalTranslation, TranslatedSubtitles |
| Persistir idioma sin cambiar esquema V7 | `Persistence/TranscriptRepository.swift`: create / saveTranslation |
| Traducción en ambas direcciones | `UI/SessionTranslationView.swift`: TranslationJob, LiveSpanishView (nombre interno histórico) |
| Practicar idioma y voz de la sesión | `UI/EnglishLearningView.swift`, `UI/PronunciationPracticeView.swift` |
| Banner persistente, Reanudar y anuncio accesible | `UI/CaptionScreen.swift`: resumePanel / onChange(canResume) |
| Soporte nativo iPad | `project.pbxproj`: TARGETED_DEVICE_FAMILY; `App/Info.plist`: orientaciones iPad |

Los nombres persistidos `LearningExpression.english/spanish` y varios identificadores de pruebas se conservan para compatibilidad: significan frase original y nota/traducción en el otro idioma. No renombrar el esquema solo para traducir una etiqueta de interfaz.


Esta guía responde “¿dónde está?”, “¿qué recibe?” y “¿qué produce?”. Los comentarios `///` de las clases principales complementan estas explicaciones y se pueden consultar en Xcode. Los comentarios describen contratos y decisiones; no cambian el comportamiento.

## Mapa de responsabilidades

| Archivo | Qué hace y cómo conecta con el resto |
| --- | --- |
| [VoiceToReadApp](../VoiceToRead/App/VoiceToReadApp.swift) | Punto de entrada @main; crea la escena que contiene AppRootView |
| [AppRootView](../VoiceToRead/UI/AppRootView.swift) | Abre el almacén, crea el coordinador, conecta pestañas y cambios de foreground/background; muestra error recuperable si no abre la base |
| [CaptionScreen](../VoiceToRead/UI/CaptionScreen.swift) | Presenta lectura, controles, fullscreen, opciones y seguimiento; conserva la posición al releer |
| [CaptionViewModel](../VoiceToRead/ViewModels/CaptionViewModel.swift) | Permisos, readiness, máquina de estados, consumo del stream y generación para ignorar respuestas obsoletas |
| [SessionCoordinator](../VoiceToRead/ViewModels/SessionCoordinator.swift) | Conecta eventos del ViewModel con persistencia, grabación, marcadores y vigilancia de espacio |
| [SpeechTranscribing](../VoiceToRead/Services/Speech/SpeechTranscribing.swift) | Contrato que permite intercambiar motor real y test doble |
| [LegacySpeechTranscriber](../VoiceToRead/Services/Speech/LegacySpeechTranscriber.swift) | Rotación de solicitudes, cola pendiente y desplazamiento temporal |
| [LegacySpeechBackend](../VoiceToRead/Services/Speech/LegacySpeechBackend.swift) | Adaptador de SFSpeechRecognizer con reconocimiento local obligatorio |
| [AppleSpeechTranscriber](../VoiceToRead/Services/Speech/AppleSpeechTranscriber.swift) | Activos de inglés, SpeechAnalyzer, tareas de entradas/resultados y tiempos del motor moderno |
| [AudioConversion](../VoiceToRead/Services/Speech/AudioConversion.swift) | Actor que conserva AVAudioConverter y adapta buffers al formato que pide Speech |
| [AudioCaptureService](../VoiceToRead/Services/Audio/AudioCaptureService.swift) | Configura AVAudioSession, selecciona micrófono integrado, copia buffers y entrega nivel/audio |
| [CapturedAudio](../VoiceToRead/Services/Audio/CapturedAudio.swift) | Copia de audio de solo lectura y posición opcional en el reloj de sesión |
| [SessionAudioRecorder](../VoiceToRead/Services/Audio/SessionAudioRecorder.swift) | Cola limitada, CAF, errores de escritura y reloj de muestras CaptureTimeline |
| [TranscriptAssembler](../VoiceToRead/Models/TranscriptAssembler.swift) | Convierte revisiones del reconocimiento en cambios de párrafos finales |
| [TranscriptRepository](../VoiceToRead/Persistence/TranscriptRepository.swift) | SwiftData, migraciones, upserts, correcciones, rutas de audio y borrado |
| [SessionMedia](../VoiceToRead/Models/SessionMedia.swift) | SessionMedia V4, marca SessionDraft V5 y estructuras de tiempos |
| [TranscriptReview](../VoiceToRead/Models/TranscriptReview.swift) | Texto corregido, historial Undo/Redo y búsqueda literal |
| [TranscriptEditorView](../VoiceToRead/UI/TranscriptEditorView.swift) | Borrador de edición, confirmación de descarte y guardado explícito |
| [TranscriptShareView](../VoiceToRead/UI/TranscriptShareView.swift) | Vista previa común antes de copiar o exportar TXT/PDF |
| [SessionMediaView](../VoiceToRead/UI/SessionMediaView.swift) | Reproducción, cues activos, edición, exportación temporal y limpieza |
| [SubtitleExport](../VoiceToRead/Utilities/SubtitleExport.swift) | Cues y serialización SRT/WebVTT, sin acceder al micrófono ni a SwiftData |

## Seguir Start, Pause y Stop

En CaptionViewModel.start, identifica los guard que rechazan estados incompatibles. Después de cada await relevante se vuelve a comprobar la generación. La operación pudo cambiar mientras estaba suspendida.

El coordinador instala onWillStart: crea una sesión persistida con marca de borrador y prepara el archivo si se eligió grabación. onFinalized aplica únicamente cambios finales. onCheckpoint guarda duración. onEnded conserva el borrador al terminar. Solo saveCurrent/publicar quita la marca SessionDraft; discardCurrent finaliza y borra. newSession rechaza limpiar un borrador sin decisión. Esos callbacks separan reconocimiento y almacenamiento.

Pause/Stop finalizan el reconocimiento cuando corresponde; cancel sirve para abortar. No son intercambiables: cancelar puede descartar texto provisional. Resume usa una nueva identidad de ejecución. El archivo de audio puede seguir abierto entre pausas, pero Stop lo cierra.

## Seguir una revisión de texto

TranscriptAssembler.apply recibe TranscriptionUpdate y devuelve FinalizedChange:

- removedIDs identifica filas que dejaron de representar el resultado.
- upserted contiene párrafos nuevos o actualizados. Un upsert inserta si no existe y actualiza si existe.
- Dos resultados se comparan por runID e intervalo, no por igualdad de palabras.
- Se conserva el UUID cuando se reemplaza un tramo para evitar recrear su identidad en la interfaz.
- runOrder conserva el orden de ejecuciones aunque llegue tarde una corrección de una ejecución anterior.

TranscriptRepository.apply transforma ese cambio en filas persistentes. Reintentar un guardado con las mismas identidades no debe duplicar el texto. Solo almacena tiempos de subtítulos cuando el segmento declara que usa el reloj de sesión.

## Seguir una corrección del usuario

TranscriptReview.paragraphs resuelve originales más correcciones. EditHistory mantiene valor actual, pasado y futuro; limita el pasado a 100 snapshots. Una nueva edición limpia el futuro de Redo.

TranscriptSearch escapa la consulta para que sea literal. Usa NSRange/NSString en UTF-16, coherente con NSRegularExpression. No mezclar esos offsets directamente con índices de String de Swift, especialmente con emoji. En reemplazos múltiples importa el orden para no desplazar los rangos pendientes.

El repositorio valida que los párrafos editados sigan perteneciendo a la sesión. Guardar la corrección no sobrescribe el reconocimiento original. Las distintas pantallas y exportadores deben resolver el mismo mapa.

## Seguir la creación de subtítulos

1. SessionMedia guarda un diccionario JSON: UUID de párrafo → CaptionTiming.
2. SubtitleExport.cues recibe ReviewParagraph corregidos y ese diccionario.
3. Valida los rangos y divide texto/palabras. Conserva tiempos nativos cuando coinciden; estima posiciones cuando cambió el texto.
4. Agrupa por longitud aproximada, hasta 5 segundos y cortes de silencio mayores de 0.8 segundos.
5. Ordena, redondea a milisegundos y recorta contra el siguiente cue. Descarta los de duración no positiva.
6. render produce texto SRT o WebVTT escapando caracteres de marcado.

Los límites ayudan a la legibilidad; no constituyen una certificación de estándares profesionales de subtitulado. Las pruebas incluyen correcciones, silencios, formato y ausencia de tiempos inventados para sesiones antiguas.

## Seguir un archivo compartido

SessionMediaView.prepareExport crea un directorio temporal único. RecordingExport.m4a usa AVAssetExportSession sobre el CAF, y el resto de archivos usa el texto revisado y los cues. MediaActivityView conecta SwiftUI con UIActivityViewController.

La tarea comprueba cancelación. cleanup borra los temporales al cerrar/cancelar; no borra la grabación original. El destino elegido por el usuario puede subir archivos a Internet, aunque VoiceToRead no tenga un cliente de red propio.

## Límites de concurrencia que debes respetar

- UI, coordinador y contexto SwiftData: MainActor.
- Conversión moderna: actor AudioConversion.
- Grabación: cola serial con límite de bloques pendientes.
- Reloj de muestras: acceso protegido con NSLock.
- Buffer copiado: contrato de solo lectura, no protección mágica por Sendable.
- Callbacks de un motor antiguo: se descartan mediante generación.

Build 11 dejó advertencias de Sendable en AudioConversion y RecordingExport. Están registradas en [incidentes](build-incidents.md). No cambiar a Swift 6 language mode ni añadir @unchecked Sendable o @preconcurrency solo para ocultarlas sin revisar la propiedad de los objetos y ejecutar pruebas.

## Qué probar cuando cambias una pieza

| Cambio | Evidencia pertinente |
| --- | --- |
| Revisión parcial/final y orden | TranscriptAssemblerTests |
| Ciclo de escucha y opciones de fondo | CaptionViewModelTests / LegacySpeechTranscriberTests |
| Migración, correcciones y borrado | TranscriptRepositoryTests / SessionMediaTests |
| Texto revisado y búsqueda | TranscriptExportTests |
| Audio, reloj y subtítulos | SessionMediaTests; AudioConversionTests con herramientas modernas |
| Fullscreen, lectura y reproductor | HomeScreenTests y revisión visual en ambas orientaciones |
| Firma o distribución | Registros de archive/export/upload; una prueba de UI no valida certificados |

El [plan de pruebas](testing.md) distingue los escenarios automatizados de los que requieren un iPhone.

## Capture/review changes in build 15

- `AudioCapturing.onLevel` → both speech engines → `CaptionViewModel.inputLevel`: optional MainActor callback, throttled for display; cleared on pause/stop/interruption.
- `CaptionViewModel.canResume` and `CaptionScreen`: contextual manual recovery action; no automatic restart.
- `SessionTitle` in SessionClock.swift → SessionCoordinator → optional inline title binding in CaptionScreen: local suggestion, trimmed name, fallback and length limit.
- `SessionDetailView` → paragraph UUID → `SessionMediaView.initialParagraphID` → cue start → `SessionPlayer.play(from:)`: audio review without guessing old timestamps.
- `CaptionScreen.pinchScale`: transient magnification; AppSettings persists the clamped final size.

## Traducción guardada (build 16)

`Models/SessionTranslation.swift` contiene el snapshot, la tabla V6 y la transformación pura de subtítulos. `TranscriptRepository.saveTranslation` rechaza IDs incompletos y texto de origen cambiado. `UI/SessionTranslationView.swift` adapta Translation de Apple a la pantalla de lectura y mantiene la cancelación por UUID de intento. `TranscriptEditorView` se reutiliza con etiquetas españolas de edición, sin guardar sobre las correcciones inglesas. [Guía completa](translation.md).


## Build 17: revisar traducciones sin perder trabajo

Consulta [la guía funcional](translation.md) y [el punto de reanudación](implementation-checkpoint.md).
Un UUID identifica un párrafo, pero no garantiza que sus palabras sigan iguales. Por eso
`IncrementalTranslation` compara UUID y texto: reutiliza traducción/correcciones solo cuando ambos coinciden.
Construye el resultado completo en memoria y lo guarda al final; cancelar nunca guarda «media traducción».
La búsqueda incluye solo español vigente, para no enviar al usuario a un texto obsoleto.
`PersonalVocabulary` separa frases libres y términos literales: traduce las primeras y conserva los últimos;
por eso es importante revisar la gramática. El diccionario es una preferencia, no una nueva tabla de la base.
`LiveTranslationBuffer` separa captura de presentación: limita memoria, evita peticiones paralelas y comprueba
que cada respuesta siga correspondiendo al texto solicitado. Volver al inglés elimina únicamente la vista previa.
La exportación espera a que cierre la hoja de revisión antes de abrir la hoja de compartir del sistema.


## Aprender inglés — build 18

Escucha/repite fragmentos a 0.75× o 1×, revela el español y conserva expresiones con contexto/audio. Capture Preferences ahora tiene un solo icono. Consulta [la guía de aprendizaje](learning.md) para uso, arquitectura V7 y límites.


## Pronunciación local (build 19)

`PronunciationPracticeView.swift` contiene PracticeRecognition (texto y peticiones locales), PracticeFiles (temporales protegidos), PronunciationPractice (estado y audio) y la vista de tres pasos. Consulta [el recorrido explicado](pronunciation.md). VoiceToReadApp limpia intentos abandonados al iniciar; EnglishLearningView detiene su reproducción antes de abrir la práctica.


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).

## Build 23: recorrido de lectura pausada

`SessionDetailView` → `SessionMediaView` → `PlaybackParagraph.make` → `SessionPlayer.select(range:)` → `scheduleSegment`. Al finalizar, el reproductor conserva el extremo final y la vista conserva el UUID seleccionado; Repetir vuelve a su inicio y Siguiente exige una acción explícita.

Corrección: `beginParagraphEdit` pausa → `ParagraphEditorView` modifica un borrador con Undo/Redo → `saveParagraph` verifica que el párrafo todavía corresponde al texto almacenado → `saveCorrections` o `saveTranslation` persiste → `rebuildCues` actualiza lectura/exportación. No se reescribe el CAF.

Protección: botón o swipe → `setFavorite` → fila única V8. Borrado de sesión o audio → `requireUnprotected` antes de cualquier efecto. Para quitar protección se confirma primero; borrar conserva su propia confirmación posterior. Los datos antiguos no se convierten automáticamente en favoritos.

## Marcadores visibles y reproducción bilingüe

[Guía de uso y desarrollo](bookmarks-and-bilingual-playback.md): un selector para leer y escuchar, original seguido de traducción, escucha directa en cada párrafo y marcadores compartidos por UUID. Incluye explicación paso a paso para estudiantes y límites de las pruebas.
