# Podcasts pilot and Training navigation

Home now has Talk, Listen and Train. Training contains Guided lessons, My
practices, Stories and Podcasts in that order. Moving the Stories entry does not
read, migrate or rewrite its library. Talk/Listen audio and session behavior are
unchanged. Existing creation, review, playback and deletion confirmations remain
in their current story views.

The first bundled episode, POD-B1B2-001, is Small Steps, Better Listening /
Pequeños pasos para escuchar mejor. Its original 1,663-word English script uses
thirty short fragments and optional Spanish support. Broad listening-practice
themes from the supplied reference informed a new neighborhood-market/workshop
scenario and new examples. No source subtitles, original presenters, promotions,
source links or platform branding are bundled. The selected pilot scope is
8–12 minutes: verified media totals are 9.71 minutes at normal speed and 11.42
minutes at slow speed.

The library and reader follow the existing List/NavigationLink layout, typography
and button-name setting. The reader offers continuous playback, Play/Pause, Stop,
Previous/Next, direct fragment replay, normal/slow speed, transcript visibility,
optional translation and follow-narration control. Output circles have explicit
48-point dimensions and icon sizes. Slow starts enabled. The transcript highlights
exact UTF-16 word ranges using measured source-audio currentTime; normal playback
uses rate 1/baseSpeed and slow playback uses rate 1. The displayed timeline stays
anchored to normal-speed content time when pace changes, preventing clock jumps.
There is no score, mandatory quiz, account or microphone request.

PodcastPlayback owns a separate AVAudioPlayer output and keeps its playback session
between adjacent fragments. Pause releases the session and preserves position;
resume does not recreate the clip. Stop resets to the beginning. Route loss,
interruption and leaving the active app pause; leaving the reader stops/cleans up.
There is no automatic restart after interruption or background playback support.
Generation tokens reject stale completion callbacks after fragment changes/Stop.
New episode resources are loaded by an explicit validated catalog; malformed IDs,
missing files and invalid segment ordering fail without accessing user stores.

Audio was generated once during development through the existing OpenAI Speech
API workflow, using Marin at base speed 0.85. AI voice disclosure is visible in the
reader. Whisper word timings were accepted only when the complete recognized text
matched the script; two mismatched clips were backed up outside the app and
regenerated. No inferred subtitle offsets or guessed word times are used. The
local ignored .env is not bundled or committed. Runtime playback needs neither a
developer API key nor a network call. Generated assets are cached to avoid repeat
paid requests; changed source text requires explicit regeneration.

Official documentation reviewed for the existing generation workflow:
- [Speech generation](https://developers.openai.com/api/docs/guides/text-to-speech)
- [Measured word timestamps](https://developers.openai.com/api/docs/guides/speech-to-text)

These generation APIs have announced retirement dates in the official docs. The
offline bundled episode has no runtime dependency on those endpoints. Future
development-time generation should migrate before their shutdown; no broad
existing-audio pipeline migration is included in this feature.

Validation covers thirty readable MP3 durations, audio/text hashes, exact source
word ranges, ordered bilingual content, pilot duration bounds, absence of review
files/secrets/source SRTs, Training entry order and resource registration.
Localization keys/placeholders match. The legacy all-purpose static validator
cannot handle current variant groups and has stale fixed test counts; its
OpenStep/project-reference checks were run separately with pathless variant groups
handled. This does not substitute for Swift compilation.

Native resource tests check decoded media duration and range validity. Injected
output tests cover continuous advancement, preserving paused position, rate
changes, no audio on idle selection, Stop/stale completion, completion/restart,
missing-output errors and invalid resource IDs. UI coverage follows the moved
story path and opens/plays/pauses/stops the pilot without microphone prompts.
Xcode/XCTest and iPhone UI cannot be executed on Windows. Xcode Cloud archive and
physical-device checks remain required: first/last word highlight, fragment
transitions, both speeds, manual scrolling/follow off, larger text/VoiceOver,
headphone disconnect, interruptions, tabs/back navigation and airplane-mode play.
