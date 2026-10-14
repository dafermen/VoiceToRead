# Audio and subtitle workflow

## Reducción opcional antes de grabar — build 22

El [filtro de ruido](noise-reduction.md) procesa la señal compartida por grabación y Speech, en el dispositivo. Se elige antes de la sesión y permanece al reanudar. Los archivos nuevos conservan el resultado; no se guarda una segunda copia sin filtro. El reloj de muestras y los subtítulos mantienen su duración. Las grabaciones existentes no se limpian con este interruptor.

Before Start, choose Audio and Background in Captions or use Capture preferences/Settings. On new installations, audio saving initially defaults on and background off. Existing choices, including the previous default-off audio behavior, are preserved. Both preferences are remembered across sessions and app relaunches. Recording follows the audio choice at Start; changes while listening apply to the next session. Background can be changed during capture. A recovery draft always stores final captions and any optional recording; Stop then Save publishes it, while confirmed Discard deletes it. A red Recording label appears while audio saving is active, including fullscreen. Stop before reviewing saved audio.

Sessions > open session > Audio & subtitles provides playback, ±10-second seeking, position slider, captions on/off and fullscreen rotation. M4A can be shared alone or together with corrected TXT and SRT/VTT. Native sharing provides Save to Files. Existing TXT/PDF review/export remains available. Delete audio keeps transcript, edits, bookmarks and subtitle timing; Delete session also deletes its audio.

Subtitles align to this session's audio, with pauses removed. Native recognition timing is retained; changed text is estimated inside the paragraph's saved range. Old sessions without recorded timing do not offer subtitle export. App switching mixes with other apps when allowed by iOS; it does not capture internal audio. The source must be audible to the microphone, so headphones will not work for transcribing another app.

## Required real-device checks
- Start with both options off: no recording file; background stops listening.
- Enable Save audio: speak, pause for ten seconds, resume, speak again, Stop. Replay around the boundary; pause time is omitted and subtitles stay aligned. Test across at least two recognition rotations.
- Correct a word, reopen Audio & subtitles; preview and export corrected TXT, SRT and VTT alongside M4A. Compare playback in an external compatible player.
- Enable Continue in background, start listening, switch to a video app using the speaker, then lock/unlock. Verify microphone indicator, final text, timing and explicit Stop. Repeat with a meeting app and check that calls/interruption surface a stopped state. No universal source-app compatibility is assumed.
- Delete audio and verify text/subtitle retention; delete session and verify file removal. Relaunch to confirm persistence.
- Verify long sessions, low storage, route changes, phone calls, airplane mode, device protection/backup and battery use on actual hardware.

Local tests cover recording/decoding, M4A conversion, sample clock, rotation/resume offsets, migrations, deletion, subtitle formatting and UI playback/export. Hardware recognition, long-session timing and source-app coexistence remain device validation tasks.

## Phrase review — build 15

In a stopped session, tap a paragraph with saved audio/timing to open playback at its first available cue. The player also offers a collapsed Listen by phrase list, keeping export actions within reach: selecting one seeks and starts playback; selecting another while playing changes position without pausing. The current phrase is highlighted. Play/Pause is available throughout playback and fullscreen. Editing pauses playback; corrections rebuild the cue text and retain the paragraph's saved range. Estimated corrected timings are not guaranteed word-accurate.

Missing audio or absent timing does not invent a seek position. Audio truncated by an earlier failure clips cues to the available recording. Plain transcripts remain selectable/editable. Pauses in recording are omitted from the sample timeline; playback pauses do not modify the recording.

Device checks: tap early and late paragraphs, pause/resume, switch phrases while playing, correct a paragraph and repeat, delete audio and verify the text remains. Test interruptions and reopening playback without overlapping microphone capture.

## Spanish and bilingual captions

Open Translation from a saved session. Its language selector controls text export and the player opened from that screen. The recording remains English. Spanish words are distributed approximately across existing English cue windows; bilingual cues include both languages. Missing timing is never invented for old sessions. See [translation](translation.md).

## Actualización 23 — 2026-10-12

Build 23 añade Continua/A mi ritmo, párrafos completos con parada, Repetir/Siguiente y corrección directa. Una favorita bloquea también Delete audio. El original CAF permanece intacto al corregir. Ver [guía completa](at-my-pace.md).
