# ADR-005: Local versioned transcript storage
Status: Implemented; Mac/device verification pending.
Update 2026-10-09: the user explicitly authorized optional audio recording and background listening. See [media and subtitles](../media-and-subtitles.md); the original decision below is historical.
## Context
Final captions should survive interruption and app relaunch without accounts or cloud storage.
## Decision
Use SwiftData schema version 1 with ConferenceSession and related StoredCaption entities. Cascade delete captions. Persist finalized changes incrementally and time checkpoints, with a complete searchable text cache at normal session end. Recover unfinished sessions from stored segments.
Use an explicit application-support store, CloudKit none, backup-excluded directory and complete-until-first-authentication protection. No stored raw audio.
Storage startup failure shows Retry, never automatic deletion or an in-memory fallback masquerading as saved data. Surface save failures and pause listening when final caption persistence fails.
## Alternatives considered
Single ever-growing transcript saved each update: rejected. CloudKit: outside offline/local requirement. JSON files: less appropriate for structured session management.
## Consequences
Deleting the app loses local sessions. User must export anything they need to retain. Device backup is excluded for these sessions. Actual SQLite sidecar protection/backup exclusion needs device inspection before release.
Future schema changes must add a migration plan; never silently recreate a failed store.
