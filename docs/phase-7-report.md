> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 7 — Reliability implementation and profiling handoff
Implemented bounded audio/input/result queues with overflow failure, five-second missing-audio watchdog, ten-second finalization timeout, session-generation cancellation guards, provisional-result bound, lazy/windowed caption rows, common-case append optimization and periodic storage/duration monitoring.
Capture stops on background, calls/Siri/audio interruptions, route/configuration changes and media-service changes. Bluetooth capture is intentionally unsupported; accessories can trigger safe stop and phone-mic restart. Screen lock ends capture.
Four caption lifecycle tests and a synthetic long-transcript regression added.
30/60/120-minute CPU, memory, battery, thermal, latency and real-device stability tests NOT RUN. This phase is not certified complete; safeguards alone do not establish long-session reliability.
See reliability.md for measurements to collect. No fabricated performance numbers.
Next: privacy/security audit and manifest.
