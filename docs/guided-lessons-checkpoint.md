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


## B1/B2 five-theme catalog

The level selector groups five themes at each level: Improving My English,
My Daily Routine, At the Doctor’s Office, A Job Interview and My First Day at a
New Job. IDs are SPK-B1-001…005 and SPK-B2-001…005. The existing SPK-B1-001
content/audio/support resources are preserved. Nine new original stories use
the same twenty-paragraph schema, eight grammar entries, eight expressions and
three reading rounds. The B2 stories are distinct narratives with more developed
reasoning, hedging, hypothetical consequences and clarification strategies.

Editorial review corrected grammar labels to match actual source sentences,
including used to, zero vs first conditional and second vs third conditional.
Medical-office stories are fictional communication practice; detailed treatment
and test-preparation instructions were removed. Chunk segments are exact extracts
of their source sentence. The original user-supplied 001 is unchanged, including
its original fragment selection.

All lessons include offline Marin recordings at the approved 0.85 speed, normal
speed selection, media-time word highlighting, repeating and shadowing, and
Spanish/French/Korean/Japanese/Simplified Chinese support. The generated support
packs are labeled as AI translations and still need fluent-speaker review. Only
the pilot has the provided photographic cover; new lessons use accessible themed
symbol placeholders according to the existing null-asset contract. Images can be
added later without changing lesson content or IDs.

Generation scripts now take --lesson, reuse existing files, and stop if cached
timing text differs from a changed paragraph. No key, .env or server API calls
are included in the app. User-created trainings, sessions and stories are not
read or migrated by this change. No scoring or progress logic is introduced.

Validation checks all ten stories, grammar/card consistency, source references,
two hundred audio hashes and word ranges, forty complete support packs and the
original JSON byte identity before publishing the catalog. XCTest adds whole-
catalog resource checks, distinct-level checks and a B1/B2 filter navigation test.
Local XCTest/playback verification is unavailable on Windows; Xcode/iPhone checks
remain necessary for real audio, layout and native-speaker quality assessment.


## C1/C2 catalog extension

The library now offers B1, B2, C1 and C2, with five lessons per level. Existing
B1/B2 lessons and generated media are preserved. Advanced themes:

- C1: Improving My English; A Job Interview; Resolving a Conflict;
  Defending a Proposal; Discussing Social Change.
- C2: Improving My English; A Job Interview; Mediating a Negotiation;
  An Ethical Dilemma; Disagreeing with Tact.

The two shared advanced themes use different narratives. C1 includes practical
argument, concession, qualification and negotiation of realistic expectations.
C2 emphasizes register, implicit meaning, reformulation, careful disagreement
and limits on what can be inferred from tone alone. These are authored learning
materials targeted at CEFR levels, not a formal CEFR assessment/certification.

Editorial review aligned eight grammar explanations with actual source sentences
per lesson, including inverted conditionals, focus constructions, fused relative
clauses and concessive forms. Essential expressions and complete chunked examples
are checked against their source paragraphs. Problematic overgeneralizations
about adjective position, directness and reading intentions were replaced.

The new lessons retain twenty English/Spanish paragraphs, eight grammar entries,
eight expressions, five objectives and three reading rounds. Four AI-generated
support packs per lesson add French, Korean, Japanese and Simplified Chinese;
these are labeled and need fluent-speaker review. Accessible themed placeholder
covers remain until dedicated artwork is provided. There is no new recording,
scoring, advancement or user-data migration logic.

Offline Marin audio uses the approved 0.85 base speed, existing Normal option,
word timings and unchanged repeat/shadowing controls. The developer scripts accept
C1/C2 identifiers. The catalog is only published after full resource validation.
Expected total: twenty lessons, four hundred audio assets and eighty support packs.
XCTest resource coverage and level-navigation tests include all four levels;
these cannot be executed locally on Windows. Xcode/iPhone playback/layout and
native-speaker editorial checks remain necessary. The API key stays in the
ignored development .env and is not copied into resources or the iPhone app.


## Illustrated lesson covers

All twenty guided lessons now have a local 16:9 PNG cover. Nineteen new editorial
photographs were created with the built-in image_gen tool and visually inspected;
the supplied SPK-B1-001 cover is preserved byte-for-byte. The originals were copied
without image conversion, resizing or replacement of existing media. Images load
through the existing lesson-ID cover convention in both library and detail reader,
and are included in the existing SpeakingLessons resource folder for offline use.
No lesson JSON, support text, audio or playback controls were modified.

docs/lesson-cover-prompts.json records the exact prompt set, built-in mode, saved
repository paths, dimensions and hashes. Each new image matches the lesson theme,
with consistent candid photography, daylight, warm neutrals and subtle blue accents.
The cover accessibility labels remain; image traits and stable IDs were added.
The resource validator requires twenty distinct landscape PNGs; XCTest adds native
UIImage decoding and uniqueness coverage, with a reader image accessibility check.
XCTest and iPhone visual verification cannot be run locally on Windows.
