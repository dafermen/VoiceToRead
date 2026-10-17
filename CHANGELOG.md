## 2026-10-17 — Inicio coherente con accesibilidad y Ajustes

- Mostrar nombres añade etiquetas a todas las herramientas de Inicio y usa una cuadrícula adaptable, sin el espacio flexible que desajustaba la cabecera vertical.
- Modo sencillo unifica las seis acciones con icono, nombre, altura mínima y estilo comunes; siempre muestra nombres.
- Retira Conversación y Escribir una respuesta de Ajustes. Escribir y hablar sigue disponible desde Inicio sencillo y Acciones de sesión: voz para texto escrito, sin traducción ni guardado.
- Guías de usuario, soporte y desarrollo actualizadas. [Detalles](docs/home-controls.md).

## 2026-10-16 — colores de idioma consistentes y personalizables

- Español verde e inglés azul en botones y tarjetas, independientemente del sentido de traducción.
- Ajustes → Colores por idioma: paleta azul/verde/morado/naranja, vista previa, guardado local y restauración.
- Reproducir usa el idioma de destino; las tarjetas en vivo y de sesiones comparten preferencias.
- Fondos claros/oscuros, etiquetas explícitas y prioridad de alto contraste. El papel se conserva como fondo exterior.
- Documentación de usuario, desarrollo y soporte actualizada. [Guía](docs/language-colors.md).

## 2026-10-16 — controles de conversación más compactos

- Español a la izquierda e inglés a la derecha en una fila, también en iPhone.
- Reproducir y Corregir mensaje en una misma fila, con etiquetas que se ajustan al espacio.
- Retira Escribir en su lugar; conserva la corrección del texto reconocido.
- Icono de Conversación sin relleno, uniforme con las herramientas del lector.

## 2026-10-16 — conversación bilingüe en dos toques

- Español → inglés e inglés → español con dos botones visibles: tocar para hablar y volver a tocar para terminar, traducir y reproducir.
- Por botón como modo inicial; detección automática de pausa dentro de Opciones. Dirección independiente del idioma global.
- Tarjetas original/traducción con igual tamaño, estado con idioma, detener/repetir voz y último intercambio visible.
- Escritura y corrección en editor secundario; Cancelar conserva el mensaje y los fallos permiten reintentar sin hablar otra vez.
- Impide activar otra captura durante reproducción; mantiene privacidad temporal, límites e interrupciones seguras.
- Documentación de usuario, estudiantes, soporte y App Review actualizada. [Guía](docs/speak-and-translate.md) · [Verificación](docs/speak-and-translate-checkpoint.md).

## 2026-10-16 — menos redundancias y más espacio de lectura

- Texto y traducción sustituye Traducir a Español/English y concentra revisión, corrección y exportación; Audio y subtítulos concentra reproducción.
- Retira controles, listas y exportación de marcadores de frases; conserva datos heredados y Favoritos de sesiones completas.
- Listo/Done usa ✓ con nombre VoiceOver y área de toque de 44 puntos; Guardar/Descartar mantienen texto explícito.
- Hablar y traducir usa icono junto al selector en vivo; preparación pasa a Ajustes, conservando avisos necesarios de permisos/modelos.
- Documentación de usuario, GitHub, desarrollo junior y notas de revisión actualizadas. [Guía](docs/simplified-navigation.md) · [verificación](docs/simplified-navigation-checkpoint.md).

## 2026-10-16 — controles claros y conversación por botón

- Sustituye Following/Follow latest y Volver al vivo por una flecha circular accesible compartida entre lector original y bilingüe.
- Identifica Guardar audio, Reducir ruido y Segundo plano con nombre y estado visible; disposición adaptable al espacio.
- Elimina el acceso pequeño duplicado a Preferencias de captura en pantalla normal, conservándolo en pantalla completa.
- Hablar y traducir distingue Automático de Por botón. El segundo espera Reproducir en inglés tras traducir y no exige mantener pulsado el micrófono. Recuerda el modo, sin conservar la conversación.
- Actualiza documentación de usuario, desarrollo junior y notas de App Review. [Uso](docs/speak-and-translate.md) · [evidencia](docs/speak-and-translate-checkpoint.md).

## 2026-10-16 — hablar en español y reproducir en inglés

- Modo temporal Hablar y traducir, con acceso desde Captions y el inicio sencillo.
- Finalización automática tras pausa estimada de 3/5 segundos, alternativa manual y límite de un minuto.
- Texto original editable, traducción visible, voz inglesa automática tras finalizar, repetir y cancelar.
- Captura y voz excluyentes; cancelación de trabajos tardíos y sin reinicio automático tras interrupciones.
- No guarda audio ni sesiones ni modifica preferencias globales de captura. [Guía y arquitectura](docs/speak-and-translate.md).

## 2026-10-16 — tamaños de letra para pantallas pequeñas

- Amplía el rango base de subtítulos de 20–44 a 14–60 puntos, conservando el tamaño guardado y el valor inicial de 28.
- Unifica ajustes, lectura en vivo, reproductor, gesto de pellizco y acciones de VoiceOver; muestra el tamaño elegido.
- Añade una indicación en el reproductor para usar A mi ritmo y desplazar los párrafos largos. No cambia automáticamente la preferencia de reproducción.
- Mantiene Dynamic Type y el mismo tamaño relativo para original y traducción.

## 2026-10-16 — comodidad de escucha y notas

- Tarjeta activa con borde y “Escuchando ahora”, seguimiento opcional al desplazar manualmente.
- Pausa de 0/1/2 segundos entre idiomas, velocidades independientes y preferencias de idioma/modo recordadas.
- Búsqueda de párrafos en ambos idiomas con reproducción directa.
- Notas opcionales de marcadores y escucha local sin abrir otro reproductor; migración aditiva V9→V10.
- Preparación antes de reunión/clase con micrófono, idiomas y voces; documentación de usuario, desarrollo junior y GitHub actualizada.
- [Uso y arquitectura](docs/listening-comfort.md) · [verificación](docs/listening-comfort-checkpoint.md).

## VoiceToRead 1.0 — corrección de marcadores y escucha bilingüe

- Hace visible Guardar/Quitar marcador en original, tarjetas bilingües, sesiones, traducción y reproductor; comparte identidad y persistencia.
- Both/Ambos controla texto y audio: original seguido de traducción por párrafo; A mi ritmo espera tras ambos.
- Escucha directa en párrafos de Traducción, con pausa/reanudar/detener y estado del idioma, sin abrir otra ventana.
- Original sin grabación usa voz generada en la cola por párrafo. Cambiar selección o salir detiene la reproducción.
- Guías de usuario, GitHub, arquitectura y estudiantes actualizadas: [detalle](docs/bookmarks-and-bilingual-playback.md), [verificación y entrega](docs/bookmarks-and-bilingual-playback-checkpoint.md).

## VoiceToRead 1.0 — reproducción unificada y traducción automática (2026-10-15)

## 2026-10-15 — opciones de accesibilidad y recuperación

- Modo sencillo, nombres opcionales de controles, aviso de pausa con vibración configurable y lectura enfocada.
- Preparación guiada, demostración sin grabación y respuestas escritas reproducidas con voz local.
- Papelera recuperable por 30 días, Deshacer y borrado permanente explícito; migración V9 conserva datos previos.
- Preferencias EN/ES, teclado y letra de reproducción adaptable al sistema; guía de aceptación con tecnologías de apoyo.
- Documentación de usuario, desarrollo junior, privacidad y paquete web actualizados. Ver checkpoint para validación y distribución reales.

- Unifica tamaño, lector y controles del audio original y la voz traducida. Separa Escuchar de Leer.
- Elimina repetición duplicada, conserva último párrafo, añade progreso por párrafo y navegación silenciosa.
- Usa tarjetas bilingües, opciones en hoja y lectura larga desplazable; práctica comparte controles, pausa real y bucle explícito.
- Inicia traducción al detener, conserva Guardar/Descartar y rechaza callbacks tardíos o textos obsoletos.
- Guías inclusivas y técnicas: [documentación](docs/playback-unification.md); [evidencia y entrega](docs/playback-unification-checkpoint.md).

## VoiceToRead 1.0 — lectura accesible y voz traducida (2026-10-15)

- Lee traducciones corregidas EN↔ES por párrafo o completas, incluso sin grabación original; voz Apple, velocidad, pausa/continuar/detener y resaltado del párrafo activo.
- Evita reproducción automática: detiene la voz al editar, abrir otro audio, salir o recibir interrupciones. No agrega doblaje ni exportación de voz sintética.
- Amplía el visor desplazable de subtítulos y pliega opciones secundarias; añade frase anterior a A mi ritmo.
- Reúne protección y borrado en dos círculos al deslizar a la izquierda, con alternativa por botón/VoiceOver; mantiene confirmaciones y la protección del repositorio.
- Actualiza guías de proyecto, GitHub y estudiantes con apoyo a discapacidad auditiva/baja visión, comprensión de nuevos idiomas y práctica infantil acompañada.
- Resultados y limitaciones: [checkpoint](docs/translated-speech-checkpoint.md). Disponibilidad en TestFlight/App Store pendiente de distribución.

## VoiceToRead 1.0 — preparación de publicación (2026-10-14)

- Alinea la versión fuente con la ficha pública 1.0; conserva bundle ID, firma configurada y datos existentes.
- Añade responsable, soporte, enlaces públicos EN/ES y conservación de correos a la privacidad local.
- Prepara 12 capturas reales de simulador, textos bilingües, guía de envío y ZIP regenerable.
- Documenta TestFlight interno confirmado por el titular, web HTTPS verificada y decisión de gratuidad en Estados Unidos/Colombia.
- Debug/UI en iPhone e iPad y Release sin firma validados; SDK moderno, aceptación física final y envío a revisión continúan pendientes. No publicado en App Store.

## VoiceToRead 0.1.0 (1) — proyecto independiente

- Nueva identidad: com.innovalogic.voicetoread, con proyecto, esquema, módulos, tests, almacenamiento, exportaciones y textos renombrados.
- Conserva las funciones del código base, incluidas tarjetas bilingües, traducción local, grabación, práctica de idiomas y soporte iPhone/iPad.
- Estado inicial: registro de Apple, firma de distribución, Xcode Cloud y TestFlight estaban pendientes. Ver preparación 1.0 para el estado actualizado.

Los apartados siguientes son historial heredado con nombres adaptados; los builds 2–27 no son entregas de esta nueva aplicación.

## Source build 27 — 2026-10-13

- Present live Both mode as compact rounded cards: blue for English, green for Spanish, with a subtle border and shadow.
- Retain explicit original/translation language labels, selectable text and reading styles. Dark appearance adapts the fills; increased/high contrast uses a strong monochrome outline.
- Include provisional original text and waiting translations in matching language cards.

## Source build 26 — 2026-10-13

- Fix the modern-SDK translation runner compilation by explicitly applying ViewBuilder to the extracted helper view. Restores Cloud compilation eligibility for the live bilingual update; distribution is verified separately.

## Source build 25 — 2026-10-13

- Add a subtle separator between original and translated live captions in Both mode, retaining language labels and reading space. The decorative line is hidden from VoiceOver and follows light/dark appearance.

## Source build 24 — 2026-10-13

- Live captions offer Original, Translation and Both in one compact menu, independent of interface/capture language.
- Pair original and translated paragraphs with language labels; show translation waiting state and provisional original text in Both.
- Remember presentation preference; preserve microphone state when switching, plus fullscreen and reading styles.
- Translate only confirmed text using the existing local engine. No new storage schema or translation service.

## 2026-10-11 — Local pronunciation practice (source build 19)

## Source build 22 — 2026-10-12

- Optional on-device noise reduction for new microphone capture, shared by recording and recognition.
- Remembered global preference and compact filter shortcut before listening; session choice retained across pause/resume.
- English/Spanish labels, current-session status and explicit next-session messaging. Unsupported processing fails visibly instead of silently recording unfiltered audio.
- Original recordings, subtitle sample clock, app identity and persistence schema remain unchanged.

## 0.1.0 — source build 21 (2026-10-11)

- Menús, instrucciones y avisos en inglés/español, separados del idioma de captura.
- Preparación inicial destacada con acciones de permiso/modelo y avisos de voces de práctica más visibles.
- Audio guardado inicialmente en nuevas instalaciones, respetando preferencias de actualizaciones.
- Guías dibujadas por el layout real de cada párrafo para mantener alineación al reanudar y girar.
- Documentación de uso y explicación para estudiantes: docs/interface-and-onboarding.md.


## 0.1.0 — source build 20 (2026-10-11)

- English (default) or Spanish capture, with language preserved per session, bidirectional translation and language-aware practice.
- Rename learning entry to “Practicar idioma”; existing sessions, expressions and translation payloads remain compatible (schema V7 unchanged).
- Native iPhone/iPad target, iPad orientations, optional light reading colors and notebook guides; high contrast takes precedence.
- Persistent paused/microphone-off banner with prominent Resume, accessibility announcement and supported-device haptic feedback.
- Inclusive-use guidance for hearing/low-vision support and adult-guided child language practice; updated student guides and release checks.
- Local verification and delivery status: [build 20 checkpoint](docs/accessibility-checkpoint.md). A source build is not proof of TestFlight availability.

- Add an explicit listen/record/compare flow with synthetic English examples, slow speech and selectable words/short phrases.
- Record protected temporary takes for up to 15 seconds, replay and delete on retry/exit/background; clean abandoned files on launch.
- Offer optional offline-only word recognition, without scores, phoneme claims or expected-answer hints.
- Document future hosted assessment; no Azure account, keys, cloud upload or service costs added. Schema V7 and app identity unchanged.

## 2026-10-10 — English learning (source build 18)
- Replace the two-symbol Capture Preferences button with one sliders icon.
- Add session-based English practice: phrase playback, slow speed, repeat, hidden Spanish and saved expressions with context/audio.
- Add V6→V7 migration for independent local study records. Preserve existing text, translations, bookmarks and audio.
- Stop practice playback on exit, background or interruption; no microphone capture or pronunciation scoring.

## 2026-10-10 — Translation review and live preview (source build 17)
- Listen to English audio from a translated paragraph; keep approximate existing subtitle timing.
- Add a local personal dictionary with recognition hints and preferred Spanish terms.
- Update only changed English paragraphs; preserve Spanish edits for unchanged paragraphs, including reordering/deletion.
- Search current English and Spanish across sessions and open the matching language/paragraph.
- Preview language, freshness, format and content before translated exports.
- Add opt-in live Spanish preview of confirmed captions; bounded queue, cancellation and foreground-only translation. No change to saved English or microphone lifecycle. Live preview is temporary, not an automatically saved translation.
- Keep schema V6, bundle identity, audio clock and user-controlled sharing unchanged. Physical-device language downloads, latency, battery and grammar validation remain required.

# Changelog

## 2026-10-10 — Saved-session Spanish translation (source build 16)
- Add explicit English→Spanish translation using Apple's Translation framework on iOS 18+, with progress, cancellation and language download preparation.
- Preserve English, machine Spanish and Spanish edits independently with additive V5→V6 migration; detect English changes before saving or sharing translated content.
- Add English/Spanish/bilingual reading, Spanish editing and TXT/PDF/SRT/WebVTT exports; replay English audio with translated captions using existing time windows.
- Retain iOS 17 compatibility for reading existing translations; actual Translation framework execution requires a modern SDK/device. See the validation report for executed checks.


## Unreleased — 0.1.0 development, through Phase 9
iOS 17 compatibility builds with Xcode 15.2; the user confirmed basic operation of TestFlight builds 5 and 6 on their iPhone; detailed offline and release verification remain pending. This is not a release-certified binary.

### Capture and audio review — 2026-10-10, source build 15
- Tap a saved timed paragraph or playback phrase to seek and listen; keep Play/Pause directly accessible.
- Show live microphone level and distinguish transcribing from recording, paused and interrupted states.
- Offer explicit Resume after interruption; keep the same recovery draft and finalized text.
- Suggest a local date/time title with an optional inline name field at Save.
- Pinch live captions to resize; preserve Aa and accessibility adjustment actions.
- Keep schema V5, existing identity, sample clock and recording opt-in unchanged.

### Session workflow — 2026-10-10, source build 14
- Persist Audio/Background preferences and expose quick controls before Start.
- Circular microphone/pause/resume and square Stop controls with accessibility labels.
- One-tap new session after Save; decision dialog only for a pending recovery draft.
- Explicit Save/Discard, separate recovery drafts in Sessions, additive V5 migration preserving existing library sessions.
- Background preference can change during capture; audio changes apply to the next session. Mid-session recording remains deferred.
- Replace the old auto-save switch with always-on local draft recovery; update privacy/help and validation background-mode checks.

### Documentation — 2026-10-10
- Added Spanish student/junior guide, code walkthrough, documentation index, distribution runbook and incident history.
- Documented Cloud export failures on Xcode 27 and 26.6, and successful local export/upload of the Cloud 11 archive with Xcode 15.2. Apple processing/TestFlight availability of that package still needs confirmation.
- Added educational source comments on state, buffer ownership, timing, persistence and exports; no runtime behavior changed.
- Reconciled current status and validation counts while keeping earlier phase reports historical.

### Changed
- New Session is a 44-point blue circular +. Completed portrait sessions omit the old footer to expand the reader; fullscreen and landscape retain accessible controls.
- Expanded the caption reader with a compact status strip and an adaptive landscape control bar. Reading options now open from Aa; save/new-session actions and full status information live in the session menu.
- A single primary action changes between Start Listening, Pause, Resume and New Session. Stop remains directly accessible.
- Renamed the app, Xcode project and scheme, source/test targets, exported filename fallback, permission text, documentation and repository to VoiceToRead.
- Adopted the subtitle "Live English Captions" and tagline "See what's being said."
- Kept `com.innovalogic.voicetoread` and the original internal session-storage directory for continuity. Validation/archive scripts also accept their previous environment-variable names.

### Added
- Optional per-session microphone recording, protected local audio, M4A export and independent audio deletion.
- Audio playback with seeking, synchronized captions and fullscreen rotation; transcript editing from the player.
- SRT/WebVTT and combined audio + corrected text + subtitle sharing, using sample-based timing across pauses and speech request rotations.
- Explicit per-session background listening and mixing with other apps' speaker audio; no internal other-app audio capture.
- Additive V4 media metadata that preserves existing sessions and corrections.
- Transcript editing with paragraph drafts, undo/redo, save/discard and restoration of the original recognition.
- Literal find/replace with whole-word/case options, previews and one/all replacement.
- Shared review preview for corrected text and bookmarks, optional metadata, TXT/PDF export, Copy and native sharing.
- Reading-position restoration and jumps from saved bookmarks.
- Additive V3 storage for corrections and reading positions, preserving old sessions, captions and bookmark snapshots.
- Fullscreen reader with visible listening status and accessible pause, stop and exit controls in portrait and landscape.
- Automatic pause of live following when scrolling back, a Back to live control and a pinned transcript window while rereading.
- Persistent line spacing, bold text and high-contrast reading options.
- Phrase bookmarks stored as snapshots, with an additive V1-to-V2 migration that preserves existing sessions.
- iOS 17/Xcode 15.2 compatibility engine with required on-device recognition, explicit speech authorization, bounded buffering and 50-second request rotation. Modern iOS 26 engine retained for newer toolchains.
- Native simulator coverage for compatibility recognition lifecycle and offline policy.
- Native on-device English SpeechAnalyzer/SpeechTranscriber pipeline and explicit model installation.
- Partial/final captions, pause/resume, lazy/windowed rendering, text size, appearance, live following and active-time display.
- Local versioned SwiftData conference sessions, incremental final saves, history, rename/search/delete and recovery display.
- Text export, Copy and native sharing.
- Persisted preferences, microphone diagnostics and Offline Readiness/Test Offline Mode.
- Bounded queues, stale-session/cancellation guards, missing-audio/finalization timeouts and storage monitoring.
- Privacy manifest, policy/source audit, App Store drafts, icon and release checklist.
- Windows static validation and Mac Debug/test/Release/archive scripts.
- 56 compatibility unit tests and 12 UI scenarios passed across full and focused runs on iOS 17.2; one additional modern conversion test requires Xcode 26/iOS 26. Independent macOS assembler validation is also available.

### Fixed
- Provisional caption revisions retain their identity; the live text container stays stable and no longer animates every word update.
- Explicitly delete a session’s captions before saving its deletion, covering the orphan observed with iOS 17 SwiftData.
- A late final revision replacing all captions from an earlier analyzer run now preserves that run's position instead of moving it after newer speech. Added an XCTest regression that reproduces the original failure.

### Limitations
- Actual Airplane Mode captions, device compatibility, accessibility and 30/60/120-minute performance unverified.
- Built-in microphone only; background listening and local recording are per-session opt-ins. No internal other-app audio capture, accounts, cloud AI, analytics, ads or tracking.
- Publisher/license/public URLs, final privacy review and genuine public-release screenshots remain pending. App identity/signing and the local upload path have been exercised; this is not App Store release approval.

## Earlier foundation
Phases 0–1 added SwiftUI/Xcode structure, microphone capture, permissions, states, initial tests and documentation.

## 0.1.0 — source build 23 (2026-10-12)

- At my pace: bounded whole-paragraph playback, repeat/manual next and persistent selected text.
- Direct paragraph correction from original/translated playback, preserving recorded audio.
- Protected favorites, library filter and additive V8 migration; protection checked before session/audio deletion.
- Explicit interface-language refresh for tab labels and Settings title, retaining session state.
- Student/developer guides and bilingual App Store preparation materials. Delivery evidence: docs/pace-checkpoint.md.
