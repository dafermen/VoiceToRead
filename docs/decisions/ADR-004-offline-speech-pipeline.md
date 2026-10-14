# ADR-004: Offline speech pipeline
Current baseline updated by [ADR-006](ADR-006-xcode-15-compatibility.md). The original decision below describes the retained modern engine.
Status: Implemented; Apple build/device validation pending.
## Context
SpeechAnalyzer/SpeechTranscriber require iOS 26 and installed compatible assets. Some current helper APIs in Apple's docs require iOS 27.
## Decision
Use verified iOS 26 buffer APIs, AVAudioConverter and AnalyzerInput(AVAudioPCMBuffer). Model installation is explicit; Start only accepts installed assets. Reserve en-US assets to keep them available for this app. No implicit download/fallback.
Raw tap buffers are copied before leaving the callback. CapturedAudio's unchecked Sendable contract permits only immutable reading of the owned copy. Conversion is isolated to an actor.
Bound raw/input/result queues; detect overflow and stop rather than silently discarding conference speech.
Assemble by run identifier and audio time range; retain legitimate repeated words. Partial text is provisional.
## Alternatives considered
iOS 27-only capture/conversion helpers: unavailable at the baseline. Legacy server-capable recognizer and cloud fallback: rejected. Whisper: deferred.
## Consequences
Initial asset setup can require Internet and disk space. Real iPhone Airplane Mode tests are mandatory. Analyzer restarts create new run identities, so timestamp resets do not erase prior captions.
API references checked 2026-10-07: developer.apple.com/documentation/speech/speechanalyzer; speechtranscriber; assetinventory; analyzerinput; asking-permission-to-use-speech-recognition.
