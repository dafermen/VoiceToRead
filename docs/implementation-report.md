> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# VoiceToRead — delivery through Phase 9
This is the historical Phase 0–9 handoff. For the subsequent iOS 17/Xcode 15.2 migration and actual Mac test results, see [validation report](validation-report.md) and [ADR-006](decisions/ADR-006-xcode-15-compatibility.md).
Original Windows project location: C:\Projects\VoiceToRead. Current project: VoiceToRead; see development.md for the Mac location and commands.
Scope: continuous implementation from Phase 2 through Phase 9, expressly authorized by the user. Phase 10 remains unimplemented.
Historical status at the original handoff: source and release-preparation materials delivered; Apple acceptance gates were pending. Current status is in [the documentation index](README.md); later audio/subtitle implementation, TestFlight use and the 2026-10-10 upload supersede the limits below.

## Implementation by phase
2: on-device Apple speech engine, explicit en-US assets, audio conversion and partial/final transcript assembly.
3: readable/scaled captions, live-follow, lazy/history loading, appearance, wake, active duration and pause/resume.
4: local SwiftData sessions/segments, recovery/history/search/rename/delete and manual save.
5: UTF-8 .txt, clipboard and native text sharing with metadata.
6: persistent preferences, microphone/model/storage readiness and guided offline test.
7: bounded queues, overflow/stall/finalization protection, cancellation and storage/duration monitoring; profiling matrix.
8: actual data-flow/privacy source review, required-reason manifest, permission wording and policy draft.
9: icon/metadata/release notes, Mac validation/archive scripts, App Store considerations and release checklist.

## Evidence and limits
Windows static checks passed; 32 unit and 3 UI tests are written. No Xcode build, XCTest or physical iPhone test has run.
No measured accuracy, latency, battery, thermal, long-session reliability or App Store approval is claimed.
No cloud recognition, account, tracking, ads, stored audio or online AI.
API signatures/availability were checked against Apple documentation; iOS 26 baseline is retained. The iOS 27 successor to installTap is not used with the iOS 26 SDK.

## Git and transfer
Foundation and each implementation stage are saved as logical local commits. No remote/push or App Store upload was performed.
A source ZIP is supplied for transfer to a Mac; it contains the repository source/scripts/docs, not Git history or a compiled app.
Run scripts/validate-macos.sh; for signing/archive use development.md. Follow testing.md and reliability.md, then release-checklist.md.

## Remaining owner/release work
Real Apple compilation/test/device/offline/profiling and archive validation; final bundle ID/team, publisher/license decision, privacy/support URLs/contact, final questionnaires and genuine screenshots.
Phase 9 release preparation is delivered, but its validated release-candidate acceptance is still open.
