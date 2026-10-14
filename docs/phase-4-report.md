> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 4 — Sessions and local storage
Implemented schema-versioned SwiftData sessions/segments, incremental final-caption saves, history, recoverable unfinished-session display, title/finished-transcript search, rename and confirmed cascade deletion. Added explicit Save Session and New Session. Startup/save errors are visible; no automatic store deletion.
Local-only CloudKit-none configuration; transcript directory excluded from backup. One repository test added.
Build, repository test and close/reopen iPhone acceptance NOT RUN on Windows.
Manual: start/speak/stop, relaunch and open history; verify recovered captions after interruption; rename, search and confirm deletion; retry failed save with low-storage conditions. Current session deletion is disabled until New Session.
Next: text export, clipboard and native sharing.
