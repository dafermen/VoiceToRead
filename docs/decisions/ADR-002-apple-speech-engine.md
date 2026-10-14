# ADR-002: Apple Speech engine and minimum platform
Current baseline updated by [ADR-006](ADR-006-xcode-15-compatibility.md). The original decision below describes the retained modern engine.
Status: Accepted for implementation in Phase 2; hardware validation pending.
## Context
Apple introduced SpeechAnalyzer and SpeechTranscriber with iOS 26 for on-device transcription. API availability does not guarantee model/device support.
Sources checked 2026-10-07:
https://developer.apple.com/videos/play/wwdc2025/277/
https://developer.apple.com/documentation/speech/speechtranscriber
https://developer.apple.com/documentation/speech/speechanalyzer
## Decision
Target iOS 26.0+ and Xcode 26+. Adopt Apple Speech in Phase 2 behind SpeechTranscribing. Verify exact signatures, isAvailable, supportedLocales and asset lifecycle at implementation time.
## Alternatives considered
Legacy SFSpeechRecognizer: not selected for this modern stack. Whisper: deferred, not implemented. Remote service: incompatible with offline core.
## Consequences
No specific model list is promised. Unsupported devices and missing assets must be handled. Initial model installation can require connectivity. A Mac and real compatible iPhone are required for validation.
