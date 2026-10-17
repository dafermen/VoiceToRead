# Testing through Phase 9

## Build 22: reducción de ruido

- Persistencia opt-in independiente de audio/idioma; cambiar la opción no inicia captura.
- Instantánea activa conservada al pausar/reanudar, preferencia nueva aplicada a la próxima sesión.
- Error de configuración no inicia Speech sin filtro ni crea un borrador antes de esa validación.
- Acceso rápido, valor actual frente a preferencia futura y localización en iPhone/iPad.
- Comparación **física pendiente**: voz cercana/lejana, ruido continuo, otras voces, altavoz del mismo dispositivo, auriculares, alarma y reanudación. Escuchar/exportar audio, verificar volumen, reconocimiento y tiempos SRT. Los dobles UI no ejecutan DSP.

[Guía y límites](noise-reduction.md); [evidencia de esta entrega](noise-checkpoint.md).

## Matriz adicional build 20

- Inglés inicial y preferencias idioma/papel/renglones persistentes; valores desconocidos vuelven a defaults.
- Español seleccionado antes de iniciar, bloqueo durante escucha/pausa, reanudación conservando idioma; nueva sesión cambia idioma.
- Payload inglés antiguo decodificable; sesión española y traducción inglesa persistentes; exportación original/traducida/bilingüe con tiempos válidos; no reutilizar snapshots del otro idioma.
- UI: idioma, fondo amarillo y renglones, interrupción simulada, banner y Reanudar en fullscreen/landscape; práctica desde sesión española. Ejecutar iPhone SE e iPad Air.
- Manual físico: alarma real, Bluetooth, bloqueo/segundo plano, español con distintos acentos, reconocimiento offline por idioma, traducción moderna ambos sentidos, pronunciación local. No confundir fixtures con prueba del modelo.
- Accesibilidad: VoiceOver con foco en Reanudar, tamaños de accesibilidad, contraste, colores claro/oscuro y reglas desactivadas por alto contraste; usuarios con distintas necesidades. iPad: ventana dividida, rotación, compartir y teclado.

Resultados comprobados: [checkpoint build 20](accessibility-checkpoint.md).

The project now builds with Xcode 15.2/iOS 17. On the iOS 17.2 simulator, 56 compatible unit tests and 12 UI scenarios passed across the full and focused validation runs. The modern AudioConversion test is excluded by the older compiler. See validation-report.md for logs and remaining gates. Simulator tests do not verify actual speech, offline model availability or a physical iPhone.


## Automated suite
- ListeningViewModelTests: 12 permission/start/stop/error/lifecycle tests.
- TranscriptAssemblerTests: 9 partial/final/duplicate/repeated-text/run-order/late-revision/merge/10,000-segment regressions.
- CaptionViewModelTests: 5 readiness/finalization/pause-resume/background-option/reset tests.
- TranscriptRepositoryTests: 6 upsert/rename/delete/order/reopen, V1/V2-to-V3 migration, bookmark snapshot, correction/original preservation and reading-position tests.
- TranscriptExportTests: 6 Unicode/metadata/filename, literal one/all replacement, undo/redo, corrected bookmark export and multipage PDF tests.
- AppSettingsTests: 2 preference/readiness tests.
- LegacySpeechTranscriberTests: offline request flags, authorization/support refusal, request rotation, queued audio, cancellation, timeout and overflow.
- AudioConversionTests: 1 sample-rate conversion test, only compiled with Swift 6.2+ and requiring iOS 26.
- SessionClockTests: 1 invalid/long-duration test.
- SessionMediaTests: 6 scenarios covering recording/decoding, export, capture timeline, subtitle construction, migration and deletion.
- HomeScreenTests: 12 tests covering launch without permission prompts, settings/readiness/privacy, microphone diagnostics, reading options, both landscape orientations, fullscreen during listening and rereading/bookmarking during incoming captions. Reader/media scenarios use deterministic DEBUG-only speech/audio fixtures and isolated stores. The player scenario covers correction, subtitle sharing and audio deletion. These fixtures do not prove real microphone accuracy.
Run bash scripts/validate-macos.sh. Do not infer device speech support from passing mocked/simulator tests.

## Phase 1 microphone diagnostics
Settings > Microphone Check: launch without permission prompt; Start and grant permission; speak/check meter; Stop clears meter/indicator. Repeat 20 times.
Deny access on a fresh permission reset, check error/Settings recovery. Background/lock/call/Siri and input changes must stop safely, with no automatic restart. Verify built-in mic is used.
Volume monitoring is not speech recognition and cannot prove offline captions.

## Phase 2 actual offline speech
1. Record device model, iOS, Xcode/SDK/build and English asset status.
2. While online, Settings > Offline Readiness, allow microphone and Speech Recognition if requested. With the compatibility engine, prepare English (US) Dictation in iPhone Settings if support is unavailable and refresh; no in-app model downloader exists for this engine. With the modern engine, Install English Model explicitly.
3. Enable Airplane Mode and turn Wi-Fi off; reopen/refresh readiness.
4. Captions > Start Listening, speak a known English passage. Observe provisional revisions and final text without duplicate ranges.
5. Record measured/observed start latency, live-caption delay, accuracy and failures; no numbers are provided before observation.
6. For the compatibility engine, speak continuously across several 50-second request boundaries; check for missing/repeated words and ensure preceding final chunks remain saved. Stop and inspect finalization. Test unsupported hardware/locale and missing assets without silent download or cloud fallback.

## Phase 3 reading/accessibility
Pause/Resume retains earlier final captions and excludes paused time. Stop ends capture and exposes Save/Discard. New Session is one tap after Save; a pending draft requires an explicit decision.
Use Aa to adjust caption size and following; use (…) Session actions for manual saving, New Session and full status information. Check largest Dynamic Type, light/dark/system appearance, contrast, VoiceOver and Reduce Motion. Rotate while listening, paused and stopped in both directions; verify captions, elapsed time and chosen text size remain intact and controls remain reachable.
Disable live following, load earlier captions and re-enable follow. Confirm screen wake only while listening/viewing captions and normal sleep on Stop/background.
Enter/exit fullscreen while listening, paused and rereading; check Pause/Stop/Exit remain accessible and tabs return on exit. Test notched iPhones as well as small screens.
Scroll back during incoming speech and confirm the same paragraph stays visible, then use Back to live. Load earlier captions in a transcript longer than 300 paragraphs. Check provisional text revisions do not flash or animate repeatedly.
Change line spacing, bold text and high contrast, then relaunch. Test these with largest Dynamic Type and both color schemes.
Long-press a finished paragraph > Save bookmark; view it through (…) > Bookmarks and Sessions > session > Bookmarks. Bookmarking checkpoints the draft without publishing it. Remove a bookmark and confirm the transcript remains; delete its session and confirm its bookmarks disappear. Update from a V1 store and verify earlier sessions survive.
Perform a 30-minute read-along.

## Phase 4 storage and recovery
Start/speak/stop, choose Save Session, force normal app termination/relaunch and open Sessions. Check title/date/duration/language, rename, title/finished-transcript search and confirmed delete.
Interrupt/terminate during listening: finalized saved segments should recover as an unfinished session; provisional text is not guaranteed.
Exercise low storage/write/startup failures. Errors must be visible, saving retry must not duplicate captions, and failed store opening must not destroy data.
Current session deletion is disabled until Stop; discarded drafts must remove text and audio without affecting other sessions.

## Phase 5 export
Open a saved session > Review & share; select TXT or PDF and use Save file/Share. Inspect UTF-8 text or rendered PDF and selected metadata. Exercise Copy separately. Audio & subtitles is the separate player/media export flow.
Cancel native dialogs and confirm the session remains. Test unusual/long titles and large transcripts. Explicit destination sharing may transmit text.

## Transcript editing and review
In Sessions, stop any current session before editing it. Correct a paragraph, apply it to the draft, undo/redo, save, close and reopen. Verify both the corrected wording and the original restoration. Cancel a dirty paragraph and a dirty transcript; confirm each explicit discard leaves saved text intact. Try multiline, accented and emoji text.

Find a repeated misspelling. Preview the matches, replace one, then replace all. Check whole-word/case options, literal punctuation, deletion via an empty replacement and Undo. Search the session history for the corrected wording.

Review & share must show the same corrections in full text, bookmarks, clipboard, TXT and PDF. Toggle session details; inspect a long PDF's first, middle and last pages. Save both formats in Files, reopen them and share a test file to a chosen destination. Cancel each native picker and ensure the session remains unchanged. No external destination is exercised automatically by UI tests.

Scroll a long saved session, leave and reopen it. Jump to a bookmark, reopen again and verify the last read paragraph is visible. Existing bookmark snapshots without a current paragraph remain readable. Migrate an existing installation containing sessions/bookmarks without deleting the app.

After Stop, verify Save/Discard appear; after Save, the portrait decision footer disappears. The circular + opens a new session immediately when saved, and requests a decision only for a pending draft. Check portrait, both landscape orientations and fullscreen.

## Phase 6 readiness/settings
Change Audio/Background in Captions and Settings, then relaunch. Choices persist without starting the microphone. During capture, Audio changes affect the next session and Background changes affect the current session. Stop leaves a recovery draft until Save/Discard. Reopen without deciding and recover the draft from Sessions.
Test all actual readiness states, permission recovery and unknown/low disk space. Test Offline Mode is guidance, not Airplane Mode detection.
The 64 MB check reserves transcript headroom; initial model download may need much more.

## Phase 7 reliability
Follow reliability.md for 30/60/120-minute memory/CPU/battery/thermal/latency measurements.
Test calls/Siri, accessory input/configuration changes, media-service resets, lock/background, low battery/storage and missing model changes.
Unchanged built-in input can continue across accessory setup events; actual input loss or stopped-engine changes must stop capture.
Inject queue overflow/missing-frame/slow-finalization failures in debug builds and restore code before release.

## Phases 8–9 production gates
Inspect built privacy manifest/report, permission wording, store/WAL protection and backup exclusion, logs and actual network behavior after model setup.
Verify no automatic uploads, no audio saved unless explicitly enabled, independent audio deletion, session deletion, protected recording files and explicit sharing behavior. Follow media-and-subtitles.md for pause/resume, playback, timing and background device tests.
Run Release simulator validation and signed device archive; check icon/dark/tinted variants, genuine screenshots and all release-checklist.md items.

## Evidence record
For each run record date, source commit, device/OS/SDK, scenario, result, latency/metrics, failure and retest. The user confirmed basic operation of TestFlight 0.1.0 (5) and (6) on their iPhone on 2026-10-09. The detailed physical scenarios above, including the revised reader during live speech, still require individual verification.

## Build 15 acceptance
- Start transcription with audio off: Transcribing and live level, no red recording indicator. Audio on: Recording only after recorder/capture starts. Pause: level clears, microphone stops, Resume keeps the session.
- Interrupt capture, keep finalized text/draft, return to foreground without automatic restart, then explicitly Resume. Verify repeated failure if microphone remains unavailable.
- Pinch to increase/decrease text, verify 14–60 base-point bounds, relaunch to verify persistence, rotate/fullscreen and use Aa/VoiceOver alternatives.
- Save with default title, custom title, whitespace-only title and long title; verify history/search after reopening.
- Tap a timed paragraph; verify playback jumps, Play/Pause and another cue work. Test corrected text, absent timing, deleted/truncated audio and no overlap with capture.

## Build 16 translation acceptance

Verify V5→V6 migration, persisted Spanish edits, unchanged English, incomplete-result rejection, stale-source detection and cascade cleanup. Verify both-language subtitle timestamps, escaping and text conservation. UI fixtures cover saved translation selection/edit/play/share and stale translation blocking; they are not Apple translation tests. On an iOS 18+ iPhone test real English→Spanish, first download, download refusal, cancellation mid-session, retry, offline after download, long paragraphs, Spanish corrections, source correction/retranslation and upgrade without losing sessions.


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).


Para los catálogos de interfaz: `python3 scripts/validate-localization.py`. Tras compilar con `SWIFT_EMIT_LOC_STRINGS=YES`, añadir `--extracted <carpeta Objects-normal/arquitectura>` contrasta las claves que Swift detectó. Esto complementa las pruebas UI: no detecta por sí solo textos String que se presenten sin LocalizedStringKey.

## Actualización 23 — 2026-10-12

Build 23 añade tests para migración V7→V8/reapertura, impedir borrar sesión/audio, retirada de protección sin borrar, rango completo de párrafo, audio parcial, corte/repetición/callback obsoleto, edición directa y etiquetas de navegación EN/ES. Evidencia final en [checkpoint](pace-checkpoint.md).

## Live bilingual reading — source build 24

Run `HomeScreenTests/testLiveBilingualEnglishCapture` and `testLiveBilingualSpanishCapture` on iPhone/iPad. They select Both while capture is active, assert capture stays active, pause explicitly, verify original/translation pairing by UUID, switch to Translation and Original, then return to Both and rotate fullscreen. The DEBUG provider uses fixed translations; these tests do not validate Apple model downloads, latency or quality.

On a physical device with the modern build, choose both directions, prepare languages, speak new sentences and compare original/translation pairs. Check provisional text, delayed translation/error retry, long sessions, background/foreground, reading earlier paragraphs without jumps, large Dynamic Type and VoiceOver. Confirm that changing display leaves audio/capture running and reopening retains the chosen display.

For source 27 cards, inspect the retained bilingual screenshots in portrait and landscape: English blue/Spanish green in either capture direction, compact padding, rounded outlines, readable labels and unclipped text. Also inspect dark appearance and increased/high contrast (monochrome strong borders), including provisional/waiting cards. Color must not be the sole language cue. These visual checks supplement the existing pairing and capture-state assertions.

## Rango de letra ampliado — 2026-10-16

- Simulador iPhone 15 / iOS 17.2: 9 pruebas `AppSettingsTests` y 2 pruebas de interfaz aprobadas, sin fallos.
- `testReadingOptionsDoNotOccupyTheReader` verifica selección de 14 y 60 puntos, conservación al reabrir y área de lectura sin controles permanentes.
- `testLongPlaybackParagraphScrollsAndPreviousRestoresIt` verifica desplazamiento de un párrafo largo y regreso a él con Anterior.
- Evidencia local: `/private/tmp/vtr-font-range.xcresult`, `/private/tmp/vtr-font-range.log` (`TEST SUCCEEDED`). Localización EN/ES: 658 claves y 2 permisos coincidentes; 467 claves extraídas cubiertas.
- Esta comprobación no sustituye la prueba física en el iPhone del usuario; la entrega en TestFlight requiere completar Xcode Cloud y el procesamiento de Apple.

## Biblioteca y cuatro idiomas (2026-10-17)

- Migrar un almacén V10 con traducción antigua a V11; conservar fuente, traducción, favoritas y audio.
- Verificar doce pares origen/destino, correcciones por destino, restaurar idioma anterior y texto coreano en SRT.
- En iPhone: guardadas primero, favoritas vacías, búsqueda sin resultados, borradores separados, papelera/restaurar. En iPad: categorías laterales y apertura de detalles.
- Conversación: elegir francés/coreano, hablar en cada sentido, detener/cancelar y corregir; color y voz deben corresponder al idioma elegido.
- Dispositivo real: comprobar idioma sin modelo, descarga aceptada/rechazada, modo avión, voces ausentes, interrupciones, VoiceOver, letras grandes y texto coreano largo. La fixture DEBUG no certifica reconocimiento/traducción reales.
- Evidencia y estado: [checkpoint](session-library-languages-checkpoint.md).
