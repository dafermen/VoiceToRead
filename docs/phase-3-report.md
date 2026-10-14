> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 3 — Caption experience
Implemented lazy segment rendering, partial sentence marking, live-follow toggle and automatic scrolling, scaled/adjustable text, system light/dark appearance, reduced-motion scrolling, VoiceOver labels, elapsed active-listening time and optional screen wake only while listening.
Pause finalizes the current analyzer; Resume starts a new run and retains previous captions. Stop finalizes and ends the session. Reset requires confirmation.
Apple runtime/accessibility and 30+ minute checks NOT RUN on Windows. No latency or comfort claims are verified.
Manual: speak, pause/resume and check continuity; vary Dynamic Type/caption size, appearance, rotation and VoiceOver; disable live following and inspect older text; background/lock and verify stopped capture; perform a 30-minute session.
Next: local sessions and durable storage.
