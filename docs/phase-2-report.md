> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 2 — Offline speech implementation
Implemented: SpeechTranscribing boundary, Apple SpeechAnalyzer/SpeechTranscriber en-US engine, explicit model installation, hardware/locale/asset checks, PCM conversion, bounded queues, volatile/final results, range-based transcript assembly and basic captions.
Apple API metadata verified for iOS 26. No cloud recognition, legacy SFSpeechRecognizer or speech authorization is used. Apple's permission article says the legacy speech authorization process does not apply to SpeechAnalyzer modules.
Four assembly tests added. Xcode build/test and real-device Airplane Mode proof NOT RUN on Windows. Latency unmeasured.
Manual: install model while online; launch in Airplane Mode with Wi-Fi also off; Start, allow microphone, speak English; verify partial/final captions and Stop. Repeat missing-model/unsupported-device/denied-permission cases. Record hardware, OS, SDK, latency and observations.
Continuous progression through Phase 9 was explicitly authorized; validation gates remain pending instead of being marked passed.
Next: caption readability and pause/resume experience.
