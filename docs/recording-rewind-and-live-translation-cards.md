# Recording rewind and live translation cards — 2026-11-04

## Saved recording playback

Saved > Audio & subtitles shows an additional Back 10 seconds (`gobackward.10`) transport button when Continuous mode plays the original saved recording. It reuses SessionPlayer.seek, which preserves playing/paused state, clamps to the recording bounds and invalidates old completion callbacks. The current render position is refreshed before computing the target. Ten seconds refers to recording time, independent of playback speed. Existing cue/time observation updates the selected subtitle paragraph after crossing a boundary. Rewind returns the reader to following audio and is disabled at the beginning.

The button is not shown in At my pace or generated-speech/bilingual-sequence modes: those sources do not expose an equivalent continuous recording timeline. Their existing previous-paragraph and playback controls remain available. No speech duration is estimated or presented as a precise ten-second seek. The optional transport action defaults to absent in all other callers.

## Listen: translation-only cards

Translation-only live paragraphs, including pending translations, now use the same LiveLanguageCard modifier as bilingual paragraphs. The configured destination color, contrast, text size and spacing are preserved. Translation-only keeps one destination-language card while waiting, then fills it with the translated text. It does not briefly insert an original-language card; this also prevents the blue-card flash seen before this correction. Interleaved and column pairing, UUID matching, translation scheduling, capture and persistence remain intact.

## Verification

Native unit coverage adds a 30-second recording fixture for exact paused rewind, repeated clamping to zero, playback-speed independence, continuing playback, invalid inputs, range bounds and unloaded media. UI coverage exercises a ten-second seek across subtitle paragraphs, playing/paused behavior, disabled-at-start behavior, mode-specific visibility and translation-only cards. Static/local checks cover Swift delimiters, localization, project references and unchanged capture/translation/storage code. Native Swift compilation, XCTest and device audio/visual verification require Xcode/macOS/iPhone and were not run on Windows.
