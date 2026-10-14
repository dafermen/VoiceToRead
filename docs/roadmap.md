# Roadmap and acceptance status
The user authorized continuous implementation through Phase 9. Each stage has a local commit/report, with validation evidence tracked in validation-report.md. The iOS 17 compatibility migration now permits native Xcode 15.2 simulator builds; real-device speech/release gates remain open.

| Phase | Source / preparation | Required external validation |
| --- | --- | --- |
| 0 Foundation | Prepared | Xcode shell build/launch |
| 1 Microphone | Implemented | Physical start/stop, permission and audio capture |
| 2 Offline speech | Implemented | Real English captions in Airplane Mode and latency |
| 3 Caption experience | Implemented | Dynamic Type/VoiceOver/rotation and 30-minute comfort |
| 4 Sessions | Implemented | Store reopen/recovery/deletion and failure handling |
| 5 Export | Implemented | Native .txt/Copy/Share on iPhone |
| 6 Readiness/settings | Implemented | Actual asset/permission/capacity and offline checks |
| 7 Reliability | Safeguards prepared | 30/60/120-minute profiling and interruption matrix |
| 8 Privacy/security | Source review/materials prepared | Archive/network/protection/privacy-report audit |
| 9 App Store | Release materials prepared | Signed Release archive, all gates and owner inputs |
| 10 Optional online AI | Not started | Requires a separate explicit request |

## Subsequent delivery status — 2026-10-10

Reader/fullscreen, corrections, bookmarks, optional audio, playback, background opt-in and SRT/WebVTT are implemented. Local validation passed 56 compatible unit tests and 12 UI scenarios across full/focused runs. Basic earlier TestFlight operation was user-confirmed. The Cloud 11 archive was exported and uploaded from the Mac. The user subsequently confirmed the iPhone update and working audio/background switches; detailed media/offline acceptance remains pending.

Next work: confirm the latest TestFlight build, perform the device/media/offline/reliability scenarios, address modern concurrency warnings with appropriate testing, and complete public-release inputs. Use [distribution runbook](distribution-runbook.md) for the Cloud export workaround and [incident history](build-incidents.md) before retrying.
Do not describe this state as App Store ready or offline proven.

## Session workflow — build 14 source

Implemented remembered capture preferences, nearby controls, circular microphone/pause/stop, one-tap new session after saving, explicit Save/Discard and V5 recovery drafts. See [session workflow](session-workflow.md). The current changes passed 59 compatible unit tests and two targeted UI scenarios across final runs; this does not mean the entire older UI suite was rerun. A new modern archive, TestFlight delivery and physical acceptance are still required.

## Audio review and capture feedback — build 15 source
Timed paragraph/phrase playback, explicit capture and playback pause/resume, level feedback, contextual interruption recovery, local suggested names and pinch resizing are implemented. The schema remains V5 and modern-engine/device verification is a separate gate. See the current validation report before claiming TestFlight availability.

## Source build 16

Saved-session Spanish translation, bilingual review and translated subtitle sharing are implemented. Build 17 adds optional experimental foreground live Spanish preview; synthesized Spanish audio remains outside this delivery. See [translation limits](translation.md) and [the implementation checkpoint](implementation-checkpoint.md). Real translation quality, on-device downloads/offline behavior and TestFlight delivery are separate acceptance steps.

## Actualización 23 — 2026-10-12

Build 23 incorpora lectura A mi ritmo, corrección desde reproducción, favoritas protegidas y actualización de etiquetas de idioma. Preparación App Store en curso; publicación pública, URLs/contactos y aceptación física siguen pendientes hasta verificarse.
