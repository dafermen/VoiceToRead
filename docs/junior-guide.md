# VoiceToRead para estudiantes y desarrolladores junior

Actualización de experiencia accesible: [guía de los ocho cambios](accessible-experience.md) y [evidencia/pendientes](accessible-experience-checkpoint.md).

## Reproductor unificado y traducción al detener

Consulta [el recorrido por eventos, cola, estados y persistencia](playback-unification.md#para-estudiantes-cómo-está-construido). Se separan seleccionar un párrafo, iniciar sonido, elegir texto visible y guardar la sesión. Esto apoya lectura a distintos ritmos, discapacidad auditiva/baja visión y aprendizaje infantil acompañado.


Estado actual: **VoiceToRead 1.0 (1), esquema V11**. Los números de build de las secciones heredadas indican hitos del código base. Ver [A mi ritmo y favoritas](at-my-pace.md) y [entrega/verificación](pace-checkpoint.md). Las secciones con otros números describen etapas anteriores.

## Lectura accesible de traducciones (15 de octubre de 2026)

La nueva [guía de voz traducida](translated-speech.md) explica la cola de párrafos corregidos, el sintetizador Apple, los estados de pausa y los tokens que rechazan respuestas antiguas. Incluye pasos para escuchar sin grabación, navegación anterior/siguiente, protección al deslizar y límites de accesibilidad. Estas decisiones buscan apoyar a personas con discapacidad auditiva o baja visión, usuarios que aún no dominan un idioma y niños acompañados por adultos; no solo añadir botones.

Ejercicio: guarda una traducción corregida sin audio, escúchala, pausa justo cuando termina un párrafo y reanuda. Explica por qué el controlador no debe avanzar mientras está pausado y por qué no se debe leer el texto original al elegir Ambos. Después protege una sesión y demuestra que el repositorio rechaza su eliminación aunque alguien evite la interfaz.

## Build 22: filtrar antes de repartir el audio

La reducción de ruido es una preferencia global que se copia al iniciar la sesión. El motor procesa la entrada antes del tap; ese tap entrega la misma señal al archivo y al reconocimiento. No basta con modificar el reproductor: hacerlo allí no cambiaría el audio exportado ni la entrada de Speech. Mantener la opción fija al reanudar evita mezclar tratamientos/formato en un archivo. Lee el [recorrido explicado de reducción de ruido](noise-reduction.md), sus límites y las pruebas con dobles frente a pruebas acústicas reales.

## Build 20: pensar en necesidades distintas

Una preferencia global es una elección para las próximas sesiones; el idioma de una sesión es un dato histórico. `AppSettings.captureLanguage` guarda en UserDefaults en-US/es-ES. `SessionCoordinator` copia esa elección al preparar la captura y `CaptionViewModel` la bloquea desde el primer inicio. `TranscriptRepository.create` escribe la misma cadena en el campo `ConferenceSession.language`, que ya existía. Por eso reanudar no vuelve a leer un idioma diferente ni se necesita migración SwiftData.

El protocolo `SpeechTranscribing.configure(language:)` comunica la elección sin acoplar la pantalla a un motor. El backend antiguo recrea SFSpeechRecognizer con la locale; el moderno pide el locale/modelo compatible. En ambos se conserva reconocimiento local. Elegir español no descarga un modelo silenciosamente ni cambia todos los menús de la app.

La traducción tiene origen y destino, que no son siempre inglés y español respectivamente. `TranslationSnapshot.sourceLocale` es opcional: un JSON antiguo sin esa clave significa origen inglés. `translated` aplica las correcciones al destino; `english` y `spanish` devuelven el idioma solicitado. `IncrementalTranslation` solo reutiliza párrafos del mismo idioma. Una corrección inglesa en una sesión española nunca modifica el audio español.

La vista `ReaderSurface` dibuja un fondo y guías con CoreGraphics a través de una vista UIKit. No captura gestos ni aparece en el árbol de accesibilidad. Alto contraste tiene prioridad y los pasteles usan texto oscuro. La pausa combina texto, icono y botón explícito: no debemos depender solo del color ni del sonido para explicar el estado.

Ejercicio: crear sesión en español, pausar, intentar cambiar idioma, reanudar y comprobar que `session.language` sigue siendo es-ES; después guardar y comenzar otra en inglés. Leer [guía inclusiva](inclusive-use.md) y las pruebas nuevas antes de modificar este flujo.


## 1. Qué problema resuelve

VoiceToRead ayuda a comunicarse mediante texto, traducción y voz en iPhone/iPad. Abre directamente en Conversar; Escuchar conserva las reuniones, clases y conferencias. Permite elegir inglés, español, francés o coreano según la disponibilidad de modelos locales. Está orientada a personas con dificultades auditivas o del habla, baja visión, personas que usan un nuevo idioma y aprendizaje infantil acompañado.

El usuario puede ampliar la lectura, girar el teléfono, pausar, guardar una sesión, protegerla como favorita y corregir palabras antes de compartir. Si activa la grabación antes de empezar, también puede conservar audio, reproducirlo y exportar subtítulos.

La app usa el reconocimiento de Apple en el dispositivo. No implementa un servidor propio ni una alternativa de reconocimiento en la nube. La disponibilidad del modelo de inglés y la precisión dependen del dispositivo y deben probarse. Descargar inicialmente un modelo puede necesitar Internet.

## 2. Tecnologías y vocabulario

| Concepto | Explicación sencilla | Uso en este proyecto |
| --- | --- | --- |
| Swift | Lenguaje con el que escribimos instrucciones y tipos | Servicios, reglas, modelos y pantallas |
| SwiftUI | Describe cómo debe verse una pantalla según sus datos | Vistas en UI |
| ViewModel | Prepara estado y acciones para una vista | CaptionViewModel |
| Protocolo | Contrato que diferentes implementaciones cumplen | SpeechTranscribing |
| SwiftData | Persistencia de objetos en un almacén local | TranscriptRepository |
| AVFoundation | APIs de Apple para capturar, convertir y reproducir audio | AudioCaptureService y grabador |
| Speech | APIs para convertir voz en texto | Motores moderno y de compatibilidad |
| async/await | Permite esperar una operación sin bloquear toda la interfaz | Permisos, reconocimiento, exportación |
| actor | Aísla estado para controlar el acceso concurrente | AudioConversion |
| UUID | Identificador estable que no depende del contenido del texto | Sesiones, párrafos y ejecuciones |
| Test doble o mock | Sustituto controlado de una dependencia durante una prueba | Reconocimiento simulado |

No necesitas npm, CocoaPods ni una clave de OpenAI. Es un proyecto nativo de Xcode sin paquetes externos requeridos.

## 3. El recorrido de una frase

Imagina que alguien dice “Welcome to the conference”.

1. El usuario pulsa Start Listening. La app verifica disponibilidad y permisos.
2. El micrófono entrega pequeños bloques de muestras, no palabras.
3. AudioCaptureService copia cada bloque y le asigna una posición en el reloj de audio.
4. El motor de Speech recibe los bloques. Puede emitir “Welcome”, después “Welcome to”, y finalmente la frase completa.
5. TranscriptAssembler sustituye las revisiones del mismo tramo. No añade una frase nueva por cada cambio parcial.
6. CaptionViewModel actualiza el estado observado por SwiftUI.
7. SessionCoordinator guarda los resultados finalizados mediante TranscriptRepository cuando corresponde.
8. Si el usuario habilitó Save audio, los bloques también pasan al grabador.
9. Después de Stop, el usuario revisa el texto, corrige errores, escucha la grabación o comparte archivos.

~~~mermaid
flowchart TD
    U[Usuario: Start Listening] --> VM[CaptionViewModel]
    VM --> S[Motor Speech]
    S --> A[AudioCaptureService]
    A --> B[Bloques copiados con tiempo]
    B --> S
    B --> R[SessionAudioRecorder opcional]
    S --> T[TranscriptAssembler]
    T --> VM
    VM --> UI[SwiftUI: lectura]
    VM --> C[SessionCoordinator]
    C --> DB[TranscriptRepository / SwiftData]
    DB --> E[Revisión y correcciones]
    E --> X[TXT / PDF / SRT / VTT]
    R --> P[Audio CAF local]
    P --> M[Reproducción / exportación M4A]
~~~

El diagrama muestra responsabilidades; no significa que todas se ejecuten en el mismo hilo ni que cada flecha sea una llamada síncrona.

## 4. Separar responsabilidades

La vista decide qué dibujar. El ViewModel decide si se puede empezar o pausar. El coordinador conecta la sesión activa con su almacenamiento. El repositorio decide cómo leer y guardar. El motor de voz transforma audio en resultados.

Esta separación permite cambiar una pantalla sin reescribir la base de datos. También permite probar una sesión sin hablar realmente al micrófono: se inyecta un objeto que cumple SpeechTranscribing y entrega respuestas conocidas.

Empieza a leer por [VoiceToReadApp](../VoiceToRead/App/VoiceToReadApp.swift), después [AppRootView](../VoiceToRead/UI/AppRootView.swift), [SessionCoordinator](../VoiceToRead/ViewModels/SessionCoordinator.swift) y [CaptionViewModel](../VoiceToRead/ViewModels/CaptionViewModel.swift). Consulta el [mapa del código](code-walkthrough.md) para continuar.

## 5. Dos motores de reconocimiento

El proyecto puede compilarse con herramientas distintas:

- Con el compilador de Xcode 15.2 se incluye el motor LegacySpeechTranscriber, basado en SFSpeechRecognizer.
- Con Swift 6.2 o posterior se puede incluir AppleSpeechTranscriber. Se selecciona en iOS 26 o posterior y usa SpeechAnalyzer/SpeechTranscriber.
- En sistemas anteriores se usa el motor de compatibilidad. La selección por versión no implica que el modelo esté instalado ni que el teléfono soporte todas las funciones.
- Si el motor seleccionado no está listo, se informa al usuario. No se envía el audio a un servidor como alternativa.

`#if compiler(>=6.2)` es una decisión al compilar. `if #available(iOS 26.0, *)` es una comprobación del sistema donde corre la app. Son preguntas diferentes: “¿mis herramientas conocen esta API?” y “¿el iPhone puede usarla?”.

En el motor de compatibilidad se cierra una solicitud después de 50 segundos de audio enviado. Mientras llega el resultado final, los nuevos bloques esperan en una cola limitada. Se abre una solicitud nueva con un UUID nuevo. Esto conserva la continuidad sin asumir que una petición puede durar indefinidamente.

## 6. Estados y operaciones asíncronas

CaptionState representa idle, preparing, listening, stopping, paused, ended o problem. Los botones dependen de ese estado: no se debe iniciar una segunda captura mientras la primera se prepara.

Una respuesta puede llegar tarde. Por ejemplo: el permiso tarda en responder y el usuario ya abandonó la pantalla. El ViewModel conserva un identificador de generación; antes de aplicar el resultado comprueba que siga perteneciendo a la operación actual.

`@MainActor` concentra los cambios de interfaz y la coordinación. No convierte todo el audio en una tarea de interfaz: el callback del micrófono, la cola de escritura y el actor de conversión tienen responsabilidades propias. Evita meter escritura de disco, esperas o trabajo pesado dentro del callback de audio.

## 7. Por qué se copia el audio

El sistema puede reutilizar la memoria del bloque entregado al micrófono. Guardar esa referencia para procesarla más tarde podría leer datos cambiados. AudioCaptureService crea una copia que los consumidores solo deben leer.

CapturedAudio usa `@unchecked Sendable`: el compilador confía en el desarrollador. No añade un candado ni hace seguro cualquier uso. La seguridad depende de copiar antes de compartir y no modificar después el buffer compartido.

SessionAudioRecorder limita a 128 los bloques pendientes. Si el disco no alcanza a escribirlos, la app muestra un fallo en lugar de dejar crecer la memoria sin límite. Su cola serial escribe en orden. CaptureTimeline protege su contador con un candado.

## 8. Tres clases de tiempo

| Reloj | Para qué sirve | Qué pasa al pausar |
| --- | --- | --- |
| Date | Fecha de inicio de la sesión | La hora real continúa |
| ContinuousClock | Duración de escucha activa | La app acumula solo intervalos activos |
| CaptureTimeline | Posición en audio grabado y subtítulos | No avanza si no entran muestras |

Ejemplo: 48 000 muestras a 48 000 Hz representan un segundo. CaptureTimeline acumula `frames / sampleRate`. Si se habla 5 segundos, se pausa 10 y se habla otros 5, la grabación tiene aproximadamente 10 segundos. Los subtítulos deben seguir ese mismo reloj, no los 20 segundos del reloj de pared.

Los motores suman el desplazamiento de cada ejecución al tiempo de sus resultados. De lo contrario, cada reinicio produciría subtítulos que vuelven incorrectamente al segundo cero.

## 9. Qué se guarda y por qué no se borra el original

| Modelo | Contenido |
| --- | --- |
| ConferenceSession | Identidad, título y metadatos de la sesión |
| StoredCaption | Texto reconocido y datos de orden de cada tramo final |
| CaptionBookmark | Marcador con una copia de la frase |
| SessionReview | Correcciones y posición de lectura |
| SessionMedia | Nombre relativo del audio y tiempos de los párrafos |
| SessionDraft | Marca que distingue un borrador recuperable de una sesión guardada |

Las correcciones son un mapa por UUID. El texto que se muestra se calcula como “corrección si existe; de lo contrario, original”. Así se puede restaurar el reconocimiento original. El editor trabaja sobre un borrador hasta que se guarda; deshacer no requiere reconocer la voz otra vez.

El esquema V4 añadió SessionMedia y V5 añade SessionDraft, sin modificar los modelos anteriores. Las migraciones anteriores conservan sesiones, marcadores y correcciones. Cambiar una estructura persistida no equivale a cambiar una variable temporal: hay usuarios con bases de datos antiguas.

Esta nueva app usa la carpeta interna VoiceToRead y el bundle ID com.innovalogic.voicetoread. El Bundle ID identifica una instalación y su contenedor privado; cambiarlo crea otra app y no migra los datos anteriores. Copiar el código no equivale a copiar las sesiones. Consulta [la identidad del proyecto](project-identity.md).

El almacenamiento se excluye del backup. Los datos importantes deben exportarse; borrar la app puede hacer perder sus datos locales.

## 10. Audio y subtítulos

Durante la captura se guarda PCM de 16 bits en CAF. La codificación M4A ocurre al exportar. Mantener un archivo PCM abierto durante las pausas evita añadir relleno de un codificador cada vez que se retoma la escucha.

SubtitleExport convierte tiempos y palabras en pequeños bloques llamados cues. Agrupa por longitud, duración y silencios. Usa los tiempos originales si coinciden las palabras; si se modifica el párrafo, distribuye las palabras corregidas dentro del intervalo disponible. Esa sincronización es estimada, no una nueva alineación automática con la voz.

SRT usa una coma antes de los milisegundos; WebVTT usa punto y una cabecera WEBVTT. Ambos son archivos de texto con inicio, fin y contenido. El reproductor muestra el cue correspondiente al tiempo del audio.

Eliminar audio conserva texto y tiempos de subtítulos. Las sesiones antiguas sin tiempos no pueden generar sincronización real. Exportar “todo junto” comparte varios archivos mediante la hoja nativa; no implica insertar subtítulos dentro de un video ni crear un ZIP.

## 11. Qué significa escuchar otro video

La app escucha el micrófono. Un video de otra aplicación puede transcribirse si su sonido sale por el altavoz y llega físicamente al micrófono. No existe captura interna del audio de YouTube o de otras apps.

Save audio y Continue in background son preferencias diferentes: inicialmente apagadas, se recuerdan al cambiarlas. Al iniciar se toma una copia de la preferencia de audio para esa captura. El ajuste de segundo plano puede cambiar durante la escucha. Las llamadas y otras actividades pueden interrumpir la captura incluso con ambas activadas. La app no debe reactivar el micrófono a escondidas después de una interrupción. Con audífonos, el sonido del video normalmente no llega al micrófono como se necesita.

## 12. Cómo estudiar y practicar

1. Ejecuta la app en un simulador para conocer las pantallas. No concluyas que reconoce voz por ver texto de prueba.
2. Lee TranscriptAssembler y sus pruebas. Sigue una secuencia de resultados parciales y finales.
3. Lee TranscriptReview y prueba mentalmente una corrección, Undo y Restore original.
4. Lee CaptureTimeline y calcula el tiempo de dos bloques con distintas duraciones.
5. Lee SessionMediaTests para ver cómo se verifica audio generado sin una grabación de una persona.
6. Sigue una acción de la vista hasta el repositorio con el mapa del código.
7. Haz un cambio pequeño en una rama; ejecuta las comprobaciones pertinentes y revisa el diff antes de subirlo.

Ejercicios propuestos, no funciones nuevas ya implementadas:

- Explica por qué repetir la palabra “yes” no debe eliminarse como duplicado.
- Dibuja qué ocurre cuando Stop llega mientras se solicita permiso.
- Calcula una marca SRT para 65.125 segundos: 00:01:05,125.
- Diseña una prueba que compruebe que borrar audio no borra las correcciones.
- Compara lo que prueba un mock de Speech con lo que requiere un iPhone real.

## 13. Compilar no es publicar

Compilar traduce Swift a un programa. Archive prepara un paquete con metadatos. Exportar aplica firma y empaquetado de distribución. Subir envía el paquete a Apple. Procesar verifica el paquete del lado de Apple. Asignar a testers y actualizar TestFlight son pasos posteriores.

En octubre de 2026 aprendimos esa diferencia: Archive terminó bien, pero Cloud falló con HTTP 502 al consultar el equipo. El mismo archivo se exportó y subió desde el Mac. Lee la [guía de distribución](distribution-runbook.md) y el [historial de incidentes](build-incidents.md) antes de la próxima entrega.

## 14. Cómo saber si algo funciona

Una prueba unitaria demuestra una regla con entradas controladas. Una prueba de UI demuestra un recorrido con condiciones concretas. Ninguna sustituye una medición real de voz, latencia o batería.

La validación registrada para audio/subtítulos fue de 56 pruebas unitarias compatibles y 12 escenarios de interfaz, pasando estos últimos entre una ejecución completa y una repetición enfocada. La prueba moderna de conversión no se ejecutó con Xcode 15.2. Consulta [testing](testing.md) y [validation-report](validation-report.md) antes de repetir números o afirmar que todo está verificado.

## 15. Ejemplo: guardar no es lo mismo que recuperar

Piensa en un documento en edición: necesitamos recuperarlo tras un cierre inesperado, pero todavía no sabemos si el usuario quiere conservarlo. La transcripción funciona igual. Al iniciar, el repositorio crea ConferenceSession y una marca SessionDraft. Cada resultado final se escribe en disco. Stop cierra el audio y deja la marca; no decide por el usuario.

Save Session elimina solo la marca: el texto, audio, UUID y tiempos siguen siendo los mismos. Discard elimina la sesión y sus archivos después de confirmación. El botón + llama a newSession directamente cuando no hay decisión pendiente; si existe un borrador, ofrece guardar o descartar antes de limpiar la pantalla. Si guardar falla, la pantalla conserva la sesión para reintentar.

La migración es aditiva: una sesión antigua sin marca se considera guardada. Nunca debemos clasificar todas las sesiones antiguas como borradores solo porque añadimos una función. Las pruebas abren una base V4, migran a V5, cierran/reabren un borrador y verifican su texto y su archivo de audio.

Las preferencias pertenecen a AppSettings/UserDefaults; el estado de captura pertenece al ViewModel. Recordar “guardar audio” no significa activar el micrófono al abrir la app. Start sigue siendo una acción explícita. Cambiar esa preferencia a mitad de una sesión afecta a la siguiente: no podemos reconstruir audio pasado ni mover el origen de los subtítulos sin una implementación específica.

## 16. Del párrafo al audio, y del micrófono al indicador

Un párrafo tiene un UUID. SessionMedia guarda tiempos usando ese UUID. SubtitleExport transforma texto revisado y tiempos en cues: pequeños fragmentos con inicio y fin. Al tocar un párrafo, SessionDetailView abre SessionMediaView con su UUID; el reproductor busca el primer cue correspondiente y llama a play(from:). No calcula segundos a partir del número de letras ni usa el orden visual como si fuera tiempo.

play(from:) primero valida la posición y hace seek. Si el reproductor estaba pausado, inicia; si ya estaba reproduciendo, sigue. Reutilizar toggle() sin comprobar el estado sería un error: tocar la segunda frase pausaría el audio.

El tap del micrófono ya calcula RMS y entrega un nivel normalizado. El motor de Speech consume esa señal para detectar falta de audio y ahora comunica el nivel mediante onLevel. CaptionViewModel limita las actualizaciones visuales a unas diez por segundo y solo las acepta mientras escucha. El indicador no escribe muestras ni sustituye la grabación. Estado listening y recordingPrepared permiten distinguir transcribir de guardar audio.

Pausa finaliza el turno de Speech y conserva el borrador. Reanudar inicia otro turno dentro de la misma sesión. Una interrupción no autoriza reanudar por sí sola. Las pruebas provocan un error, comprueban que el UUID y texto final sobreviven, y exigen una llamada explícita a start().

Un gesto de ampliación usa estado temporal durante el movimiento. Solo al finalizar persiste el tamaño en AppSettings: esto evita escribir preferencias en cada actualización del gesto. Se limita al mismo intervalo que el control Aa. SessionTitle usa DateFormatter local y limpia el nombre al guardar; no necesita IA ni red.

SwiftUI describe vistas mediante tipos genéricos. Una cadena muy larga de modificadores puede resultar cara de comprobar para el compilador aunque sea rápida en ejecución. En esta entrega se midieron unos 176 segundos en el getter del lector; separar contenido, estilo, interacción y seguimiento redujo cada comprobación a menos de un segundo en la ejecución medida. Esto no es una medición de velocidad de transcripción. Los componentes conservan los mismos IDs de párrafo y acciones.

## 17. Traducir sin destruir el original

Lee [el recorrido de traducción](translation.md). La idea central es separar datos originales de datos derivados: cada párrafo conserva su UUID; la traducción guarda una copia del inglés usado, un resultado automático y las correcciones españolas. Si el inglés cambia, conservar el mismo UUID no basta: comparar el contenido detecta que hay que retraducir. Un lote se guarda solo cuando todas las respuestas son válidas. Cancelar evita publicar resultados parciales. La migración V6 añade una tabla en lugar de modificar los modelos anteriores.


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


## Práctica de pronunciación (build 19)

Lee [cómo se conectan voz sintética, grabador, reproductor y reconocimiento local](pronunciation.md). Presta atención a generation: protege contra respuestas asíncronas que llegan después de cerrar la pantalla. Comparar texto reconocido no evalúa pronunciación.


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).

## Lección: reproducir un párrafo y proteger una sesión (build 23)

Imagina un cuaderno con audio: cada párrafo tiene una etiqueta UUID y dos números, inicio y fin. Corregir “casa” por “clase” cambia las letras, no la etiqueta ni el audio. `PlaybackParagraph.make` une texto y tiempos por esa etiqueta. No usa el índice de pantalla: filtrar una lista no debe cambiar qué grabación corresponde al texto.

El audio digital contiene muestras. Para reproducir desde el segundo 2 hasta el 4 a 16 000 muestras por segundo, se programan 32 000 muestras comenzando en la muestra 32 000. `scheduleSegment` limita la reproducción a ese intervalo. El reloj de pantalla se actualiza aparte. Al terminar, el texto sigue seleccionado: quien lee decide cuándo continuar.

Los callbacks llegan después. Si se toca otro párrafo antes de recibir el callback anterior, no queremos que ese callback detenga el nuevo audio. Por eso cada reproducción tiene un UUID temporal (`generation`); solo el callback con el UUID actual puede finalizarla. Pausar cambia ese UUID y cancela el temporizador.

El editor tiene un borrador. Cancelar no escribe en la base. Guardar llama al repositorio y solo cierra cuando la operación termina bien. La corrección se guarda separada del reconocimiento original; SRT, TXT y la pantalla reutilizan el texto revisado. Traducir produce otra copia, también separada. No confundir “editar el subtítulo” con “editar la voz grabada”.

Una favorita es una fila `SessionFavorite(sessionID)`, no otra copia de la sesión. Agregar esta tabla requiere migración V7→V8; redefinir modelos antiguos puede romper la apertura del almacén. El repositorio comprueba la protección antes de tocar archivos, incluso si alguien llama a borrar sin pasar por el botón. La interfaz deshabilita el botón para explicarlo, pero la regla vive también en el repositorio.

Práctica: ejecuta `testV7MigrationFavoriteProtectionAndExplicitRemovalSurviveReopen`. Crea un almacén anterior, lo abre con la nueva versión, protege, cierra, vuelve a abrir e intenta borrar. Comprueba texto y audio reales: no basta con verificar que un icono sea amarillo.

El cambio de idioma conserva el `TabView`: recrearlo con `.id(idioma)` podría perder navegación/estado. Se resuelven explícitamente sus etiquetas y el título de Ajustes. Prueba alternar EN→ES→EN con una sesión pausada y confirmar que Reanudar sigue disponible.

Para publicar, código correcto no equivale a una app disponible. Se necesitan archivo firmado, subida procesada, grupo TestFlight, prueba física y revisión pública aparte. Lee [la guía de App Store](app-store.md) antes de marcar una entrega como publicada.

## Lección: dos idiomas en el mismo lector (build 24)

Una preferencia de presentación no debe cambiar la captura. `LiveCaptionDisplay` contiene original/translation/both y se conserva con `@AppStorage`. `CaptionScreen` muestra el lector original o pasa la opción al panel de traducción, sin llamar a start/stop. Idioma del micrófono, idioma de interfaz y forma de mostrar el texto son tres decisiones distintas.

Cada párrafo tiene un UUID. `LiveTranslationBuffer.translated[id]` permite dibujar la traducción debajo del original correspondiente aunque llegue después. Mientras falta, se muestra un aviso, no una segunda copia del original que pueda confundirse con traducción. Solo se envía texto confirmado al motor; el provisional aparece como texto que puede cambiar. Cambiar Traducción↔Ambos mantiene la misma vista/cola; volver a Original desmonta la vista previa y cancela su tarea sin tocar el micrófono.

Las pruebas UI usan respuestas prefijadas dentro de `#if DEBUG`. Verifican parejas, selector y continuidad de la sesión, no la calidad ni latencia del motor de Apple. El build Release no contiene ese proveedor simulado. Ver [evidencia](live-bilingual-checkpoint.md).

### Tarjetas bilingües (fuente 27)

`LiveLanguageCard` es un `ViewModifier`: decora una vista sin cambiar sus datos ni la traducción. Recibe la preferencia `LanguageColor` resuelta a partir de `CaptureLanguage`; azul/verde son los valores iniciales, personalizables aunque se invierta la captura. `LiveSpanishView` aplica el mismo modifier al original, a la traducción pendiente y al provisional en modo Ambos. Los modos de un solo idioma conservan su presentación.

El contenido usa `ReaderParagraph`, que ya resuelve tamaño, interlineado, selección y renglones. Un fondo `RoundedRectangle` añade relleno, borde y sombra sin añadir elementos a VoiceOver. Las etiquetas de idioma evitan depender del color. La preferencia de alto contraste llega desde `CaptionScreen`; también se respeta el contraste aumentado del sistema. En esos casos el fondo es blanco/negro y el borde más marcado. `@ViewBuilder` permite devolver vistas distintas al activar/desactivar la tarjeta; no omitirlo en helpers condicionales (ver incidente de fuente 26).

## Sitio público y políticas — VoiceToRead

La web bilingüe se genera en `website/dist/`. La [guía de publicación y explicación para estudiantes](website-publication.md) cubre HTML/CSS, generación desde documentos, idiomas, validación, hPanel y SSL. El [README de la web](../website/README.md) contiene los comandos. Sitio preparado; subida y HTTPS públicos pendientes.

## Preparar una publicación sin confundirla con instalar la app

Una app tiene tres identificadores distintos: el **bundle ID** identifica el producto; **MARKETING_VERSION** es la versión visible (ahora 1.0); **CURRENT_PROJECT_VERSION** identifica una compilación. Cloud puede asignar su propio número al archivo. Cambiar un texto en GitHub no demuestra qué número recibió Apple: se comprueba el Info.plist del archivo y TestFlight.

TestFlight interno permite probar, pero un archivo marcado Internal Testing Only no puede enviarse a la tienda pública. El workflow debe archivar con TestFlight and App Store. Después se instala y prueba ese mismo archivo antes de seleccionarlo en la ficha 1.0. No se resuelve creando otro bundle ID ni borrando sesiones.

`PrivacyPolicyView` usa el locale de SwiftUI (idioma de menús) para elegir `/en/privacy/` o `/privacy/`. El idioma de captura puede ser distinto. `Link` abre el navegador o correo únicamente al tocarlo; el texto local de privacidad no necesita conexión. Los textos visibles están traducidos en ambos Localizable.strings. El responsable y el plazo de soporte deben coincidir con la política pública.

Para capturas reproducibles, `--store-screenshots` crea una biblioteca **en memoria**, con texto ficticio y preferencias separadas. Está dentro de `#if DEBUG`: el compilador elimina ese código de Release. No se inicia el micrófono ni se simula una traducción en vivo. XCTest navega por las pantallas reales, verifica controles y guarda capturas como attachments. Esta técnica comprueba presentación y navegación, pero no la precisión del reconocimiento, los servicios modernos de traducción ni la firma de Apple.

El [paquete de publicación](store/submission-kit.md) distingue hechos comprobados, decisiones del titular y verificaciones pendientes. El validador `--ready` debe seguir fallando mientras haya pendientes; es una protección contra enviar una ficha incompleta, no un error que deba ocultarse.

## Marcadores visibles y reproducción bilingüe

[Guía de uso y desarrollo](bookmarks-and-bilingual-playback.md): un selector para leer y escuchar, original seguido de traducción, escucha directa en cada párrafo y marcadores compartidos por UUID. Incluye explicación paso a paso para estudiantes y límites de las pruebas.

## Escucha más clara y notas (V10)

[Guía de uso y explicación para estudiantes](listening-comfort.md): identificación del texto que suena, pausa cancelable, velocidades por idioma, preferencias, búsqueda, notas de marcadores y preparación. [Validación y entrega](listening-comfort-checkpoint.md).

### Tamaño de letra compartido (2026-10-16)

`CaptionTextSize` en `AppSettings.swift` define 14–60 puntos base y el valor inicial 28. `CaptionSizeControl` se reutiliza en Ajustes, lectura en vivo y reproductor. El gesto y VoiceOver llaman al mismo límite; al cargar preferencias se valida también el dato persistido. Así evitamos que una pantalla acepte 14 y otra lo restablezca a 20. Dynamic Type sigue multiplicando el tamaño de presentación. El tamaño visual y el avance del audio son responsabilidades separadas: para terminar de leer un párrafo usamos A mi ritmo, no un cambio oculto del reproductor. [Uso y límites](listening-comfort.md#párrafos-largos-en-un-iphone-pequeño).

## Hablar y traducir (2026-10-16)

[Guía de implementación para estudiantes](speak-and-translate.md#para-estudiantes-arquitectura-y-decisiones): máquina de estados temporal, detección heurística de pausa, finalización de micrófono antes de la voz, validación de traducciones y rechazo de callbacks obsoletos. El modo no crea una sesión de SwiftData.

## Controles claros y voz por decisión del usuario — 2026-10-16

Una traducción terminada no obliga a reproducir sonido. `SpeakTranslateModel.Mode` distingue Automático de Por botón; al crear un trabajo se copia la decisión en `speakWhenComplete`. Así el resultado asíncrono sabe si debe hablar o quedar disponible para Play. Se bloquea cambiar modo durante operaciones y se valida la identidad del resultado antes de usarlo. `@AppStorage` conserva la elección, mientras que el mensaje pertenece al modelo temporal de la pantalla y desaparece al cerrarla.

Ejercicio: en Por botón, escribe y traduce sin hablar, pulsa Play y cancela. Reabre: el modo debe conservarse y el texto estar vacío. Explica por qué guardar ambas cosas en UserDefaults cambiaría las expectativas de privacidad. Comprueba también una pausa larga durante escucha manual: no debe cerrar el turno salvo el límite de duración.

`ReturnToLiveButton` comparte aspecto y nombre accesible entre los lectores original y bilingüe. Cada lector conserva su propio estado de seguimiento y desplazamiento. Una acción visible única evita confundir estado con acción. `CapturePreferenceLabel` muestra nombre y On/Off; `ViewThatFits` cambia de fila a columna cuando falta espacio. Esto ayuda a baja visión y a quienes no reconocen un icono, sin depender del color. Lee [el recorrido de sesiones](session-workflow.md#controles-claros--2026-10-16).

## Simplificación de navegación — 2026-10-16

La [guía actual](simplified-navigation.md#para-estudiantes-qué-cambió-y-por-qué) explica cómo separar revisar texto de reproducir audio, reutilizar DoneButton sin cambiar las decisiones de guardado, pasar una acción desde el coordinador a un icono compacto y retirar una función conservando los modelos persistidos. Las secciones históricas de marcadores/reproducción inline ya no describen la interfaz actual.

Ejercicio: abre Texto y traducción, corrige un párrafo y luego entra en Audio y subtítulos. Comprueba que el texto corregido llega al único reproductor. Explica por qué mantener los IDs permite conservar tiempos y datos anteriores, y por qué eliminar vistas no requiere borrar filas de SwiftData.

## Conversación bilingüe de dos toques

`SpeakTranslateModel.start(language:)` fija el idioma de cada turno, sin cambiar Ajustes. El primer toque inicia escucha y el segundo espera el texto final, lo traduce y reproduce en `language.opposite`. `canEdit` incluye el estado de voz: no basta con que la traducción haya terminado para volver a abrir el micrófono. El modo Por botón es inicial; Automático está en Opciones, con la preferencia nueva `conversationTurnMode`.

El editor trabaja sobre una copia: cancelar no borra las tarjetas. Un resultado de traducción se aplica solo al identificador de trabajo actual; así una respuesta tardía no habla después de Cancelar. Ejercicio: seguir un turno inglés desde el botón hasta la voz española, detenerla y comenzar uno español; observar que el idioma global y las sesiones no cambian. Consulta [el flujo, límites y pruebas](speak-and-translate.md).

Ajuste visual de Conversación: dos `HStack` mantienen español/inglés y reproducir/corregir en sus respectivas filas, también en iPhone. Las etiquetas admiten varias líneas y conservan áreas de toque amplias. Se retiró el menú Escribir en su lugar; el editor sigue disponible para corregir un turno reconocido. El icono de acceso usa la variante de contorno del mismo símbolo.

## Colores por idioma

La paleta tiene una sola definición para botones y tarjetas. Los ajustes persisten como identificadores de color, independientes del idioma hablado y sin migrar sesiones. Alto contraste tiene prioridad. Consulta [uso, flujo de datos y pruebas](language-colors.md).

## Inicio y preferencias de accesibilidad (2026-10-17)

[Guía de implementación](home-controls.md): etiquetas observables, cuadrícula adaptable, tamaños comunes y separación entre preferencias y acciones. Incluye la causa del espacio excesivo al cambiar HStack por VStack y cómo evitarla.

## Biblioteca e idiomas explícitos (2026-10-17)

Lee [la explicación para estudiantes](session-library-and-languages.md#para-estudiantes-de-programación). Antes `opposite` asumía inglés/español; ahora cada trabajo lleva origen y destino. No basta con agregar dos valores a un Picker: hay que revisar persistencia, caché, reproducción, nombres de archivos, práctica y mensajes.

Ejercicio: crea una sesión francesa, tradúcela a coreano, corrige una frase, cambia a español y vuelve a coreano. La corrección debe conservarse. Después modifica el original: ambos destinos deben requerir actualización. Sigue el UUID del párrafo desde el reconocimiento hasta el snapshot y el paso de audio. Repite con un almacén V10 para comprobar que la migración añade datos sin destruirlos.

Los nombres históricos `LearningExpression.english/spanish` representan original/nota; no se cambian sus columnas para conservar los almacenes anteriores. Su etiqueta visible es genérica, porque las notas históricas no incluyen un destino. Las nuevas traducciones sí guardan su destino explícitamente.

## Uniformidad visual de controles (2026-10-17)

Consulta [las convenciones y su explicación SwiftUI](home-controls.md#convenciones-compartidas-de-presentación). El objetivo es que personas con baja visión, dificultades auditivas o del habla, estudiantes de idiomas y niños acompañados encuentren acciones previsibles sin aprender otra organización en cada pantalla.

Al agregar una ventana de consulta, reutiliza `DoneToolbar`, no un `DoneButton` con ubicación implícita. Si hay un formulario con cambios pendientes, conserva Cancelar/Guardar. Un menú solo debe aparecer si hay acciones adicionales: coherencia no significa duplicar botones sin función. Las acciones secundarias de práctica reutilizan `PracticeActionStyle`; reproducción usa `PlaybackTransport`. Mantén separados el dibujo del símbolo, el texto visible y el nombre de accesibilidad. Prueba también nombres activados, español, letra grande y apariencia oscura; un círculo con un texto largo dentro no es un buen control adaptable.

## Preferencias independientes y selectores compartidos

Mostrar nombres y Modo sencillo son decisiones distintas. Evita expresiones como `showButtonNames || simpleMode`: hacen que el interruptor parezca roto. `AccessibleControlLabelStyle` y `PlaybackTransport` leen el objeto observable de ajustes del entorno, en lugar de abrir otra instancia de UserDefaults. Esto mantiene sincronizados controles de ventanas secundarias y las pruebas con preferencias aisladas.

`LanguagePickerControl` reutiliza la apariencia azul para todos los idiomas hablados y de traducción. Su binding delega la selección al propietario; no mezcla la dirección de una sesión guardada con la de Conversación ni con el idioma de los menús. Consulta [la guía actualizada](home-controls.md#selectores-de-idioma-y-regreso-a-inicio).


## Comunicación primero: presentación, estado y reversibilidad

Ver [decisión y recuperación](conversation-first.md). `AppSettings.conversationHome` elige entre dos presentaciones; su valor predeterminado es true cuando aún no hay preferencia. No cambia `SessionCoordinator` ni el esquema de SwiftData. Así podemos probar otra entrada sin migrar o borrar sesiones.

`CommunicationHomeView` tiene un selector local y posee el modelo de conversación. Lo pasa a `SpeakTranslateView` en modo integrado; el inicio anterior puede seguir abriendo la misma vista como ventana. Compartir el modelo mantiene un único estado del turno y evita crear un segundo micrófono al cambiar la presentación. El cambio de modo se bloquea mientras hay captura, finalización o voz en curso. Salir de Conversación cancela sus operaciones temporales; salir de Escuchar conserva la política existente de sesiones.

El modo sin traducción es una ruta real del modelo: no basta con ocultar la tarjeta traducida. Debe permitir capturar sin el framework de traducción, terminar y mostrar el original sin iniciar un trabajo de traducción ni repetir automáticamente la voz captada. Leer en voz alta es una acción explícita; una respuesta escrita puede reutilizarla. Cambiar una preferencia no debe iniciar audio por sorpresa ni borrar texto al volver a la pantalla.

Un tag Git conserva código, no las grabaciones privadas del usuario. La opción de inicio anterior es una comparación reversible; una reversión de TestFlight requiere volver a compilar con un número nuevo, nunca borrar sesiones ni reescribir main con force push.

Con tamaños de letra de accesibilidad, los botones de turno se apilan dentro del área desplazable. En tamaños normales permanecen junto al borde inferior. Mantener una barra fija con texto enorme puede ocultar toda la conversación: por eso una prueba de que el botón existe no basta; también revisamos capturas y comprobamos que su altura no ocupe la pantalla completa.
