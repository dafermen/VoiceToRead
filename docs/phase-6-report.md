> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 6 — Preferences and offline readiness
Implemented persisted caption size, screen wake, appearance and auto-save preference; fixed initial en-US language; model/microphone/storage readiness and guided Test Offline Mode. Unknown storage is not represented as ready. Auto-save off requires explicit Save Session.
Settings includes microphone diagnostics and user-facing privacy text. Two preference/readiness tests added.
Mac/device validation NOT RUN. The checklist does not claim to detect Airplane Mode or guarantee successful engine startup. Minimum 64 MB applies to transcript headroom, not the size required for initial model download.
Manual: change preferences/relaunch, test auto-save off/manual save, install/missing model states, permission recovery, low/unknown storage and actual Airplane Mode captions.
Next: reliability safeguards, long-session profiling plan and interruption behavior.
