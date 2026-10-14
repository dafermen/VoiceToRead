# ADR-006: Xcode 15.2 and offline speech compatibility

Status: Accepted by the user on 2026-10-08; supersedes ADR-002's mandatory iOS/Xcode 26 baseline. Physical-device validation pending.

## Context
The available MacBookPro14,2 runs Ventura 13.7.8 and Xcode 15.2. The original iOS 26/Swift 6 target cannot compile there. The user authorized adapting the project to the older toolchain after reviewing the speech-engine tradeoffs. Offline-only recognition remains a requirement.

## Decision
- Target iOS 17.0, Swift 5 language mode with the Swift 5.9 compiler, and Xcode 15.2-compatible explicit project file references.
- Use LegacySpeechTranscriber behind the existing SpeechTranscribing protocol. LegacySpeechBackend isolates SFSpeechRecognizer from lifecycle/policy tests.
- Require explicit speech authorization, supported en-US locale, supportsOnDeviceRecognition and availability before capture. Recheck for every recognition request and set requiresOnDeviceRecognition=true. Unsupported states fail; there is no remote fallback.
- The compatibility API does not expose AssetInventory downloads. Readiness gives system English Dictation preparation guidance and requires an actual Airplane Mode test; a capability flag is not proof that models are usable offline.
- End a request after approximately 50 seconds of submitted audio, wait for its final result, then feed the queued audio into a new request with a new run UUID. This accommodates the older short-dictation API; it does not claim verified long-session reliability. The queue holds at most 128 captured frames, finalization times out at 10 seconds, and overflow/errors stop visibly. No provisional result is silently promoted to final.
- Treat each legacy result as a cumulative revision of the entire request range. Preserve previous requests' finalized text. Cancel/background stops audio immediately and invalidates callbacks; request rotation never restarts a canceled session.
- Keep AppleSpeechTranscriber and AudioConversion behind compiler(>=6.2), with iOS 26 availability. Newer builds choose that engine on iOS 26+; Xcode 15.2 builds always use the compatibility engine regardless of phone OS.
- Declare both microphone and speech purpose strings. Launch/readiness inspection must not trigger permission prompts; speech permission is a user action.

## Consequences and validation
The UI, SwiftData schema and transcript/export flows are retained. UI types explicitly use MainActor for compatibility with the older SwiftUI annotations. A newer phone OS can still be incompatible with Xcode 15.2 developer services, independently of app deployment target. The connected phone's developer image failed to mount before this migration.

Tests cover offline request policy, authorization refusal, request rotation, queued audio, final results, cancellation, timeout and overflow using injected system/audio boundaries. Actual 50-second boundary continuity, accuracy, permission recovery, model setup, offline behavior and 30/60/120-minute runs require a real supported device. Modern-engine validation still requires the newer SDK.

## References
- [Apple: SpeechAnalyzer and long-form speech](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Apple: requiresOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Apple: supportsOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [Apple: Xcode 15.2 SDK/platform requirements](https://developer.apple.com/documentation/xcode-release-notes/xcode-15_2-release-notes)
