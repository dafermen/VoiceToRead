> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Phase 5 — Export and sharing
Implemented UTF-8 .txt export via native file exporter, text Copy and native ShareLink with title/date/listening-duration/language/unfinished status. Audio is never exported. Sharing is an explicit user action and the chosen destination may send text off-device.
Two export/filename tests added. Mac/device exporter, clipboard and share-sheet checks NOT RUN.
Manual: open a saved session, export .txt to On My iPhone, inspect metadata/Unicode, copy into Notes and open Share. Cancel export/share and confirm no session is lost. Validate long and unusual titles.
PDF deferred because text provides the required portable export without extra complexity.
Next: persistent preferences and offline readiness.
