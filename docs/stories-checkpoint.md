# Cuentos — primera versión, 2026-10-25

Inicio ofrece Talk / Listen / Train / Stories, traducidos según la interfaz. El selector usa dos filas con texto accesible o cuando las cuatro opciones no caben. No se cambian los motores de Conversar, Escuchar ni Entrenar.

Biblioteca independiente en Application Support/VoiceToRead/Stories/stories.json, con escritura atómica, protección de archivo y exclusión de copia de seguridad, como los entrenamientos. El ejemplo inicial es una adaptación propia de Los tres cerditos. Se puede crear y editar título, texto e idiomas, con los seis idiomas existentes. Los datos de sesiones y entrenamientos no se leen ni reescriben.

El lector narra el cuento completo con la voz guardada en Ajustes para el idioma elegido. Controles: reproducir, pausar/reanudar, detener, lectura lenta y tamaño de texto. Las palabras se resaltan con rangos UTF-16 del sintetizador y UITextView mantiene el rango visible sin reconstruir el texto por palabra. No se usa el micrófono ni se conserva audio.

Preparación para adultos: traducción Apple existente y revisión editable por párrafo. La narración traducida se habilita tras guardar la revisión; el original se puede leer desde el comienzo. Cambiar origen/idiomas requiere confirmar la pérdida de la traducción de ese cuento. La traducción sustituye la anterior solo cuando finaliza y el documento de origen sigue vigente. Eliminación y descarte de cambios llevan confirmación. La etiqueta para adultos describe el flujo; no constituye un bloqueo parental ni una cuenta infantil.

La voz se detiene y limpia resaltado al salir, cambiar texto/idioma, entrar en segundo plano o recibir interrupciones de audio. Se rechazan callbacks tardíos. Se preservan pausas, selección manual y voces de los otros módulos.

Verificación: pruebas XCTest de almacenamiento independiente, archivo corrupto, traducciones incompletas/obsoletas, revisión, pausa y callbacks tardíos; recorrido UI de creación/traducción/revisión/borrado. En Windows no se ejecutan XCTest ni la narración real: pasar compilación Xcode Cloud y probar en iPhone/iPad, incluyendo párrafos largos, idiomas asiáticos, auriculares y Dynamic Type. Archive correcto no acredita disponibilidad TestFlight ni lectura física validada.


## Included catalog update

The library includes eleven Spanish beginner texts: Caperucita Roja, Rapunzel,
Los tres cerditos, El patito feo, Pinocho, Blancanieves, Cenicienta,
Hansel y Gretel, El gato con botas, El flautista de Hamelín, and
El principito · Resumen breve. These are short original retellings; the last
entry is only an original brief summary, not the book. Default translation is
English; the existing language selection and adult translation review remain.
Stories are listed alphabetically.

Stable catalog IDs and optional installation markers extend the version-1
archive compatibly. Existing matching titles/aliases are kept byte-for-byte as
documents, including corrected translations and IDs. Missing examples are added
once; deleting an installed example does not restore it on reopening. Custom
stories, training archives and sessions are untouched. XCTest coverage includes
old-archive migration, corrections, repeated opening and deletion persistence.
XCTest/audio interaction require Xcode and an iPhone; not executed on Windows.


## Visible translation steps

The reader now shows a compact next step under the language selector: Translate
(with target-language guidance), translating progress and cancellation, Review,
or ready-to-play guidance. Review explicitly ends with Approve; it calls the same
existing review save operation. Original playback remains available before
translation and review, with the existing busy guard during translation.
The options menu labels repeat translation as Translate again and keeps its
replacement confirmation. Editing, deletion and discard confirmations remain.
The existing UI workflow test covers these visible steps, original playback
availability and cancellation of translation replacement. XCTest requires Xcode;
it has not been executed locally on Windows.


## Visible destination language

Reading language and Translate to are separate controls. Translate to offers
all current app languages except the story's source language. Selecting a new
destination changes only the pending request: saved translations/corrections
survive cancellation and failure. Replacement requires the existing confirmation.
The completed translation and its destination are validated and saved atomically,
then require a fresh review and approval. Original narration stays available
before preparation; the existing translation-in-progress busy guard is unchanged.
Focused XCTest coverage checks failed/successful target replacement and persistence;
UI coverage checks the destination selector. Tests require Xcode (not run on Windows).


## Reader header alignment and slow default

Stories reuse CommunicationLanguagePair and stacked LanguagePickerControl roles
for Original language → Translate to, including the existing accessibility-size
stacked layout. The original is fixed in this reader; Edit story retains source
editing and its reset confirmation. An approved translation exposes a compact
Original / Translation selector for reading and listening. No translation or
approval requirement is bypassed. Slow reading starts enabled whenever a reader
opens and remains adjustable while idle. Storage and other modules are unchanged.
The UI workflow covers the initial slow toggle, language alignment, absence of
the version selector before approval and switching both reading versions.
XCTest requires Xcode and was not run on Windows.
