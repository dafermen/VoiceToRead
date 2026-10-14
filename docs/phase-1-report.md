> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 1 implementation report
Status: implementation prepared; acceptance PENDING Apple build, automated tests and real-device validation.
The user authorized Phase 1 while Phase 0 Mac validation was pending. Neither phase is reported as build-verified.

## Implemented
Contextual AVAudioApplication microphone permission; Debug/Release usage description; AVAudioSession record/measurement; built-in mic AVAudioEngine capture; Start/Stop; explicit idle/requestingPermission/ready/starting/listening/stopping/error states; volume meter; errors and Settings recovery; background/interruption/input/configuration/media-service handling; bounded stream, stale-session protection and missing-buffer watchdog.
No speech recognition, captions, persistence, stored audio or network functionality.

## Files
Added Models/ListeningState.swift, Services/Audio/AudioCapturing.swift, Services/Audio/AudioCaptureService.swift, ViewModels/ListeningViewModel.swift, VoiceToReadUnitTests/ListeningViewModelTests.swift and ADR-003.
Updated HomeView, UI smoke test, project/scheme, README, CHANGELOG, architecture, roadmap, development, testing, privacy and App Store notes.
Original project brief and Phase 0 report retained.

## Decisions
Foreground only; built-in microphone preferred; no automatic resume. Apple permission has no separate restricted case. installTap is supported for the selected iOS 26 baseline; newer replacement requires iOS 27. See ADR-003.

## Build / tests
No Xcode or Swift toolchain is available on this Windows host. Build and XCTest NOT RUN.
Twelve mocked unit tests and one UI smoke test are provided for Mac execution.
Static validation results are recorded below after execution. They do not prove Swift compilation or audio functionality.

## Manual verification
Use docs/development.md to build/test and docs/testing.md for permission, meter, repeated start/stop, lifecycle, interruptions, accessories, Airplane Mode and accessibility checks on iPhone.

## Limitations / next phase
Requires Mac validation and physical device proof. Input level is not transcription and no offline speech readiness claim is made.
Phase 2 only after explicit approval: Apple SpeechAnalyzer/SpeechTranscriber, en-US model setup/readiness, microphone audio pipeline, partial/final assembly, responsiveness, duplicate prevention and physical Airplane Mode proof with latency observations.
STOP after Phase 1 implementation and validation handoff.

## Git
Review all untracked files; the Phase 0 repository has no baseline commit yet. Recommended logical commits: foundation first, then feat: add foreground microphone capture. No remote push or automatic commit performed.

## Executed static validation
2026-10-07:
- Parsed OpenStep project syntax successfully.
- Resolved all 37 project objects; checked three targets and source groups.
- Parsed shared scheme XML and verified both unit/UI test targets.
- Verified microphone purpose in Debug and Release app configurations.
- Counted 12 unit tests and one UI smoke test.
- Checked local Markdown links and authored-file whitespace.
- Confirmed xcodebuild is unavailable. No build/test pass is asserted.
Git status: all project files remain untracked; no commits exist.

## Next action on Mac
Open VoiceToRead.xcodeproj, select your team/unique identifier for device use, build Debug and Release, run Product > Test, and execute the iPhone checklist in docs/testing.md. Record results before calling Phase 1 complete.