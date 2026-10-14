> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Informe de validación

## Build 22 — 2026-10-12

- **95 pruebas unitarias aprobadas**, cero fallos: persistencia opt-in, configuración sin inicio automático, instantánea a través de pausa/reanudación/nueva sesión y error sin inicio silencioso. Suite completa compatible con Xcode 15.2; no incluye ramas que ese SDK desconoce.
- **UI iPhone aprobada**: acceso rápido, opción futura frente a sesión actual, pausa/reanudación, inglés y español (33,287 s). `/private/tmp/VoiceToRead22-verified.log` y `.xcresult`, TEST SUCCEEDED; capturas revisadas.
- **UI iPad aprobada** con el mismo recorrido (51,624 s): `/private/tmp/VoiceToRead22-ipad.log` y `.xcresult`, TEST EXECUTE SUCCEEDED; capturas revisadas.
- **Release universal aprobado**, BUILD SUCCEEDED: `/private/tmp/VoiceToRead22-release.log`, 0.1.0 (22), familia [1,2], bundle original, sin firma local. Advertencias de concurrencia onLevel/onDismiss existentes.
- Paridad de 485 claves por idioma y dos razones de permiso, placeholders y plist válidos. No se ejecutó comparación de extracción del compilador porque este build no emitió .stringsdata; el validador lo señaló explícitamente. Las claves nuevas fueron contrastadas con el catálogo y la UI.
- El primer intento unitario no inició las pruebas por timeout del daemon; ver [incidentes](build-incidents.md). No se cuenta como aprobación.

Código `32e549bc1e38203c238e0afb91e0dd2e5dd556eb` publicado en main; Archive Cloud aprobado el 2026-10-12 15:13:38 UTC, check `114877221766`, cero errores y cuatro advertencias preexistentes de concurrencia/audio. Enlace y límites en [checkpoint](noise-checkpoint.md). Los dobles de captura prueban estados y preferencias, no reducción acústica. Pendiente comparación física de ruido, volumen con AGC desactivado, ruta, voces lejanas, traducción/reconocimiento real, alarma/reanudación y sincronía de la exportación.

## Build 21 — 2026-10-11

- **Unitarias finales:** 92 aprobadas, cero fallos, TEST SUCCEEDED (`build21-verified.log`, `VoiceToRead-21-Verified.xcresult`). Incluyen conservación del audio previo, valor inicial nuevo, idiomas independientes, permisos sin inicio automático y reglas de TextKit contrastadas con límites de tinta de CoreText a tamaños 20/28/44/70, anchos 280/700/280 e interlineados 0/4/16.
- **Release universal:** BUILD SUCCEEDED (`build21-release-final.log`), fuente 0.1.0 (21), familia `[1,2]`, identidad conservada. Sin firma local; no acredita upload. Dos advertencias de concurrencia existentes: callback onLevel y cierre onDismiss de traducción. No se declara migración a Swift 6 completa.
- **Localización:** 480 claves en inglés/español, paridad y placeholders comprobados; 370 claves extraídas por Swift cubiertas, incluyendo once etiquetas neutrales/formatos/ejemplo de vocabulario. Las razones de permiso incluyen dos recursos por idioma. `python3 scripts/validate-localization.py --extracted <Objects-normal/arm64>` reproduce la verificación.
- **UI iPhone:** cuatro escenarios aprobados en tandas dirigidas: lectura/renglones/pausa/giro, interfaz independiente durante pausa, preparación sin inicio automático y práctica de sesión española. La preparación pasó de nuevo tras corregir un aviso truncado (14,821 s, `VoiceToRead-21-Preparation-Final.xcresult`). Capturas revisadas. **iPad final:** tres recorridos (renglones/giro/reanudar, idioma independiente durante pausa y preparación) aprobados, `VoiceToRead-21-iPad.xcresult`, TEST EXECUTE SUCCEEDED. Capturas revisadas. Código publicado: `59f4eae`; Cloud y aceptación física se registran en [checkpoint](interface-checkpoint.md). Archive moderno aprobado para ese SHA el 2026-10-12 a las 00:39:42 UTC, check final `114617065401`, cero errores y cuatro advertencias existentes de audio/concurrencia. La captura/traducción real y la aceptación física se comprueban en dispositivos.

Los intentos iniciales detectaron uso incorrecto del alto de fragmento para dibujar reglas y pruebas con micrófonos ficticios que no soportan grabación. Ambos fueron corregidos antes de la suite final. No contabilizar esos intentos como aprobados. Ver [incidentes](build-incidents.md).


## Build 20 — 2026-10-11

Implementado: idiomas en-US/es-ES por sesión, traducción en ambos sentidos, Practicar idioma, familia iPhone/iPad, aviso persistente de pausa, colores claros y renglones. Esquema V7 e identidad sin cambios.

- **Unitarias:** 88 aprobadas, 0 fallos, Xcode 15.2 / iOS 17.2 Simulator (`VoiceToRead-20-Unit.xcresult`). Incluyen preferencias persistentes, bloqueo del idioma al pausar/reanudar, reapertura de sesión española, dirección de subtítulos, vocabulario inverso y payloads antiguos. Se ejecutaron antes del ajuste final de dibujo CoreGraphics y de congelar el diccionario por trabajo. El intento de repetirlas junto con UI quedó esperando al runner y se canceló: no sumar una segunda aprobación.
- **UI iPhone, fuente final:** `VoiceToRead-20-confirmed.log` registra aprobación de idioma/fondo/renglones/interrupción/fullscreen/giro/Reanudar (86,863 s) y práctica de sesión española (56,310 s). El recorrido de edición/audio/exportación había pasado en `VoiceToRead-20-UI.xcresult`; en la repetición conjunta no logró abrir Sessions, por lo que esa ejecución no pasó íntegra. XCTest se bloqueó después esperando el runner unitario; al cancelar no finalizó correctamente el xcresult. Conservar el log, sin presentar ese bundle como resultado completo.
- **Regresión aislada final:** `VoiceToRead-20-regression-final.log` abrió Sessions y completó corrección, guardado y reproducción. Tras confirmar SRT quedó esperando las consultas de accesibilidad de la hoja nativa de compartir (reintentos de 30 s); se canceló sin resultado final aprobado. La muestra de proceso no terminó, por lo que no se atribuye una causa definitiva. Una captura tardía (`VoiceToRead20-share.png`) mostró «Preparing file…»: no confirma que la hoja nativa llegara a presentarse.
- **Release de dispositivo final:** `VoiceToRead-20-release-final.log` terminó BUILD SUCCEEDED. Paquete 0.1.0 (20), UIDeviceFamily `[1,2]`, icono iPad y cuatro orientaciones, identidad original. Compilación sin firma local, no prueba de upload.
- **iPad:** configuración universal y capturas anteriores de vertical/fullscreen horizontal revisadas con fondo amarillo y pausa. La última prueba de renglones no inició XCTest y se canceló; aceptación final en iPad pendiente.
- **Estática:** plist y metadatos válidos, 166 enlaces locales de documentación sin roturas, `git diff --check` y sintaxis de `validate-macos.sh` correctos. No se ejecutó el antiguo validador PowerShell.

Artefactos locales: `/private/tmp/VoiceToRead-20-*`; [estado actualizado](accessibility-checkpoint.md). Xcode 15.2 no valida las ramas modernas de Speech/Translation. Probar modelos reales, alarma real, VoiceOver/tamaño accesible y ventanas/compartición en iPad físico. La publicación de fuente, el check de Cloud y la instalación TestFlight son evidencias diferentes.


## Entrega de código y compilación moderna

Código publicado en `main`: `25d24ac1308e0581830d2741c45ce76b6138e307`. [Archive – iOS](https://appstoreconnect.apple.com/) aprobado el 2026-10-11 a las 17:46:15 UTC; check `114533808792`, conclusión `success`, cero errores y cuatro advertencias (concurrencia de AVAssetExportSession/AVAudioPCMBuffer, import AVFAudio y nombre obsoleto allowBluetooth). Son advertencias en código de audio existente; no impidieron Archive. No declarar migración a modo Swift 6 completa.

Esto valida compilación moderna, no voz/traducción real, prueba física ni instalación TestFlight. Comprobar procesamiento, asignación al grupo Dev y actualización en el dispositivo. El commit posterior de documentación no cambia Swift ni configuración de la app.

## 2026-10-11 — Pronunciación local, source build 19

- Debug y Release final **BUILD SUCCEEDED** en Xcode 15.2/iOS 17.2, arm64/x86_64 de simulador. Metadatos revisados: build 19, identidad, iOS mínimo, permisos actualizados, orientaciones, background audio, assets y privacidad.
- Suite unitaria final: **83 pruebas aprobadas, cero fallos** (`/private/tmp/VoiceToRead-19-Unit-Final.xcresult`, `VoiceToRead-19-unit-final.log`). Incluye segmentación/comparación de texto, petición estrictamente local sin pistas, directorio separado/excluido de backup, limpieza sin tocar archivos vecinos, permiso denegado y permiso tardío tras cerrar.
- Primera ejecución UI: ambos escenarios de aprendizaje y pronunciación aprobados. Grabación real de simulador, reproducción, cierre y reapertura sin el intento anterior. El audio de prueba no valida calidad de voz, pronunciación ni reconocimiento real. Resultado: `VoiceToRead-19-Tests.xcresult`.
- En esa primera ejecución fallaron dos aserciones de una prueba unitaria: diferencias de barra final en URL y atributo de protección no expuesto por macOS/simulador. Corregidas comparando rutas y limitando la aserción de Data Protection a dispositivo. La protección sigue configurada en código; su comportamiento con bloqueo requiere iPhone físico. No se presenta como comprobada en simulador.
- Tras revisar las capturas se redujo el título y se evitó duplicar la frase en el selector. La UI final de pronunciación pasó en 39,348 s (`VoiceToRead-19-UI-Final.xcresult`, `VoiceToRead-19-ui-final.log`, **TEST SUCCEEDED**): grabación, reproducción, cambio de orientación, cierre, descarte del intento y selección de una palabra. Capturas de vertical revisadas; la captura horizontal coincidió con la animación de giro, por lo que la revisión visual completa de landscape queda para iPhone. Ver [checkpoint](pronunciation-checkpoint.md).
- Evidencia Release final: `/private/tmp/VoiceToRead-19-release-final.log`. Enlaces locales revisados, plist y diff correctos.
- No se implementa evaluación especializada, backend, Azure ni puntuación. El usuario confirmó continuar localmente. Cloud/TestFlight y aceptación física se verifican aparte.

## Build 18 — Aprender inglés y Capture Preferences (2026-10-10)

**TEST SUCCEEDED**: 76 pruebas unitarias y un recorrido UI dirigidos al aprendizaje. Verificadas V6→V7, expresiones tras reapertura/borrado, independencia de transcripciones, límites de audio, velocidad/repetición, español oculto/revelado y acceso por icono único de preferencias. Xcode 15.2, simulador iOS 17.2; la suite UI completa anterior no se repitió.

Release **BUILD SUCCEEDED**, metadatos e identidad verificados. Captura final inspeccionada. Evidencia y pasos restantes: [punto de reanudación de aprendizaje](learning-checkpoint.md). No se afirma entrega Cloud/TestFlight ni prueba física de esta versión. La primera compilación falló por una referencia de estilo privada y fue corregida antes de las pruebas finales.

## Build 17 — revisión de traducciones y vista en directo (2026-10-10)

- Debug y Release de simulador compilados con Xcode 15.2. Bundle Release verificado: build 17, identidad anterior, mínimo iOS 17, orientaciones, audio en background, assets y privacidad.
- **71 pruebas unitarias pasaron**, incluidas 10 de traducción: nuevas pruebas de actualización incremental, términos/espacios/persistencia del diccionario y cola acotada con respuestas tardías.
- Búsqueda española y bloqueo de traducción obsoleta pasaron en `/private/tmp/VoiceToRead-17-Tests.xcresult`. El conjunto inicial no pasó completo: el recorrido de compartir tenía dos expectativas antiguas (buscar «Hola» después de que el audio ya avanzó y localizar el selector por una etiqueta incompleta).
- La prueba se ajustó para comprobar inicio automático/Pause; esto detectó un fallo real de inicio del reproductor que motivó una selección identificable y una nueva verificación. El formato ahora usa segmentos visibles; resultado final en el [punto de reanudación](implementation-checkpoint.md).
- Evidencias: `/private/tmp/VoiceToRead-17-build.log`, `VoiceToRead-17-tests.log`, `VoiceToRead-17-ui-final.log`, `VoiceToRead-17-release.log`; resultados UI finales en `/private/tmp/VoiceToRead-17-UI-Final.xcresult`.
- 118 enlaces locales comprobados; proyecto plist y `git diff --check` correctos.
- Verificación final: **TEST SUCCEEDED**, recorrido de edición/audio/pausa/preview/SRT en 51,509 s (`VoiceToRead-17-UI-Verified.xcresult`). Release final **BUILD SUCCEEDED** (`VoiceToRead-17-release-final.log`). Las otras dos pruebas UI pasaron en la ejecución inicial.
- Código publicado como `a135f0e`. Cloud pendiente: las primeras consultas no mostraron check y la siguiente falló por conexión a api.github.com. No se afirma compilación moderna ni disponibilidad TestFlight para build 17.
- La ejecución real de Translation, las sugerencias del motor moderno, calidad, descarga de idiomas, latencia/batería y entrega TestFlight necesitan validación aparte. La vista en directo es temporal y experimental, no una traducción guardada automáticamente.

# Validation report — updated 2026-10-10

## Saved-session Spanish translation — 2026-10-10, source build 16

Implemented English/Spanish/bilingual saved-session reading, Apple's iOS 18+ Translation integration, separate machine/edited Spanish, source-change detection, translated text/PDF/subtitle sharing and English audio playback with translated captions. V6 adds SessionTranslation without changing V1–V5 model definitions or app/store identity.

- Xcode 15.2 / iOS 17.2 simulator: **67 compatible unit tests passed**, including six translation tests for V5 migration, persisted Spanish edits/deletion, stale English rejection, incomplete-result protection, subtitle timing/escaping and empty/short paragraphs. The Apple Translation branch is excluded by this SDK and was not exercised by these tests.
- The initial UI flow verified language selection, Spanish editing and translated playback, then failed because two nested navigation bars exposed Done. The test now scopes Done to the player. Following attempts could not activate the Menu share control after sheet dismissal, even after an accessibility wait. Sharing now uses an ordinary button and native format dialog. The stale-translation UI scenario passed. The final complete read/edit/play/share scenario passed after switching to the native share control’s actual accessibility type.
- Final targeted UI results: **two scenarios passed across final runs**. `VoiceToRead-Translation16-verified.log` / `VoiceToRead-Translation16-Verified.xcresult` passed language switching, Spanish correction/save, translated playback/pause and native SRT sharing. `VoiceToRead-Translation16-ui.log` passed stale-translation blocking (its other scenario failed before the share-control fix). The full pre-existing UI suite was not rerun. Portrait reader and return-from-player screenshots were inspected.
- Final Release simulator build passed for arm64 and x86_64: `VoiceToRead-Translation16-release-final.log`. Bundle checks verified source build 16, unchanged identity, iOS 17 minimum, microphone/speech strings, audio background mode, three orientations, assets and privacy manifest. Project plist lint, 111 local documentation links and Git whitespace checks passed.
- Test fixtures seed Spanish text only in DEBUG; they do not simulate or establish actual Apple translation quality, model downloads or offline operation.

Initial evidence: `/private/tmp/VoiceToRead-Translation16-tests.log` and `VoiceToRead-Translation16-Tests.xcresult` (67 unit passes, one UI pass, one initial UI failure). The modern Cloud archive also passed for implementation commit `d9ebefa526ba97486b8fc0dbd17585106ee64835`: [Archive – iOS](https://appstoreconnect.apple.com/), completed 2026-10-10 17:32:22 UTC. GitHub check `114271602766` reports success, zero errors and three existing audio concurrency warnings (AVAssetExportSession / AVAudioPCMBuffer / AVFAudio). This validates modern-SDK compilation, not runtime translation quality or installation. Actual iPhone translation and TestFlight tester availability remain unconfirmed.


## Capture feedback and phrase review — 2026-10-10, source build 15

Implemented paragraph-to-audio playback and a collapsible timed-phrase list; explicit capture/playback pause and resume; metering and recording/transcribing distinction; interruption recovery without automatic restart; local suggested names and inline editing; pinch resizing with accessibility alternatives. No schema, app identity or storage-path change.

- Xcode 15.2 / iOS 17.2 simulator: all 61 compatible unit tests passed. New coverage includes interruption→explicit resume preserving the draft UUID and final text, metering cleanup, local title fallback/limits, history rename preservation, and playback seeking without accidental pause. Audio recording/export and existing migration tests also passed. Modern AudioConversion tests remain unavailable with this compiler.
- The initial completed UI run passed pinch, pause/resume, paragraph-triggered playback and initial playback pause, but failed later on keyboard visibility and locating the phrase-list control. These were addressed with explicit title focus handling and an accessible button for the phrase list. The final focused UI reruns both passed; the full pre-existing UI suite was not rerun.
- Final UI evidence: `VoiceToRead-Review15-UIFinal.xcresult` / `VoiceToRead-Review15-ui-final.log` passed phrase-triggered playback and pause; `VoiceToRead-Review15-NameCheck.xcresult` / `VoiceToRead-Review15-name-check.log` passed pinch, capture pause/resume, clearing/editing the name, keyboard dismissal, landscape Save and the saved title in history. Portrait, landscape and phrase-playback screenshots were inspected. The intermediate name assertion failed because the test backspaced from the middle of the suggested title; the final flow uses the new clear-name button.
- Final Release simulator build passed for arm64 and x86_64. Bundle checks confirmed version 0.1.0/build 15, unchanged bundle identifier, iOS 17 minimum, microphone/speech purpose strings, audio background mode and all three supported orientations. Project plist lint, 98 local documentation links and Git whitespace checks passed. Release log: `/private/tmp/VoiceToRead-Review15-release.log`.
- Several earlier compilation attempts were intentionally cancelled while diagnosing SwiftUI type-checking cost. Diagnostic timing located a 175943 ms reader expression; separating its modifiers reduced the measured per-component checks below one second. This measures compilation only, not transcription performance.

Evidence outside Git: `/private/tmp/VoiceToRead-Review15-validation.log` and `VoiceToRead-Review15-Validation.xcresult` (61 unit tests passed; initial UI failures). New delivery and physical iPhone acceptance remain pending.

## Session preferences and explicit Save/Discard — 2026-10-10

Source build 14 adds persisted Audio/Background defaults, quick controls, circular capture buttons, one-tap new sessions after saving, and explicit Save/Discard. Schema V5 adds a SessionDraft marker without altering previous models. Stop checkpoints a recovery draft; only Save publishes it. Existing sessions remain saved. No bundle ID or storage path change was made.

Validated on Xcode 15.2, iPhone SE (3rd generation), iOS 17.2:

- All 59 compatible unit tests passed. New coverage checks preferences across relaunch, Stop versus Save, protection against starting over with a pending draft, isolated discard, V4→V5 migration, persistent draft recovery/publication and associated audio cleanup. Previous repository migration tests also passed. Modern AudioConversion runtime tests remain excluded by this compiler.
- Two targeted UI scenarios passed across final runs: global preferences persist without starting the microphone; circular controls, pending-draft cancellation, Save, one-tap new session, fullscreen rotation and confirmed Discard preserve the previous saved session. The full older UI suite was not rerun. Speech is mocked for these flows.
- Debug and Release simulator builds passed. The Release bundle was checked for version 0.1.0/build 14, unchanged identity, iOS 17 minimum, microphone/speech purpose strings, audio background mode, portrait/both landscape orientations, compiled assets and privacy manifest. Project plist, shell syntax, 106 local documentation links and git diff --check also passed.
- Portrait and fullscreen-landscape screenshots were inspected: controls remain visible and the reading area is unobstructed. VoiceOver labels and 44-point capture targets are present; full accessibility/device acceptance is still pending.
- Initial UI attempts exposed a synthetic 320-paragraph burst timeout and an assertion during rotation animation. The short workflow fixture now emits eight paragraphs, and the test waits for the rotated Stop button to become hittable. The final workflow rerun passed; this does not establish long-session performance.

Evidence remains outside Git under `/private/tmp`: `VoiceToRead-SessionFlow-14-final-tests.log` and `VoiceToRead-SessionFlow-14-FinalTests.xcresult` (59 unit tests and preferences UI passed; pre-fix rotation assertion failed), plus `VoiceToRead-SessionFlow-14-ui-check.log` and `VoiceToRead-SessionFlow-14-UICheck.xcresult` (final workflow passed). Release output: `VoiceToRead-SessionFlow-14-release.log`.

Delivery is pending: a GitHub push or successful simulator build does not update the iPhone. This feature requires a fresh archive built with an eligible modern SDK; do not reuse the previous build 13 archive. The earlier Cloud export failure and local signing workaround remain documented in [the distribution runbook](distribution-runbook.md). The user confirmed the previous iPhone update and working audio/background switches; build 14 is not yet device-validated.

## Earlier distribution evidence — 2026-10-10

This section records the earlier media/subtitle delivery. Dated sections below preserve the evidence and open gates as they were recorded; earlier statements such as “no upload” or “registration pending” are historical.

- Source for the media/subtitle delivery: commit 261b8b4. Local validation for that feature passed 56 compatible unit tests and 12 UI scenarios across final full/focused runs; see the recording section below.
- Cloud builds 9 and 10 archived with Xcode 27 (27A266a) but failed in export: managed session authentication warning, HTTP 502 on listTeams, then missing-profile errors.
- Cloud Build 11 archived with Xcode 26.6 (17F113); its app metadata reports SDK iphoneos26.5. Export failed with the same 502. Changing the toolchain did not fix Cloud.
- On the Mac, Xcode 15.2 exported that downloaded archive successfully. The IPA retained its modern build/SDK metadata; no local recompilation or metadata falsification was used.
- Distribution summary showed the existing bundle/team, a Cloud Managed Apple Distribution certificate, an App Store profile, beta-reports-active=true and get-task-allow=false.
- A second export operation with destination=upload, uploadSymbols=true and manageAppVersionAndBuildNumber=true completed at approximately 00:07 America/New_York on October 10. Output: Uploaded package is processing; Upload succeeded; EXPORT SUCCEEDED.
- This proves successful submission to Apple's processing pipeline, not completed processing, latest build installation, App Review approval or resolution of Cloud's automatic export.
- Screenshots at 04:37 confirm the first local upload completed processing as 0.1.0 (1), assigned to Dev, Ready to Submit, with one invitation and no recorded installs. This status allows internal testing.
- A copy of the same Cloud archive was re-signed and uploaded as 0.1.0 (13) with automatic numbering disabled. Archive executable equality, IPA version/bundle/SDK, distribution profile and codesign verification passed. Upload succeeded; processing/group availability of 13 and physical tests remain unconfirmed. No Swift implementation changed in this numbering correction. Earlier TestFlight 5/6 basic operation was user-confirmed.
- Modern source compiled, but modern AudioConversion runtime tests were not executed. Swift concurrency warnings on the Xcode 26.6 archive remain open; see the incident record.

Reproduction: [distribution runbook](distribution-runbook.md). Diagnosis, earlier obstacles and unsuccessful attempts: [incident history](build-incidents.md). Full private logs/artifacts are not committed.


## Transcript review, export and compact New Session — 2026-10-09

Added correction drafts with save/discard, undo/redo and original restoration; literal one/all find-and-replace with previews; one review screen for corrected full text or bookmarks, optional metadata, Copy, TXT/PDF saving and native sharing; saved reading positions and bookmark jumps. New Session is a 44-point blue circular +. Completed portrait sessions remove the footer to increase the reading area; fullscreen and landscape retain the control.

Corrections live in a new SessionReview model in schema V3, independent of the recognition captions and bookmark snapshots. The app identifier and storage location remain unchanged. Editing current listening/paused sessions requires Stop first. No speech engine or audio capture code changed.

Validation on Xcode 15.2 / iPhone SE (3rd generation), iOS 17.2:

- All 48 compatible unit tests passed. Coverage includes V1 and V2 store migration to V3, correction/save/reopen/restore, unchanged originals and bookmark snapshots, reading position, deletion, stale paragraph rejection, literal Unicode replacements and undo/redo. The modern audio conversion test remains excluded by this compiler.
- The actual PDF renderer generated an 18-page Unicode transcript. Tests verified every section and the final marker through PDF text extraction; all 18 PDFKit-rendered page images were inspected for clipping, margins and page numbers.
- UI verification includes dirty draft cancellation, original restoration, find/replace, corrected preview/bookmarks, metadata removal, clipboard action, PDF preview/native share presentation, bookmark navigation, reading restoration, the compact + and active-session edit protection. All 11 UI scenarios passed across the full run and focused reruns. The compact-button test checks a 44-point target, increased reader height and new-session confirmation in fullscreen landscape.
- Initial UI assertions targeted the wrong accessibility types for native confirmation/share controls and tapped the label instead of the switch. The long reader fixture also required waiting for its initial 320 paragraphs before Stop. Tests now target the actual controls and rendered live input. Screenshot review exposed lost horizontal margins after reading-position restoration; margins now belong to the scroll content. The replacement preview was simplified to show the changed word and resulting context, with a keyboard toolbar action to reveal the matches. The final editor flow passed again and its revised screenshots were inspected.

The six export/replacement tests passed again after adding a combining-accent word-boundary regression. Final Release compiled for arm64 and x86_64 simulator architectures. Bundle checks passed for app identity, iOS 17 minimum, all three orientations, purpose strings, assets and privacy manifest; DEBUG fixtures are absent. Plist lint, shell syntax and Git whitespace checks passed. The PowerShell validator was updated but not run on this Mac.

Evidence is stored in ignored local folder `build/review-ux-20261009/`. No external sharing destination was selected by automation. Actual Files round-trips, recipient delivery, VoiceOver/largest Dynamic Type and on-device upgrade testing remain manual checks for the new TestFlight build.

## Fullscreen, live following and reading tools — 2026-10-09

The user confirmed TestFlight build 6 works well on their iPhone and authorized all five follow-up improvements. This change adds fullscreen reading, automatic suspension of following when scrolling back, stable provisional caption rendering, persistent line spacing/bold/high-contrast preferences, and saved phrase bookmarks.

Fullscreen retains listening status and pause/stop/exit controls. The reader stays anchored to the latest text across size changes while following; scrolling back pins the start of the rendered transcript window until Back to live. Bookmarks preserve the selected text as a snapshot independent of later recognition revisions. Saving a bookmark explicitly saves the current session even when auto-save is off. The additive SwiftData V1-to-V2 migration preserves the original session/caption models, app identifier and storage directory.

Validation with Xcode 15.2 and the iPhone SE (3rd generation), iOS 17.2 simulator:

- All 42 compatible unit tests passed. The repository regressions also passed after the final deletion adjustment. Coverage includes opening a V1 database, preserving its session/captions, saving a bookmark, revising the original text, reopening the database and deleting the session with its bookmarks. The modern audio conversion test remains excluded by this compiler.
- All seven UI scenarios passed across the final full and focused runs. Fullscreen tests use over 300 deterministic paragraphs, verify the latest text remains visible through portrait and both landscape orientations, pause listening, exit and restore tab navigation. The rereading test checks a paragraph's position while the transcript grows, saves/reopens a bookmark, returns to the newest paragraph and pauses.
- Early UI test assertions read transient state during rotation/initial layout. The final tests wait for completed orientation/hittability and rendered incoming text. Screenshot inspection also revealed that long lazy stacks could lose the live bottom anchor during resize; the reader now uses a conditional bottom anchor and tests verify the latest paragraph after each rotation. Final portrait/landscape screenshots were inspected.
- Release compiled successfully for both simulator architectures. Bundle checks verified identity, iOS 17 minimum, all three orientations, purpose strings, assets and privacy manifest. DEBUG speech fixtures are absent from the Release binary. Shell syntax and git diff checks passed. The PowerShell validator's UI count was updated; PowerShell was not run on this Mac.

Evidence is in ignored local folder `build/focus-ux-20261009/`: initial full test results, repository/fullscreen focused results, final UI run, passing focused rereading run, Release log and screenshots. Actual microphone recognition, VoiceOver, largest accessibility text sizes and notched-device layout still need a check on the user's iPhone with this new build. The simulator inputs do not measure real-speech accuracy or battery use.

## TestFlight and reading experience — 2026-10-09

This update supersedes the historical installation-blocked status below. User screenshots show Xcode Cloud Archive build 5 completed and TestFlight 0.1.0 (5) was assigned to the internal Dev group. The user then confirmed successful installation and basic operation on their iPhone. Offline behavior, transcription accuracy and extended reliability were not separately measured.

The reader now uses a compact status header, an Aa settings sheet, a session actions menu and a primary Start/Pause/Resume control. In landscape, status and controls share a bottom row. Portrait and both landscape orientations remain enabled; app identity and stored-session format are unchanged. Full permission/error explanations remain accessible from the compact banner or session information.

Verification on Xcode 15.2 / iPhone SE (3rd generation), iOS 17.2:

- Debug compilation and all 40 unit tests passed. Neither speech engine was changed by this UI work.
- All five UI scenarios passed across the final full run and focused rerun: launch without permission prompts, microphone diagnostics, portrait/landscape-left/landscape-right rotation, readiness/privacy navigation, and reading options/session actions. The focused rerun corrected a test assumption: iOS may omit a disabled Save Session action when there are no final captions.
- The initial UI runs exposed a duplicate, untappable accessibility element in SwiftUI Menu. The final implementation uses a standard button and native confirmation dialog; rotation tests now verify the action button remains hittable, and the options test opens its session information screen.
- Release compilation passed for both simulator architectures. Bundle checks passed, including all three supported orientations, app identity, purpose strings, assets and privacy manifest. Shell syntax and git diff checks passed. The PowerShell validator was updated but not run on this Mac.
- Portrait and both landscape screenshots were inspected. On the small SE screen, the reader occupies approximately 66% of screen height in portrait and 61% in landscape even with the permission banner visible. The banner disappears once recognition is ready.
- A stalled macOS power service delayed validation; the user restarted it and the final checks completed afterward.

Local evidence (ignored by Git): `build/reading-ux-20261009/initial-tests.log` and `Initial-tests.xcresult` contain the 40 passing unit tests and initial UI findings; `ui-tests.log` and `UI-tests.xcresult` contain the final rotation/navigation run; `options-test.log` and `Options-test.xcresult` contain the passing focused options/actions rerun. `release-build.log` contains the final Release build. The `screenshots` subfolder contains portrait and both landscape captures.

The revised interface still needs a TestFlight check during real speech on the user's iPhone, including rotation while listening/paused, manual saving with final captions, VoiceOver and the largest accessibility text sizes. Prior build 5 success does not verify this new interface on a physical device.

## iOS 17 / Xcode 15.2 compatibility migration

The user authorized this direction on 2026-10-08. See [ADR-006](decisions/ADR-006-xcode-15-compatibility.md). This section supersedes the earlier build-blocked status below.

Environment: MacBookPro14,2, macOS Ventura 13.7.8, Xcode 15.2 (15C500b), Swift 5.9.2, iOS Simulator 17.2 (21C62), iPhone 15 simulator. The project now targets iOS 17.0 with Swift 5 language mode and explicit Xcode-compatible file references.

### Implementation

- Added an offline-only SFSpeechRecognizer backend: explicit speech authorization, en-US availability/support checks before capture and each request, requiresOnDeviceRecognition=true, no remote fallback.
- Requests rotate after about 50 seconds of submitted audio. A bounded audio queue preserves frames during finalization; overflow, interruptions and finalization timeouts stop visibly. System models are prepared through iPhone settings; this engine has no in-app model downloader.
- Preserved the modern engine behind Swift compiler 6.2+ and iOS 26 availability checks. It was not compiled/tested with this older toolchain.
- Updated purpose strings, readiness/permission UI, privacy copy, project format, scripts and development instructions. Explicit MainActor annotations resolve SwiftUI isolation errors under Swift 5.9.
- Simulator tests exposed a real orphan-caption failure when deleting a session. The repository now explicitly deletes related captions and clears the active-session cache. The existing deletion regression passed after the correction.

### Executed verification

- Debug simulator build: **passed** (both x86_64 and arm64 slices).
- Release simulator build: **passed**, with minimum iOS 17.0, microphone and speech purpose strings, compiled assets, no background capture modes and the expected privacy manifest checked in the generated bundle. Installed and launched Release independently in the simulator; the caption screen, permission action, reading controls and navigation tabs rendered correctly without an automatic permission prompt.
- Full iOS 17.2 simulator suite after the deletion fix: **40 unit tests and 3 UI tests passed**, zero failures. Tests cover compatibility speech policy/lifecycle, existing microphone/caption view models, transcript assembly/export, time/settings, SwiftData reopen/order/deletion, launch, readiness/privacy navigation and microphone diagnostics. Launch checks include the absence of app/system permission alerts.
- All eight new compatibility speech tests passed: offline request flags, explicit permission and unsupported-device refusal, denied/restricted/unavailable states, rotation/final text, audio queued during finalization, cancellation/late callbacks, timeout and overflow.
- There are 41 unit test methods in source; the additional modern AudioConversion test is excluded by this compiler. The modern iOS 26 engine remains separately unverified.
- Focused final persistence rerun: all three repository tests passed after retaining temporary stores until OS cleanup; the earlier SQLite open-file deletion diagnostics no longer appeared.
- Project structure check: 115 object references resolve; all 37 Swift files are registered in targets; both test targets and local documentation links are valid. Mac shell scripts pass bash -n and git diff --check passes. The Windows PowerShell validator was updated but was not executed on this Mac.

### Evidence

Generated logs and result bundles remain under build/ and are ignored by Git:
- build/compatibility-debug.log: successful Debug compilation.
- build/compatibility-release.log: successful Release compilation.
- build/compatibility/release-launch.png: visually inspected standalone Release launch.
- build/compatibility-tests.log and build/compatibility/Tests.xcresult: first full run, which exposed the deletion failure.
- build/compatibility-tests-fixed.log and build/compatibility/Tests-fixed.xcresult: full suite passed after the fix.
- build/compatibility-repository-tests.log and build/compatibility/Repository-tests.xcresult: three final persistence regressions passed without SQLite cleanup diagnostics.

Run bash scripts/validate-macos.sh for Debug, unit/UI tests, Release and bundle checks. Set VOICETOREAD_SIMULATOR_ID to choose a particular installed compatible simulator. The focused bash scripts/validate-assembler.sh is still available.

### Physical iPhone follow-up

The iPhone was detected again over USB. The compatibility app compiled for the physical arm64 iPhone platform, and a generic iOS build was signed with an existing Apple Development identity (development bundle ID override: com.innovalogic.voicetoread). Logs: build/device-build.log and build/device-generic-signed-build.log. No signing settings or credentials were added to the repository.

A build addressed directly to the phone timed out with “Waiting to reconnect.” A more detailed developer-image probe returned CoreDevice error 10003: **the device is locked**. This corrects the earlier assumption that the mounting failure alone established an Xcode/iOS compatibility problem. A subsequent lock-state probe reported passcodeRequired=false. Retrying developer-image activation then failed with a different error: 0xe8000076 / kAMDMobileImageMounterImageMountFailed, “Could not support development.” The connection therefore remains blocked after the locked-device error was cleared. Evidence: build/device-ddi.log and build/device-ddi-retry.log.

The signed bundle passed codesign verification outside workspace isolation. Its embedded provisioning profile still does not include this phone; registration/profile refresh remains necessary. The direct-device build could not register it because the destination never became eligible. No installable-for-this-phone build was produced and no app was installed.

Apple documents hardware support updates through xcodebuild -runFirstLaunch -checkForNewerComponents ([component documentation](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)); the installed Xcode 15.2 help does not expose the newer component-update option. No system/Xcode update or third-party device image was installed. Actual speech tests remain pending.

### Requested installation retry

On the next user-requested retry, USB pairing was available but developer-image activation again failed with error 0xe8000076 (“Could not support development”). The direct-device signed build timed out with the phone marked ineligible/waiting to reconnect. A separate attempt to install the already-signed physical-device app using devicectl device install app also failed during developer-image mounting, before app installation or profile validation. Logs: build/device-ddi-latest.log, build/device-retry-build.log and build/device-install-retry.log. No physical installation or speech test succeeded.

### Remaining device/release gates

Real speech, offline asset availability, accuracy, continuity at request boundaries, microphone/permission recovery, 30/60/120-minute behavior, accessibility, binary privacy/network review and a signed archive remain pending. Mocked speech tests do not prove transcription quality or offline operation. The connected iPhone 15 reported iOS 27.0.1 and Developer Mode enabled, but developer-image activation failed first while locked and then with “Could not support development” on retry. Compatible developer services and a profile including the phone are still required. No build was installed on the physical iPhone.

## Before the compatibility migration: original iOS 26 target blocked
Base commit: 9b4bafb3e8226e83c0516b505b6e42e364f2031d, plus the local assembler fix and regression test described below.

Environment: MacBookPro14,2 (Intel x86_64, 16 GB RAM), macOS Ventura 13.7.8 (22H730), Xcode 15.2 (15C500b), Swift 5.9.2. Selected developer directory: /Applications/Xcode 15.2.app/Contents/Developer.

The project requires Swift 6 and the iOS 26 SDK. Running bash scripts/validate-macos.sh exited with status 1 and "Xcode 26+ is required." It stopped before Debug build, simulator testing or Release build. An initial simctl probe also failed under workspace restrictions; it does not establish whether runtimes are installed. No iOS app was compiled or launched.

Apple lists [Xcode 26 as requiring macOS Sequoia 15.6 or later](https://developer.apple.com/xcode/system-requirements) and [MacBookPro14,2 as a 2017 model whose newest supported OS is Ventura](https://support.apple.com/en-us/108052). Full validation therefore needs a different supported build host, local or remote; an ordinary supported OS/Xcode update on this model cannot meet the requirement.

### Connected iPhone check — 2026-10-08

A USB check detected an iPhone. The initial restricted devicectl probe reported no devices; repeating it outside workspace isolation detected a paired, available iPhone 15. Device details reported iOS 27.0.1 (24A446), a wired connection and Developer Mode enabled. Device identifiers and serial numbers are intentionally omitted from this report.

The details command warned: "The developer disk image could not be mounted on this device" and reported ddiServicesAvailable=false. Xcode remains 15.2. The physical connection and pairing are confirmed, but developer services and app installation/debugging are not validated. No app was installed or launched. Full device testing needs a build host with the required SDK and Xcode support for the connected phone's OS.

### Executed checks
- Native plutil validation passed for project.pbxproj and PrivacyInfo.xcprivacy.
- Project structure: all 37 object references resolve, three targets, both scheme test targets, source directories and both microphone usage descriptions checked.
- Privacy plist tracking flag, asset catalog JSON and opaque RGB 1024x1024 icon checks passed. These are source checks, not a binary privacy audit.
- Swift 5.9.2 parsed all 34 Swift files successfully with swiftc -frontend -parse. This is syntax parsing, not type checking of the app or validation of iOS 26 API signatures/concurrency.
- All three Mac shell scripts passed bash -n; git diff --check passed.
- Seven original TranscriptAssembler XCTests passed against the unchanged source in an isolated native macOS Swift package, including the 10,000-segment case.
- A new regression test reproduced a late-revision ordering error: after runs "One" then "Two", revising the first run produced "Two / One revised.". The assembler now remembers run order even when replacing every existing segment of a run, preserving segment identity and returning "One revised. / Two".
- After the fix, bash scripts/validate-assembler.sh compiled the actual assembler source and ran all eight assembler XCTests: **8 passed, 0 failures**. No Speech/SwiftData/UI substitutes were included; those components were not tested.

### Local evidence and reproduction
Run bash scripts/validate-assembler.sh to repeat the focused tests. The script creates a fresh package from the repository source/test files and retains logs under build/assembler-validation.*. These generated artifacts are ignored by Git.

Evidence from this validation:
- build/validation-local/assembler-tests.log: original seven tests passed.
- build/validation-local/assembler-regression-before.log: new regression failed before the fix (eight tests, one failure).
- build/assembler-validation.9HQRoh/tests.log: all eight tests passed after the fix.
- build/validation-local/swift-parse.log: empty diagnostics from successful syntax parsing before the assembler fix; the modified assembler was subsequently compiled by the focused test run.

The suite now contains 33 unit tests and three UI tests. Only the eight assembler tests have executed; the remaining 25 unit tests and all three UI tests are pending. Microphone capture, real English captions, Airplane Mode, model installation, SwiftData persistence, export/share UI, accessibility, signing and extended reliability remain unverified. No claim of app or release readiness follows from these focused tests.

## Historical Windows validation — 2026-10-07
### Executed and passed on Windows
- OpenStep project syntax parsed, all 37 object references resolved.
- Three targets, synchronized source groups and both shared-scheme test targets checked.
- Microphone purpose in Debug and Release configurations verified.
- Privacy manifest XML and UserDefaults CA92.1 / DiskSpace E174.1 reasons checked.
- Asset catalog JSON parsed; icon is 1024x1024 opaque RGB PNG and visually inspected.
- App Store draft name/subtitle/keyword bytes/description lengths checked against documented limits.
- Authored-file whitespace and local documentation links checked.
- Swift delimiter/source-surface inspection; no application HTTP client, legacy recognizer, audio-file recorder or apparent secret pattern found.
- Mac shell-script syntax checked using Git Bash bash -n.
- 32 unit tests and 3 UI tests confirmed present, not executed.
- Git diff --check required before the final local commit.

### Not executed / not verified at that time
Xcode/Swift compilation, XCTest, simulator launch, microphone capture, actual English captions, Airplane Mode speech, asset installation, physical persistence/share/permission behavior, accessibility, network/privacy binary report, store-sidecar protection, device matrix, signed Release archive and 30/60/120-minute profiling.
xcodebuild is unavailable on this Windows host. These are open acceptance gates, not passing results.

## Next full validation
Run bash scripts/validate-macos.sh on a Mac, resolve compiler/test failures, execute testing.md and reliability.md on physical compatible iPhones, and finish release-checklist.md with owner identity/signing/URLs/license details.
The source is implementation-ready for this validation handoff; App Store readiness is not certified.

## TestFlight preparation (2026-10-08)

- Configured automatic signing for team `7799N4RYUG`, app ID `com.innovalogic.voicetoread`, and matching test target identifiers. Apple registration is pending.
- Release arm64 device build passed with Xcode 15.2 and signing disabled after the configuration change. Bundle metadata verified: version 0.1.0, build 1, minimum iOS 17.0. Log: `build/testflight-preparation-build.log`.
- Prepared branch `codex/testflight-preparation` for Xcode Cloud. Cloud onboarding, a build with an eligible Xcode 26+ SDK, TestFlight upload, and physical speech testing remain pending. This local build is not an uploaded or distribution-signed binary.

## VoiceToRead rename (2026-10-08)

- Renamed the Xcode project, shared scheme, app/test targets and source folders to VoiceToRead. Updated user-visible captions title, permission descriptions, privacy text, export fallback, metadata, scripts and documentation.
- Kept `com.innovalogic.voicetoread`, the existing test bundle identifiers and the internal `VoiceToRead/Sessions.store` location. The schema and model definitions were not changed. Migration from a previously installed development build has not been separately tested.
- Debug simulator build passed. On iPhone SE (3rd generation), iOS 17.2: 40 unit tests and 3 UI tests passed with zero failures, including the new navigation title and transcript export fallback.
- Release simulator build passed. Verified display name/executable `VoiceToRead`, unchanged bundle identifier, iOS 17 minimum, microphone/speech purpose strings, compiled assets and privacy manifest.
- Project references, shared-scheme targets, metadata field lengths, shell-script syntax and Git whitespace checks passed. The PowerShell validator was updated but not executed on this Mac.
- Logs/result bundle: `build/rename-validation.log` and `build/validation-20261008-113618/Tests.xcresult`. These inherited checks ran before a workspace move in the base project; renamed paths are illustrative rather than available local artifacts. Earlier validation artifacts belonged to the previous checkout and were deleted when the user replaced that checkout.
- The GitHub repository is now `dafermen/VoiceToRead`. App Store Connect name registration, Xcode Cloud onboarding/build and TestFlight upload remain pending.

## 2026-10-09 — optional recording and synchronized subtitles

Added opt-in local audio recording, sample-clock timing across speech rotations and pause/resume, playback with fullscreen captions, editing from playback, M4A/SRT/WebVTT and combined sharing, independent audio deletion, and opt-in background listening. V4 adds media metadata without changing prior model definitions.

Validation on Xcode 15.2 / iOS 17.2 iPhone SE (3rd generation) simulator:
- 56 compatible unit tests passed, including CAF recording/decoding, pause concatenation, M4A export/decoding, file-write failure preservation, native speech-run offsets, subtitle formatting/escaping/corrections, V3 migration, audio/session deletion and background opt-in/reset. The modern conversion test is excluded by this older compiler.
- All 12 UI scenarios passed across the final full run and focused rerun. The focused run verified rereading under a 320-paragraph fixture, synchronized playback, fullscreen rotation, editing from the player, native SRT sharing and deleting audio while retaining text/subtitles.
- The initial UI run exposed a lazy-stack timing issue: following now coalesces updates and repeats scrolling after layout, including size changes. A fixture-load wait was aligned to the existing 20-second long-transcript wait. Native share dismissal and duplicate editor labels were corrected in the UI test.
- Debug and Release simulator builds passed; release app identity, portrait/landscape support, background audio array and revised microphone purpose string inspected. DEBUG media fixtures absent from the Release binary.
- Project/plist syntax, source registration, shell syntax, documentation links, metadata limits and git whitespace checks passed. PowerShell static validation was updated for the authorized recorder and 12 UI cases; PowerShell itself was not executed on this Mac.
- Real screenshots reviewed for player portrait/landscape and caption fullscreen. Local evidence is in ignored `build/media-20261009/`.

Device-only validation remains: speech recognition accuracy and timing across long sessions, microphone coexistence with the actual source apps, screen-lock/background operation, calls/route changes, storage exhaustion, protection/backup and battery use. This implementation does not capture internal audio from other apps. Subtitle timing after text changes can be estimated within the original paragraph range. See media-and-subtitles.md.

## Build fuente 23 — 2026-10-13

- 99 tests unitarios pasaron, incluida migración V7→V8, reapertura/protección, audio limitado y exportaciones. Evidencia: `/private/tmp/VoiceToRead23-final.xcresult` (bundle global fallido por dos recorridos UI luego corregidos; no atribuirle éxito total).
- iPhone SE 3 / iOS 17.2: A mi ritmo, corrección y favoritas pasó (48.547 s); idioma conservando sesión pausada pasó (19.241 s), en ese bundle.
- Exportación SRT y borrado independiente pasó (65.656 s) en `/private/tmp/VoiceToRead23-review.xcresult`; ese bundle conserva un fallo anterior del selector de traducción.
- Traducción: edición desde playback, Cancelar/descartar borrador, retorno al mismo párrafo y compartir pasó (92.960 s) en `/private/tmp/VoiceToRead23-translation.xcresult`, TEST SUCCEEDED. Usa traducción prefijada; no mide el motor real de Apple.
- iPad Air 5 / iOS 17.2: idioma pasó (21.944 s) en el bundle ipad; A mi ritmo/favoritas pasó en ipad-final (45.475 s) y se confirmó rotación con espera de ancho>alto en ipad-rotation (46.861 s), TEST SUCCEEDED.
- Release genérico iOS sin firma pasó: `/private/tmp/VoiceToRead23-release-final.log`. Se verificó build 23, bundle original, familias iPhone/iPad, mínimo iOS 17, modo audio de fondo y presencia del manifiesto.
- Catálogos: 507 claves + 2 propósitos de permisos por idioma; sin diferencias de claves/placeholders. No se generaron stringsdata para comprobación por extracción.
- Metadata de tienda EN/ES dentro de límites; enlaces locales de Markdown válidos. El modo --ready rechaza correctamente la publicación aún incompleta.

Se inspeccionaron las capturas de lectura/favoritas y el iPad. Los ajustes de los fixtures, desplazamiento de listas y popover están en build-incidents.md. Evidencia de entrega y límites: [checkpoint](pace-checkpoint.md). Pruebas físicas de audición/VoiceOver, operación larga, protección con bloqueo, ruido y modelos reales siguen pendientes antes de publicar.

### Resultado Cloud de la entrega 23

El SHA `40af9bd1310881a9d6c3cd37de9b38c2cf235ced` pasó Archive - iOS el 2026-10-13 a las 04:22:27 UTC. Check final `115127872696`: 0 errores, 0 fallos de tests reportados, 0 incidencias de análisis, 4 advertencias. La suite local es evidencia separada; el archivo Cloud no prueba ejecución de tests ni instalación en el teléfono. Estado general GitHub success. Detalles y límites en [checkpoint](pace-checkpoint.md). La API de anotaciones no incluyó el texto de las advertencias.

## Build fuente 24 — 2026-10-13

Traducción en vivo Original/Traducción/Ambos. Pasaron 13 tests de traducción, los recorridos UI de ambos sentidos en iPhone, el recorrido bilingüe en iPad y Release genérico sin firma. Se corrigió el selector y su anclaje antes de repetir las pruebas. Resultados exactos, capturas y límites del proveedor DEBUG en [checkpoint](live-bilingual-checkpoint.md). Cloud/TestFlight y motor Apple real se verifican por separado.

## Corrección fuente 26 — 2026-10-13

Release local pasó (`/private/tmp/VoiceToRead26-release.log`). Xcode Cloud confirmó Archive - iOS del SHA `2da928440decb7c7d4da2bdac58dcce2b5ae10b0`, check `115263454589`, success: 0 errores y 4 advertencias. Se corrigió el result builder de la vista auxiliar moderna; no se volvieron a ejecutar recorridos UI por este cambio de compilación. Ver [checkpoint bilingüe](live-bilingual-checkpoint.md) para pruebas previas, fallos y disponibilidad aún no confirmada en TestFlight.

### 2026-10-13 — Tarjetas bilingües, fuente 27

Ambos separa los párrafos en tarjetas por idioma, con modo oscuro y alto contraste. Pasaron dos recorridos bilingües iPhone y dos revisiones iPad (oscuro / contraste aumentado), con screenshots inspeccionados; Release sin firma y validadores de localización/metadatos correctos. Ver rutas, límites y estado remoto en [checkpoint bilingüe](live-bilingual-checkpoint.md#tarjetas--fuente-27-2026-10-13). El usuario confirmó funcionamiento de la vista bilingüe anterior en su iPhone; esa confirmación no valida todavía las nuevas tarjetas.
