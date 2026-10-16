# Privacy and data flows
Source data-flow description updated for optional recording and subtitles; status reconciled 2026-10-10. An archive has been exported/uploaded, but a full binary privacy audit and physical protection/network checks remain pending.

| Data or action | Behavior | Location / recipient |
| --- | --- | --- |
| Microphone audio | User-started listening, optional background continuation, bounded queues; optional Save audio selected before a session | Memory plus local protected CAF when Save audio is enabled (initially on in new installations); M4A export |
| Speech analysis | SFSpeechRecognizer en-US or es-ES with on-device support checked and required; modern SpeechAnalyzer where available; no remote fallback | Device; installed Apple models |
| Model setup | System Dictation setup for the selected language for compatibility engine; explicit Install Selected Language Model only for modern engine | Apple's system asset service |
| Saved-session final captions | Incremental recovery draft always; explicit Save publishes to library, Discard deletes | Local SwiftData store |
| Transcript corrections and reading position | Original recognition is retained; corrections and last read paragraph are stored separately | Local SwiftData store |
| Partial captions | Provisional, displayed in memory; not saved | Device memory |
| Session metadata | UUID, title, dates, active-listening duration, language and ended status | Local SwiftData store |
| Preferences | Caption size, wake, appearance, paper/rules, selected capture language, remembered audio/background choices | App's UserDefaults domain |
| Disk capacity | Checked for storage readiness and low-storage safeguard | Local value, not transmitted |
| Export / Copy / Share | Only after user action | Destination chosen by user; may transmit or sync text, audio and subtitle files |
| Translation speech | Explicit playback of corrected saved destination text; in Speak and translate, automatic English speech after a user-started Spanish turn or Translate and speak action. Playback uses Apple AVSpeechSynthesizer; no recording/export of synthesized audio | Device voice; availability/download managed by Apple; no developer server |
| Temporary conversation | Spanish recognition, text editing, translation and English speech; no recorded file or saved session; cleared when the view is closed | Device memory and Apple language/voice resources |
| Diagnostics | Microphone check shows volume only | Device memory |

No account, analytics, advertising, tracking, OpenAI key, server endpoint or custom network client exists.
On-device support is checked before each compatibility request. Modern model reserve does not install assets at Start. Device support is rechecked before each run.
Microphone and Speech Recognition purpose strings are declared. The compatibility engine requests speech authorization through an explicit user action and sets requiresOnDeviceRecognition=true only after verifying supportsOnDeviceRecognition. The modern SpeechAnalyzer engine does not request legacy speech authorization.

Audio saving initially defaults on for a new installation; background stays off. Existing installations retain their audio choice, including the previous default-off behavior. Both choices persist. The microphone still starts only on explicit Start/Resume. Recording choice is fixed for the active session; background continuation can change while listening.

## Persistence and deletion
SwiftData uses an explicit application-support store with CloudKit disabled. The transcript and recording directory is excluded from backup and created with complete-until-first-user-authentication protection.
A finalized segment save commits incrementally; unfinished sessions can be reopened after interruption. Unsaved/partial text can be lost on cancellation or termination. Compatibility results remain provisional until request finalization (normally around 50 seconds); backgrounding can lose that current chunk.
Permanent session deletion removes its recording, synchronized timing, draft marker, related captions, bookmarks, saved translations and corrections/reading position, but this is logical deletion and not a forensic secure-erase guarantee. Exported copies and clipboard content are controlled separately by the destination/user.
Deleting the app removes its local data; backup exclusion means users should export transcripts they wish to retain.
Verify SQLite/WAL sidecar protection and backup exclusion on device before release.

## Manifest inventory
PrivacyInfo.xcprivacy declares:
- UserDefaults CA92.1: app-owned preferences only.
- DiskSpace E174.1: local storage readiness, write-failure prevention and user-visible capacity state.
- No tracking domains, no tracking, no collected-data declarations.

No explicit file timestamp or boot-time APIs are used by application source. Audit the built archive/privacy report and any future dependencies; this source-level manifest is not a guarantee that a final binary audit passes.

## Policy and production status
User-facing policy is accessible in Settings. Public draft: privacy-policy-draft.md.
Owner identity, contact and a public policy URL remain required for public release.
Re-review actual data flows, App Privacy answers and current requirements whenever SDKs or features change.

Sources:
https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition
https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
https://developer.apple.com/app-store/app-privacy-details/
https://developer.apple.com/app-store/review/guidelines/

The live level indicator reuses the microphone's local RMS-derived level; it is not a separate recording or a transcription-quality score. Suggested session titles use local date/time formatting. Phrase playback reads the existing local recording. These controls add no network service or new data destination.

## Optional saved-text translation

English source snapshots, machine Spanish and Spanish edits live in the local V6 store. Apple Translation prepares/downloads language models with system consent; downloaded models enable on-device translation. No third-party translation service or app HTTP client is added. Apple may collect API usage/performance metrics, including languages and bundle ID, but not the original or translated content according to [TranslationSession documentation](https://developer.apple.com/documentation/translation/translationsession). Text export obeys the selected language. Session deletion removes its translation; exported copies remain under the destination's control.


Build 17 adds temporary foreground live translation of confirmed captions. It is cleared when the reader closes and never alters saved English. The personal vocabulary lives in UserDefaults, separately from the backup-excluded session database; preferences can follow iOS backup settings. Clear and save the vocabulary to remove its entries. No vocabulary content is logged or sent to a new third-party service.


Build 18 stores study expressions and optional Spanish notes in the same local, backup-excluded session database (V7). Study copies keep their original context when transcripts are edited. Deleting a session also deletes its learning collection; removing a learning expression does not modify the transcript. Original phrase playback uses saved session audio. The separate pronunciation practice introduced in build 19 records temporary takes as described below.


## Práctica local de pronunciación — 2026-10-11

Build 19 permite grabaciones temporales explícitas de hasta 15 segundos. Se protegen, excluyen de backup y eliminan al repetir/cambiar/salir/background; tras cierre inesperado, al próximo inicio. Reconocimiento opcional exclusivamente local, sin Azure ni puntuaciones. Los controles globales de sesiones no afectan esta práctica. Véase [alcance y futura evaluación en línea](pronunciation.md).


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).

## Actualización 23 — 2026-10-12

Build 23 añade el marcador local SessionFavorite (V8) y la preferencia local playbackAtMyPace. No añade destinatarios ni servicios de red. Protección no significa backup: bloquea borrado desde la app hasta quitarla, sin impedir desinstalación/pérdida del dispositivo. La política consolidada EN/ES sustituye el borrador histórico: [política](privacy-policy-draft.md).


## Accessible recovery and written responses (2026-10-15)

V9 adds a separate SessionTrash marker. Moving a completed saved session to Recently deleted retains all its existing local files for 30 days. Restore removes only the marker. Explicit permanent deletion or expiry at launch/foreground deletes associated data through the existing repository deletion path. Draft discard and audio-only removal remain permanent. Written responses are view-memory text, spoken only by explicit action, never added to the session database or exported as audio. Leaving their screen clears the text; backgrounding interrupts speech.
