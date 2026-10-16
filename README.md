# VoiceToRead

Actualización de experiencia accesible: [guía de los ocho cambios](docs/accessible-experience.md) y [evidencia/pendientes](docs/accessible-experience-checkpoint.md).

**Read what is being said.** Live captions, translation and language practice by InnovaLogic.

VoiceToRead is a native iPhone/iPad app for following English or Spanish conversations, reviewing recordings and practicing a language. It offers reading support for people with hearing loss or low vision and adult-guided language activities for children. Captions and translations may contain errors; it is not a certified interpretation or medical service.

## New independent project

- Open `VoiceToRead.xcodeproj`, scheme **VoiceToRead**.
- Bundle ID: `com.innovalogic.voicetoread`; public-release source version **1.0 (1)**.
- Local folder: `/Users/dariomeneses/Projects/VoiceToRead`.
- This app has its own storage and installation. It does not update or automatically import data from the previous application.
- Repository: [dafermen/VoiceToRead](https://github.com/dafermen/VoiceToRead), branch `main`. App Store Connect record **6822564230** is confirmed by the owner’s screenshot (1.0, Prepare for Submission). The owner confirmed VoiceToRead runs on iPhone through internal TestFlight. Source version is now 1.0; an App Store-eligible archive and final device acceptance remain pending.
- Current setup and validation: [project identity](docs/project-identity.md). Older build numbers in inherited reports describe the code base, not releases of this new app.

## Read, translate and review

- English capture by default, optional Spanish; English/Spanish interface selected independently.
- Live **Original / Translation / Both** modes. Both uses blue English cards and green Spanish cards with language labels, rounded borders and subtle shadows. Dark mode and high contrast are supported.
- Fullscreen, portrait/landscape, larger or bold text, line spacing, light paper colors and notebook guides.
- Pause/resume with a prominent interruption notice. Reread previous paragraphs without automatic scrolling; the circular down arrow returns to live text and resumes following.
- Clearly labelled Save audio, Reduce noise and Background controls show On/Off before starting. Optional saved microphone audio, noise reduction and background continuation. Recording always starts explicitly; background capture is opt-in.
- Save/discard sessions, recover drafts, correct text, search transcripts, bookmark phrases and protect favorites from accidental deletion.
- Replay continuously or one paragraph at a time with **At my pace**: previous and next, with replay from the main button; correct the selected phrase while paused. The caption reader fills the available height; secondary playback options collapse.
- Export TXT/PDF, recorded audio and synchronized SRT/WebVTT subtitles. Timing after text edits is approximate.
- Automatically translate finalized text after Stop on compatible devices, with progress and retry; Save/Discard remains your choice. **Listen to the corrected translation or original audio in one reader**, with matching controls, pause/resume and reading speed. Previous/Next select silently. One language choice controls text and sound: Both plays original then translation for each paragraph; At my pace stops after both. Translation paragraphs play inline, without opening another player. Generated speech needs an available device voice.
- [Unified playback and automatic translation](docs/playback-unification.md): usage, student-oriented architecture and limitations; [validation checkpoint](docs/playback-unification-checkpoint.md).
- Swipe left on a saved session (or use its actions button) for circular favorite/protect and delete controls. Protected sessions cannot be deleted; removing protection and deleting require separate confirmations.
- Review bilingual text, practice phrases and compare temporary pronunciation recordings. Local word recognition is not pronunciation scoring.

See [accessible listening and reading](docs/translated-speech.md) for user steps, junior developer explanations, limits and acceptance checks.

## Speak and translate

Speak Spanish, pause and hear the English translation for everyday conversations. Choose **Automatic** (3/5-second pause, translation and speech) or **By button** (tap to start, tap Finished speaking, then explicitly Play English). The mode is remembered. Type/correct a message, play English again, or cancel. The microphone is off during playback, and each new turn starts explicitly. Temporary text only: no recording or session is saved. Requires a compatible iOS/iPadOS 18+ build and prepared Apple models/voices. [User and student guide](docs/speak-and-translate.md).

## Listening comfort

- Adjust caption text from **14–60 base points** in Settings, live Reading options or playback Reading preferences. Your saved size is preserved; Dynamic Type still applies. Use **At my pace** for time to finish long paragraphs and scroll any text that exceeds the reader.

- The speaking card has a border and “Listening now”; manual scrolling pauses automatic following.
- Remember language/mode preferences, set independent original/translation speeds and choose a 0/1/2-second gap between languages.
- Search original or translated paragraphs and play a result directly; add private notes to bookmarks and preview their corrected text with local speech.
- Check microphone, languages, voices and preparation before a meeting or class.
- [User/student guide](docs/listening-comfort.md) · [validation and delivery](docs/listening-comfort-checkpoint.md).

## Requirements and limits

Minimum iOS/iPadOS 17. Local development supports Xcode 15.2 on macOS Ventura. Newer toolchains enable the modern speech implementation behind compiler/OS availability checks. Translation requires a Translation-capable SDK, iOS/iPadOS 18+ and prepared Apple language models; it is unavailable in builds made with Xcode 15.2.

Recognition requires compatible on-device support and permissions. Model setup may need Internet. Test readiness before an event. Audio comes from the microphone, not other apps' internal audio. Saved content stays local and is excluded from device backup; export important recordings and transcripts. The app has no developer account requirement, ads or analytics.

Simulator tests use controlled fixtures for microphone/translation UI. Real-device accuracy, language models, long recordings and accessibility need their own acceptance checks. A local build does not imply App Store/TestFlight availability.

## Build and tests

```sh
open VoiceToRead.xcodeproj
bash scripts/validate-macos.sh
python3 scripts/validate-localization.py
python3 scripts/validate-store-metadata.py
```

The Mac script selects an available simulator, runs tests, builds Debug/Release and inspects the bundle. Set `VOICETOREAD_SIMULATOR_ID` to choose a simulator. See [development](docs/development.md) for targeted commands and toolchain selection.

## Project and documentation

`VoiceToRead/App` starts the app; `UI` draws screens; `ViewModels` coordinates sessions; `Services` captures and recognizes audio; `Models` and `Persistence` store local data; `Utilities` prepares exports. `VoiceToReadUnitTests` and `VoiceToReadTests` cover logic and UI.

- [Documentation index](docs/README.md)
- [Student/junior developer guide](docs/junior-guide.md) and [code walkthrough](docs/code-walkthrough.md)
- [Architecture](docs/architecture.md), [testing](docs/testing.md) and [known incidents](docs/build-incidents.md)
- [Distribution setup](docs/distribution-runbook.md) and [App Store preparation](docs/app-store.md)
- [Privacy policy](docs/privacy-policy-draft.md) and [support pages](docs/store/support.md)
- [Bilingual public website](website/README.md) and [Hostinger deployment guide](docs/website-publication.md)

Responsible person: **Dario Fernando Meneses Ceron**. Support/privacy: **dariofernandomeneses@gmail.com**. Website: https://voicetoread.innovalogic.tech/ (Hostinger). Public privacy/support pages in both languages were verified over HTTPS on 2026-10-14. No open-source license has been granted; see LICENSE.

Public release preparation: [submission kit](docs/store/submission-kit.md). Owner selected **free, no in-app purchases**, initially **United States and Colombia**. Nothing has been submitted to App Review.

- [Visible bookmarks and bilingual paragraph playback: usage and developer guide](docs/bookmarks-and-bilingual-playback.md).
