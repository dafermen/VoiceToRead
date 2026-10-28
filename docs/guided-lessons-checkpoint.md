# Guided lesson pilot: SPK-B1-001

Access: Train → Guided lessons → Improving My English. Existing free trainings
and their storage are unchanged. The supplied JSON and PNG cover are copied
without rewriting, conversion or generated replacements. The JSON remains the
source of truth; catalog.json enumerates bundled lessons without changing UI.
The cover is mapped locally by lesson ID, with an accessible 16:9 placeholder
when absent. image.prompt is never treated as a URL. HTTPS asset_url is optional.

The typed Decodable model validates schema version, level, twenty consecutive
nonempty bilingual paragraphs, eight expressions, references to paragraphs,
three reading rounds, chunks and lesson-card consistency. Invalid resources
display a recoverable library error; no user archive is read or overwritten.
The initial supported editorial language is en-US, matching this pilot.

The reader shows introduction, objectives, Part A, expandable grammar and
expressions, three rounds with slash-separated chunks, and expandable card.
Audio per paragraph uses a dedicated StoryNarrator instance with app-selected
English voice and existing generated-speech word boundaries. Slow reading starts
enabled. Stop, new playback, navigation away, app inactivity and interruptions
clear playback safely. No fake audio, microphone, recording, speaking questions,
assessment, advancement rules or B1 sublevels are added. No changes to Talk,
Listen or Stories production code. Training library changes only add an entry.

Accessibility: native List, Dynamic Type, scalable English text, 44-point playback
targets, voice-over labels and supplied cover alt text. Editorial Spanish/English
content remains verbatim; interface labels have English/Spanish localizations.

Validation on Windows: byte identity of supplied resources, content structure,
references, card consistency, project registration, localization and diff checks.
Added XCTest loading/validation tests and a UI navigation/rendering test. These
were not run locally because this machine does not have Xcode. Real playback,
word highlighting and iPhone/iPad visual layout still require device verification.


## Offline OpenAI audio, support languages and shadowing

Twenty Marin MP3 assets use the approved 0.85 generation speed. The first asset
is the approved slow preview. Each paragraph has Whisper word timestamps, checked
against the unchanged source words and converted to UTF-16 ranges. These timing
estimates follow the recording; they are not phonetic assessment or user grading.
The original English/Spanish lesson JSON remains byte-identical to the supplied
file. Additional support packs provide all 58 support fields in French, Korean,
Japanese and Simplified Chinese. They include paragraphs, grammar explanations,
expression meanings, objectives, instructions and card labels. These translations
are AI-generated, labeled in the UI, and still need editorial/native-speaker review.

Dedicated local AVAudioPlayer playback replaces phone synthesis only in guided
lessons. There is no runtime API, secret or network requirement for lesson audio.
Slow uses the approved recording unchanged; Normal plays that same recording at
1/0.85, keeping word highlights tied to media time. Support-language changes and
practice-mode changes stop audio. Backgrounding, navigating away, headphones
removal and audio interruptions stop playback without restarting automatically.
Pause/resume applies to audio, Stop cancels playback and any pending loop.

Understand plays once. Listen and repeat leaves a silent interval equal to the
paragraph duration before repeating. Shadowing repeats after a short 0.7-second
gap while the user follows the speaking voice. Automatic repeat can be disabled.
The user can hide the support translation. No recording, scoring, advancement
tracking or microphone permission was introduced. Other modules are unchanged.

scripts/generate-guided-audio.py and generate-lesson-support.py are developer-only
tools, not Xcode sources/resources. They read the ignored root .env and use HTTPS
OpenAI endpoints; never log keys. Existing assets are reused to avoid regeneration.
Neither the scripts nor the app bundles the .env. Only supplied editorial text
and generated lesson audio were sent for generation/alignment, no user sessions.

Local checks: 20 MP3 hashes, exact matching source word ranges, four complete
support packs, unchanged lesson JSON, localization and diff checks. XCTest covers
asset decoding/duration, cue validity, support availability and UI start/stop.
XCTest and physical-device speech quality, loop/pause behavior and layout checks
have not been run on Windows and require Xcode/iPhone verification.
