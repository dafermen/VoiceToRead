# VoiceToRead

**Read what is being said.** Live captions, translation and language practice by InnovaLogic.

VoiceToRead is a native iPhone/iPad app for following English or Spanish conversations, reviewing recordings and practicing a language. It offers reading support for people with hearing loss or low vision and adult-guided language activities for children. Captions and translations may contain errors; it is not a certified interpretation or medical service.

## New independent project

- Open `VoiceToRead.xcodeproj`, scheme **VoiceToRead**.
- Bundle ID: `com.innovalogic.voicetoread`; initial version **0.1.0 (1)**.
- Local folder: `/Users/dariomeneses/Projects/VoiceToRead`.
- This app has its own storage and installation. It does not update or automatically import data from the previous application.
- Repository: [dafermen/VoiceToRead](https://github.com/dafermen/VoiceToRead), branch `main`. Apple registration, Xcode Cloud and TestFlight for this identity are pending.
- Current setup and validation: [project identity](docs/project-identity.md). Older build numbers in inherited reports describe the code base, not releases of this new app.

## Read, translate and review

- English capture by default, optional Spanish; English/Spanish interface selected independently.
- Live **Original / Translation / Both** modes. Both uses blue English cards and green Spanish cards with language labels, rounded borders and subtle shadows. Dark mode and high contrast are supported.
- Fullscreen, portrait/landscape, larger or bold text, line spacing, light paper colors and notebook guides.
- Pause/resume with a prominent interruption notice. Reread previous paragraphs without automatic scrolling until you choose to follow again.
- Optional saved microphone audio, noise reduction and background continuation. Recording always starts explicitly; background capture is opt-in.
- Save/discard sessions, recover drafts, correct text, search transcripts, bookmark phrases and protect favorites from accidental deletion.
- Replay continuously or one paragraph at a time with **At my pace**, correcting the selected phrase while paused.
- Export TXT/PDF, recorded audio and synchronized SRT/WebVTT subtitles. Timing after text edits is approximate.
- Translate saved sessions, review bilingual text, practice phrases and compare temporary pronunciation recordings. Local word recognition is not pronunciation scoring.

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

Responsible person: **Dario Fernando Meneses Ceron**. Support/privacy: **dariofernandomeneses@gmail.com**. Website destination: https://voicetoread.innovalogic.tech/ (Hostinger). The bilingual site and upload ZIP are prepared; hosting upload and SSL verification remain pending. No open-source license has been granted; see LICENSE.
