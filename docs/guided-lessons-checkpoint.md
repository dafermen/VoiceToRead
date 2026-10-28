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
