# Reproducción unificada y traducción al detener

Actualización: 2026-10-15. La validación y distribución se anotan en el checkpoint; implementar no equivale a publicar.

## Experiencia de uso

VoiceToRead ofrece apoyo de lectura y escucha a personas con discapacidad auditiva o baja visión, personas que todavía no dominan el idioma y niños que practican acompañados por un adulto. Los controles deben poder entenderse sin depender del color o del sonido. No se promete precisión perfecta ni se sustituye la interpretación profesional.

- **Audio y subtítulos** es un único lector para audio original y voz traducida, también al entrar desde Traducción. Ambos usan los mismos tamaños, posición de controles y área de lectura. El original utiliza el archivo cuando existe y voz generada cuando falta el archivo o un rango válido en el modo por párrafo. La voz traducida necesita una traducción vigente y una voz disponible.
- **Leer y escuchar** elige original, traducción o ambos para texto y audio. Ambos reproduce original y luego traducción por párrafo; la velocidad Lenta/Normal/Rápida se configura aparte. Los idiomas se identifican mediante etiquetas y tarjetas; inglés azul, español verde con la paleta predeterminada. Los colores se personalizan en Ajustes → Colores por idioma; alto contraste tiene prioridad y el papel cambia el área exterior de las tarjetas.
- El botón central significa Reproducir, Pausar, Reanudar o Escuchar de nuevo según el estado. Se elimina el botón duplicado de repetición. Reiniciar párrafo queda en Opciones y selecciona su inicio sin reproducir.
- Anterior/Siguiente y la lista seleccionan silenciosamente. En **A mi ritmo**, Play reproduce solo el párrafo elegido, incluidos ambos idiomas cuando están seleccionados. **Continua** recorre los siguientes desde la posición seleccionada. Terminar conserva el último párrafo y su texto completo.
- Se muestra Párrafo N de M. El tiempo de audio en A mi ritmo es relativo al párrafo. La voz generada no tiene una duración fiable conocida: nunca se muestran los tiempos del audio original como si fueran los de la traducción.
- El lector desplaza párrafos largos, alinea a la izquierda y permite mostrar dos tarjetas por párrafo. Opciones abre una hoja independiente para no comprimir el texto. En horizontal/pantalla completa, los selectores están en Opciones.
- Corregir párrafo edita el original; Editar traducción edita el destino, también cuando se ven ambos. Corregir el original invalida traducciones anteriores. No se cambia el archivo grabado.
- Una interrupción detiene la reproducción y presenta una indicación. El audio original conserva su posición; la voz traducida reinicia el párrafo al pulsar Play. Nunca se reanuda sola. Cambiar el idioma detiene el sonido y exige pulsar Play para iniciar la nueva selección.
- Practicar idioma usa el mismo transporte y velocidades. Repetir esta frase es un interruptor explícito, inicialmente apagado. Es un bucle de práctica, distinto de escuchar otra vez una sola vez. Pausa conserva la posición de práctica.

## Traducción automática

Detener espera el cierre del reconocedor y del grabador, guarda el borrador final e inicia la traducción al idioma opuesto. No se inicia al pausar ni habla automáticamente. La barra de estado muestra progreso, resultado, reintento o cancelación. Inglés sigue siendo el idioma inicial; español se configura antes de capturar.

La generación requiere iOS/iPadOS 18+, un SDK compatible y los modelos de Apple. La primera vez Apple puede pedir descargar los idiomas. En iOS 17 se explica la limitación, conservando grabación y texto. Si faltan modelos, hay un error o se cancela, el original permanece disponible y se puede reintentar. El trabajo se suspende al iniciar otra captura o al salir de la app, y se retoma mientras el proceso siga vivo, al volver y terminar la captura. Si iOS termina el proceso, el borrador sigue guardado pero la tarea pendiente en memoria no se recupera: guardar la sesión y reintentar desde Traducción.

Traducir no publica el borrador. **Guardar sesión** lo conserva en la biblioteca; **Descartar** cancela su trabajo y elimina texto, audio y traducción derivados. Las respuestas tardías no pueden recrear datos descartados. La vista previa en vivo continúa siendo temporal; al detener se genera una traducción completa del texto final, que puede diferir de la vista previa.

## Para estudiantes: cómo está construido

1. `CaptionViewModel.stop()` espera los resultados finales y cierra el archivo antes de llamar `onEnded`.
2. `SessionCoordinator` hace checkpoint y encola la sesión. Solo hay un `TranslationJob` activo. Su UUID identifica el intento; reintentar crea otro UUID. La cola y el estado son observables, por lo que SwiftUI los muestra sin polling.
3. `AppRootView` mantiene un `TranslationRunner` asociado al trabajo. Este usa la API Apple existente y devuelve pares UUID/texto, nunca sustituye el texto original. Una autorización de descarga puede poner la escena inactiva: no se cancela por eso, solo al pasar realmente a segundo plano. Suspender/cancelar desmonta el runner. El controlador ignora callbacks cuyo UUID ya no es el activo.
4. `IncrementalTranslation` conserva traducciones y correcciones de párrafos que no cambiaron. `TranscriptRepository.saveTranslation` verifica existencia de sesión, idioma y snapshot exacto del origen antes de guardar atómicamente. Solo la ruta automática permite un borrador con fecha de finalización; no admite una captura activa ni publica el borrador.
5. `SessionMediaView` sincroniza `listening` (archivo/voz) con `reading` (original/destino/ambos); una sola selección controla ambos. `ParagraphPlayback` alterna los motores por callbacks para la cola bilingüe. Comparte `PlaybackTransport` y `PlaybackTextCard` para evitar botones con tamaños o significados diferentes. Navegar selecciona; reproducir es otra acción.
6. `SessionPlayer` programa muestras con `scheduleSegment`; el temporizador actualiza la posición, no corta el audio. `AVAudioUnitTimePitch` cambia velocidad sin cambiar intencionadamente el tono. Solo desactiva AVAudioSession si adquirió su uso. `PracticePlayer` reutiliza ese motor y añade el bucle de estudio.
7. `TranslationSpeechPlayer` entrega un párrafo corregido a la vez al sintetizador. En A mi ritmo recibe un solo elemento; en Continua recibe la cola restante. Una identidad de finalización conserva el último párrafo en pantalla. No se inventa un slider de segundos para una duración sintética desconocida.

No hay cambio de esquema, bundle ID, servidor, telemetría ni exportación de voz sintética. Las etiquetas accesibles acompañan a los iconos. Probar VoiceOver, colores, auriculares y voces reales sigue siendo necesario: los tests no certifican accesibilidad universal.

Referencias: [AVAudioUnitTimePitch](https://developer.apple.com/documentation/avfaudio/avaudiounittimepitch), [TranslationSession](https://developer.apple.com/documentation/translation/translationsession).

## Validación

Ver [checkpoint](playback-unification-checkpoint.md). Probar navegación sin sonido, igualdad geométrica de ambos reproductores, fin de párrafo, pausa, edición, texto largo, dos idiomas, traducción sin grabación, Stop automático, descarte y callbacks tardíos. La traducción real con modelos descargados se valida aparte de los fixtures locales.

La escucha de párrafos en Traducción ahora es directa, sin abrir el reproductor. Ver [marcadores y escucha bilingüe](bookmarks-and-bilingual-playback.md).
