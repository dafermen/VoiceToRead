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


## Per-language translations

Each story retains translations, manual corrections and approval separately for
each destination. The optional savedTranslations field preserves compatibility
with archives containing only the active translation. Switching destinations
saves the active version and restores the requested version without translation
or a replacement prompt. New destinations start untranslated. Translate again
confirms replacement of only the selected destination; other versions survive.
Source text/language edits retain their confirmation and clear all now-outdated
translations; title/destination-only edits preserve them. Atomic writes and stale
snapshot guards remain. Tests cover legacy decoding, switching, corrections,
approvals, reopening, replacement isolation and source invalidation. XCTest was
not executed on Windows; localization validation is run locally.

## Illustrated story library

The eleven built-in examples now have local landscape PNG covers, generated with
built-in image_gen and visually inspected. Story cards follow the guided lesson
library's 16:9, rounded-corner cover style and retain their titles and language
labels. The reader layout is unchanged, keeping the reading area available.
Custom stories have a neutral book cover. Images require no network or API key.

The example's stable ID selects its artwork even after a title change. Existing
archives with older random IDs use the catalog's existing normalized title/alias
matching. No archive, story text, translation, approval, narration or confirmation
is rewritten. The decorative image is hidden from VoiceOver; the existing link
title and language labels continue to identify the destination.

StoryCovers is bundled through a dedicated folder reference in the application
resource phase. docs/story-cover-prompts.json records exact prompts, repository
paths, dimensions and hashes. Local validation checked eleven unique 16:9 PNGs,
identity/filename correspondence, resource registration, localization and diff
format. XCTest adds native image decoding, uniqueness, renamed/legacy identity
and custom-story fallback coverage. Xcode/XCTest and iPhone layout/VoiceOver
verification cannot run locally on Windows and remain necessary on Apple devices.

## Twenty-story starter library

Nine original Spanish short adaptations complete the twenty-story library:
La liebre y la tortuga; El león y el ratón; El ratón de campo y el ratón de ciudad;
Ricitos de Oro y los tres osos; Juan y las habichuelas mágicas; Los músicos de Bremen;
La princesa y el guisante; El zapatero y los duendes; Sopa de piedra.
The new versions use eighteen short paragraphs each, gentle outcomes and no
graphic violence. They are newly written retellings, not copied translations.
Juan's ending is adapted to avoid taking someone else's possessions; the pea
story presents its traditional test as a fictional belief, not a claim about
real sensitivity or worth. Existing eleven texts and all earlier covers remain
unchanged. Traditional tale references consulted for selection include:

- Aesop fable index: https://read.gov/aesop/001.html
- Andersen collection: https://www.gutenberg.org/cache/epub/1597/pg1597-images.html
- Three Bears reference: https://www.colorado.edu/projects/fairy-tales/the-story-of-the-three-bears
- Stone Soup tradition: https://www.ala.org/winner/stone-soup

The existing per-example installation markers add only newly introduced IDs.
User corrections, translations and approvals remain; intentionally deleted older
examples stay deleted. No store migration, language control, review, narration,
speed, highlighting or session/training behavior was changed. New stories start
in Spanish and use the existing translation-and-adult-review flow for other
languages; the original remains playable.

Nine additional built-in image_gen covers follow the established offline 16:9
gouache style. Exact prompts, repository paths and SHA-256 hashes are appended
to story-cover-prompts.json. The existing folder resource includes them without
new Xcode project entries. Local checks verify twenty unique covers and IDs,
unchanged first-eleven source text, valid content lengths and localization.
XCTest expectations now require twenty examples, plus a prior-eleven archive
case that keeps an edited story, preserves deletion and adds new examples once.
XCTest/iPhone UI verification requires Xcode and cannot run locally on Windows.
