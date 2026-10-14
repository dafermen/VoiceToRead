# ADR-003: Foreground microphone capture and lifecycle safety
Status: Accepted for Phase 1 implementation; Apple build/device verification pending.
Update 2026-10-09: the user explicitly authorized optional audio recording and background listening. See [media and subtitles](../media-and-subtitles.md); the original decision below is historical.
## Context
Phase 1 proves safe microphone monitoring without recognition or audio storage. The user explicitly authorized proceeding even though Phase 0 Mac validation is pending.
## Decision
Use AVAudioApplication permission APIs, AVAudioSession record/measurement and AVAudioEngine. Prefer built-in iPhone microphone. Request only on Start; add NSMicrophoneUsageDescription in both app configurations.
Capture only in foreground. Stop on interruption, relevant route changes, engine reconfiguration and media-service changes; require a new user Start. Do not add background entitlements or Bluetooth microphone options.
A testable MainActor service boundary and observable view model isolate platform capture. Bound the volume stream; reject stale sessions; display errors and offer Settings for denied permission.
Apple's permission enum exposes undetermined/granted/denied, not restricted. Explain denied or restricted access together without claiming we can distinguish them.
## API availability verification
Official Apple documentation metadata checked 2026-10-07:
- AVAudioApplication.requestRecordPermission async: iOS 17+.
- AVAudioSession setCategory(mode:options:): iOS 10+; setActive: iOS 6+; setPreferredInput: iOS 7+.
- AVAudioEngine.start and AVAudioNode.installTap: iOS 8+.
- installTap deprecation begins iOS 27; installAudioTap and AVReadOnlyAudioPCMBuffer require iOS 27.
Use installTap on the chosen iOS 26 SDK because the new API is unavailable for that baseline. This is an explicit compatibility decision, not a claim that installTap is the newest API on every OS. Reassess a guarded new API path with an iOS 27 SDK before upgrading tooling.
Sources:
https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)
https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory(_:mode:options:)
https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:)
https://developer.apple.com/documentation/avfaudio/avaudionode/installaudiotap(onbus:buffersize:format:tapprovider:)
https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange
## Alternatives considered
Legacy session permission request: rejected in favor of AVAudioApplication.
Background recording/automatic resume: deferred to avoid unintended capture.
Bluetooth capture: deferred; this phase verifies the phone microphone.
Remote recognition, Whisper and stored recordings: outside phase scope.
## Consequences
Locking or leaving the app stops listening. The user must restart after interruptions. No text transcription yet.
A Mac and physical iPhone remain mandatory acceptance gates; static inspection cannot certify runtime behavior.
