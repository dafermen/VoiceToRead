# Verb reference — first version

Training > Verbs and sentences is a read-only English conjugation reference below Podcasts.
The library searches base/past/participle and English/Spanish meanings, with verb group and
tense filters. Details show all supported tenses or one selected tense, affirmative/negative/
question forms and seven pronouns (you covers singular and plural). Main filters are visible;
pronoun and slow-pronunciation controls are in an optional disclosure. Clear filters restores
the full view. Normal and large accessibility text wrap vertically without a wide table.

The initial catalog contains 28 curated everyday verbs, all five spelling patterns and regular
verbs. Rows in the supplied workbooks were reference material, not imported as trusted data:
misclassified AAB rows, nonstandard forms, duplicate senses and unnatural combinations are
excluded. The be/know/see examples omit continuous forms for their selected meanings.
English examples have descriptive localized labels and a bilingual verb gloss; this version
does not claim to translate every sentence. Examples use full negatives to make auxiliaries
visible. Be has subject-sensitive am/is/are and was/were; do/does/did use the base form.

Pronunciation uses the existing TranslationSpeechPlayer with the user's English voice from
Settings, slow initially. Only the requested word/example plays. A new selection replaces
the previous utterance; its control becomes Stop. Filters, leaving the screen, backgrounding,
audio interruptions and route changes stop playback. There is no microphone, recording,
translation request, external API, progress system or change to an existing training archive.
Button-name visibility, reading size, bold text, spacing and system dark mode are respected.

Validation: localization catalog and Xcode project references checked on Windows. Dataset
validation checks uniqueness, required forms and pattern coverage. Four XCTest methods cover
the conjugation engine, exceptions, filtering/search and all supported combinations. An XCUI
test covers entry, AAB filtering, tense/form/pronoun selections, slow default and touch targets.
Native Swift compilation, XCTest/XCUI execution, VoiceOver, playback and visual iPhone checks
require Xcode/macOS and have not been run on Windows.

## Per-form translation update

Each pronunciation row now places its contextual translation below the English word, using
the same caption font and secondary color as the form label. All 28 verbs include English
glosses and Spanish, French, Korean, Japanese and simplified Chinese equivalents. Was and
were have separate glosses. English inflections do not map one-to-one to target-language
conjugations; a short visible note states that meanings depend on context.

The existing LanguagePickerControl appears below the library/detail filters. Its choice is
shared within this module and survives navigation. Initially it follows the interface language;
a manual override is remembered until Use app language or a change of interface language in
Settings. A stale choice is discarded on reentry. Interface menus remain in the application's
currently supported English/Spanish locales; choosing French content does not change the
global interface. Search also accepts the new meanings. No API call or download is needed.

Additional XCTest coverage checks translation completeness, representative meanings, default/
override selection, settings changes and multilingual search. XCUI coverage checks Spanish,
French and return-to-app-language behavior. Native tests and visual verification remain pending
on macOS/iPhone; Windows checks cover resource integrity, localization and project references.
