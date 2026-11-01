# Learning interface and beginner catalogue — 2026-11-01

## Scope

- Guided lessons: 21 topics × six levels (A1, A2, B1, B2, C1, C2) = 126 lessons. The 20 existing topics now have beginner adaptations. New topic `021`, Greetings / Saludos, appears first at every level without renumbering existing IDs. A native menu retains the chosen level and avoids squeezing six segments into one row.
- New content follows the existing schema: 20 bilingual paragraphs, eight source-backed structures, eight expressions, three reading rounds, and four support-language packs per lesson. Greetings distinguishes arrival and departure, register, introductions, phone greetings and brief replies, including “What’s up?”. The level labels describe intended difficulty, not external CEFR certification.
- 46 new lessons include 920 offline Marin clips at base speed 0.85, with measured word timings. Runtime does not require the developer API key. Text/audio hashes are validated before catalogue publication.
- My practices: a 44-point pencil beside each phrase opens only that translation. Saving checks the selected phrase snapshot and language pair; other phrases and preferences remain intact. Empty translations retain automatic preparation. The global review screen is removed, while whole-practice source/language editing and replacement confirmations remain.
- Settings contains an informational accuracy notice for automatic translations and manual edits. The individual translation editor also reminds users to check edits. This is product guidance, not a statement that legal liability is eliminated.
- Podcast fullscreen contains reading text, highlighting and one exit button. The same player remains active. Playback controls and reading preferences (including text size) remain available outside fullscreen.

## Covers

Beginner adaptations reuse their matching B1 topic cover. Greetings uses one new cover across six levels, generated with the built-in image generation tool: a horizontal editorial photograph of two adult neighbors smiling and waving near a cafe, natural light, no text, logos or UI. Representative saved asset: `VoiceToRead/Resources/SpeakingLessons/SPK-A1-021-cover.png`. All original 80 cover assets are preserved.

## Validation

- Full catalogue validator checks 126 distinct narratives, 2,520 audio/text hashes, UTF-16 word ranges, 504 support packs, covers, schemas and the original lesson 001 hash.
- All 920 new MP3 files fully decode with ffmpeg; measured cues fall within actual media duration (87.2 minutes of new audio).
- Added/updated XCTest coverage for six levels, Greetings ordering, single-phrase edits and stale snapshots, and fullscreen control visibility/rotation/state preservation.
- Windows cannot run the iOS compiler, XCTest or visual iPhone checks. Those checks remain for Xcode Cloud and device testing; delimiter/project checks are not substitutes for native compilation.

## Data preservation

No archive migration or deletion is introduced. Existing 80 guided lessons, recordings, personal practices, favourites, stories and verbs remain intact. Talk/Listen capture and translation code is outside this change.
