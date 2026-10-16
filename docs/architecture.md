# Architecture through Phase 9

Actualización V9: [experiencia accesible, respuestas escritas y papelera recuperable](accessible-experience.md). La tabla `SessionTrash` se añade sin modificar los modelos históricos.

Estado actual: **VoiceToRead 0.1.0 (1), esquema V8**. Los números de build de las secciones heredadas indican hitos del código base. Ver [A mi ritmo y favoritas](at-my-pace.md) y [entrega/verificación](pace-checkpoint.md). Las secciones con otros números describen etapas anteriores.
App -> AppRootView -> SessionCoordinator -> CaptionViewModel -> SpeechTranscribing.
CaptionViewModel selects LegacySpeechTranscriber for Xcode 15.2 builds and older iOS versions. Swift 6.2+ builds select AppleSpeechTranscriber on iOS 26+. Both use AudioCaptureService and never fall back to server recognition. Modern conversion stays in its AudioConversion actor.
MainActor owns observable UI state, capture/session control and SwiftData context. Conversion runs on its own actor.

## Audio and recognition
Start checks speech readiness, asks microphone permission only when needed, and starts the built-in mic. Compatibility readiness requires explicit speech authorization, en-US support, supportsOnDeviceRecognition and availability. Each system request independently rechecks those conditions and sets requiresOnDeviceRecognition=true.
Compatibility requests use cumulative full-request text ranges and a new run UUID for each request. After 50 seconds of submitted audio, endAudio waits for the final result (10-second timeout), then queued buffers feed the next request. The 128-frame raw queue fails on overflow; cancellation stops audio and unblocks finalization. Unexpected errors stop the session, preserving earlier final chunks. Hardware tests must verify continuity at request boundaries.
Tap buffers are copied into immutable-owned CapturedAudio values before crossing executor boundaries. @unchecked Sendable expresses that ownership contract; consumers never mutate a shared buffer.
AVAudioConverter produces AnalyzerInput at the analyzer-selected format. Asset download is an explicit separate action. Installed English assets are reserved for reuse.
Raw/input/result queues are bounded, overflow stops the session and missing audio/finalization timeouts surface errors.
Audio failures and relevant route/engine/media-service changes are marshaled to MainActor with generation checks. Unchanged input route/setup notifications do not stop a valid engine.

## Caption state
States: idle, preparing, listening, stopping, paused, ended, problem.
Start preparations and analyzer runs use separate cancellation generations. Stop/background invalidates outstanding permission/start intent.
By default, scene background handling stops microphone synchronously, checkpoints finalized state and schedules analyzer cleanup. Remembered Continue in background allows an already-running capture to continue; it never starts capture from background. Foreground never auto-resumes.
Pause/Stop finalize before ending a run; resume gets a new run identity. Partial results remain provisional and can be discarded on cancellation.
TranscriptAssembler replaces overlapping revisions by run/range, not text equality, so repeated words remain legitimate. Common chronological final append avoids a full history scan.
Active-listening duration uses ContinuousClock to avoid wall-clock changes; metadata uses Date.

## UI
Lazy segment rows show 300 recent final captions initially, with Load Earlier Captions. There is no growing single Text rendering the full live transcript.
User can disable live-follow to read older captions; scroll animation respects Reduce Motion. Caption text scales with Dynamic Type and user preference.
Screen wake is enabled only for active listening/caption view and reset on background/disappearance.
Settings and Offline Readiness expose actual microphone/model/storage state; unknown checks never become an assumed ready state.
Microphone diagnostics preserve the Phase 1 volume-only workflow.

## Persistence
Schema version 1 contains ConferenceSession and related StoredCaption rows with cascade deletion.
Repository upserts finalized changes by UUID and stores run ordering separately from audio timestamps. Time/capacity monitoring runs every 30 seconds. Final full-text cache is created at normal end for search.
MainActor saves incremental segments; profile cost on device before claiming long-session reliability. On write failure, captions remain in presentation state for retry/manual save; rollback invalidates repository caches.
CloudKit is disabled; the store directory is backup-excluded with complete-until-first-authentication protection. Store failure is explicit; no automatic destructive reset or deceptive in-memory fallback.
Future schema changes require an explicit migration plan.

## Privacy and distribution
System language/model preparation can use system download services. The compatibility engine cannot explicitly download models; its readiness screen directs users to English Dictation settings. Speech authorization is requested explicitly for that engine. The modern engine retains explicit AssetInventory installation. Explicit file export/Copy/Share can send text to user-selected destinations.
Local audio storage follows the remembered Save audio preference, snapshotted at Start. It initially defaults on for new installations; existing preferences are preserved. Microphone capture still requires an explicit start. No developer network client, tracking, ads, analytics, account or embedded secret.
Manifest includes app-owned preferences and disk-space reasons. Source review is not a binary privacy/security audit.
Phase 9 prepared metadata/icon/scripts/checklist. Local unit/UI/build checks and basic TestFlight use have since been recorded. On 2026-10-10, a Cloud archive was exported/uploaded from the Mac; see [distribution runbook](distribution-runbook.md). Detailed device/privacy/reliability validation and public-release inputs remain pending.
Phase 10 is not implemented.

ADRs: 001 offline-first, 002 Apple speech/minimum OS, 003 original foreground microphone policy, 004 speech pipeline, 005 original local storage, 006 Xcode 15 compatibility. The V4 recording/background section below supersedes the original no-recording/foreground-only constraints where noted. For a teaching-oriented explanation, read [the junior guide](junior-guide.md) and [code walkthrough](code-walkthrough.md).

## Transcript review and export
V3 adds one SessionReview record per session containing a JSON correction map keyed by caption UUID and the last read caption UUID. Recognition captions and bookmark snapshots remain unchanged. V1-to-V2-to-V3 lightweight migration adds the new model without changing the earlier models. Session deletion explicitly removes captions, bookmarks and review metadata together.

The editor works on local paragraph drafts, with up to 100 undo snapshots, explicit save/discard and restoration of the original. Editing an ongoing or paused session is blocked until Stop. Literal find/replace uses UTF-16 ranges, Unicode word boundaries and descending replacements to retain offsets. Repository writes reject stale paragraph identities.

Session reading, bookmark display, search and export resolve the same correction map. Export previews freeze saved paragraphs on entry. TXT/PDF, Copy and native sharing use the preview text; title/date/duration/language metadata is optional. Core Text paginates PDFs in a cancellable background task; PDFKit previews them. Native sharing uses a protected temporary file removed on dismissal. File export uses the native document picker. The later V4 media extension described below adds optional local recording; no network service is used.

## Recording and synchronized subtitles (V4)
SessionMedia is an additive model with a relative audio filename and JSON caption timing map. V3 model fields are unchanged; original recognition, corrections and bookmarks survive migration. Audio-enabled sessions force transcript persistence regardless of the normal autosave preference.

CaptureTimeline stamps owned tap buffers from accumulated sample counts. The same frames enter speech and the optional bounded serial SessionAudioRecorder. Pauses do not advance this clock. Legacy request offsets come from the first frame submitted to each request, including frames queued during finalization; modern analyzer ranges are shifted by capture duration at analyzer start. Native word ranges are preserved in final segments and saved independently.

The writer saves 16-bit PCM CAF in a protected, backup-excluded Recordings directory; keeping the file open over pauses avoids repeated codec padding. Stop closes the writer; explicit export encodes M4A with AVAssetExportSession. Format changes, full queues and write failures stop capture. Partial audio remains for review; a failed writer cannot resume. Export directories are unique, protected and cleaned after share dismissal/cancellation.

AVAudioSession uses playAndRecord + measurement + mixWithOthers + defaultToSpeaker. This allows coexistence but does not provide internal audio from another app. An explicit background preference retains capture under UIBackgroundModes/audio. Choices are persisted in AppSettings. Audio is snapshotted before preparation; background preference can change during capture. No automatic resume after interruptions. Playback is blocked while capture is active; the playback sheet stops on dismissal and pauses on scene inactivity.

SubtitleExport groups native timed words into short cues, preserves silence, removes overlap and formats valid millisecond SRT/WebVTT. Corrections are reflected in exported subtitles with estimated timing inside the original paragraph range. Old untimed sessions do not receive invented timestamps. Subtitle time follows the saved microphone recording, not the original video timeline.

## Explicit session decisions and recovery (V5)
SessionDraft is an additive marker keyed by session UUID. ConferenceSession and previous schema models are unchanged, so a V1–V4 session without a marker remains a saved library entry. Create(draft: true) saves both objects together before capture. onFinalized/onCheckpoint/onEnded checkpoint the draft; none of these publish it. publish removes the marker after an explicit Save. Deletion removes the marker and associated data. The history screen partitions sessions by marker IDs and lets recovered drafts be reviewed, saved or discarded without automatically reopening the microphone.

SessionCoordinator refuses newSession while a decision is pending. Save-and-new resets only after a successful publish; Discard stops/finalizes the recorder before deleting. AppSettings persists two global defaults. CaptionViewModel receives an audio snapshot before preparing and a mutable background choice; recorder timing cannot be changed retrospectively. The old autoSave preference is no longer used: recovery persistence and library publication are separate operations.

## Capture feedback and phrase playback (build 15)
The metering callback uses the existing microphone level stream, never a second AVAudioEngine tap. Both recognition engines forward values on MainActor; CaptionViewModel throttles rendering and resets the displayed level when capture stops. Recording status depends on a prepared recorder and listening state, not just a future preference.

Saved paragraph playback joins by paragraph UUID to generated subtitle cues. The player clamps ordinary seeking and rejects invalid play-from positions; selecting another phrase during playback does not toggle it off. Pause/Resume retains the draft UUID and recording sample timeline. Interruption recovery is explicit, and draft durability still depends on successful storage writes.

No schema migration or new background capability is required for this change. Suggested names and pinch preferences are local.

## Saved translation (V6)

SessionTranslation stores a validated JSON snapshot separately from recognition, SessionReview and media. It contains exact reviewed English, generated Spanish and Spanish-only edits. A full-source comparison invalidates stale translations. The SwiftUI Translation runner is SDK/OS gated, requests language preparation only after a user action, and saves only a complete result belonging to the active request. Existing models and store identity are unchanged. See [translation](translation.md).


## Learning expressions (V7)
Build 18 adds LearningExpression snapshots associated by session/paragraph UUID. LearningUnit is a pure presentation model using corrected source and current Spanish; it never synthesizes missing timing. PracticePlayer owns a separate playback lifecycle and cancels looping on exit/background/interruption. No microphone or new remote service is involved. Repository deletion removes study records with their session; deleting only a study record preserves source/translation/audio. See [learning design](learning.md).

## Build 20 — per-session language and presentation

CaptureLanguage is a persisted global default copied into the existing session language. Recognition configuration is locked after start; a pause is not a new session. Translation payloads add optional sourceLocale (old missing values mean English). Translation/learning views derive direction from session language, never the current global default. V7 schema and bundle identity are retained. Paper/rules are presentation preferences only; ReaderSurface uses a simple CoreGraphics ruling layer, cannot intercept input and is hidden from accessibility. Universal target family and iPad orientations enable native tablet layouts. See [inclusive guide](inclusive-use.md).

## Actualización 23 — 2026-10-12

El esquema actual es V8: SessionSchemaV7.models + SessionFavorite. El reproductor de sesiones usa segmentos de muestras limitados en AVAudioPlayerNode; el reproductor de práctica sigue separado. Ver [flujo y decisiones](at-my-pace.md).
