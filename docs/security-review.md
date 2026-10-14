# Phase 8 source security review
Historical review of application source/configuration through Phase 8. The bullets below describe that earlier scope; the later V4 recording/background extension changes the no-audio-storage assumption. Read [current privacy/data flows](privacy.md), [media design](media-and-subtitles.md) and [validation results](validation-report.md) for present behavior. No binary/dynamic security audit is claimed.
- Core uses only on-device Apple Speech, AVFoundation, SwiftData, SwiftUI and Foundation.
- No HTTP client, cloud speech fallback, embedded credentials, analytics/ad/tracking SDK or account flow.
- Only explicit model installation can initiate system-managed model download.
- Only explicit user export/share can send transcript text to a chosen destination.
- No audio storage or raw-audio export.
- Bounded copied audio queues; unchecked Sendable ownership contract documented. Concurrency/build validation pending.
- Local-only store with explicit errors; no automatic database wipe on failure.
- Session deletion confirmation and cascade; no forensic erasure promise.
- Preferences and disk-capacity reason declarations included.
- Permission text reflects captions and local processing.

Release gates: inspect archive/privacy report, SQLite sidecar protection/backup exclusion, network behavior in Airplane Mode and online after setup, logs for sensitive data, actual permission behavior, and failure recovery on device.
No security certification, legal compliance guarantee or App Store approval is asserted.
