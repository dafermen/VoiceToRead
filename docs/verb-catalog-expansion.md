# Complete workbook verb coverage — 2026-11-01

The reference now contains **130 distinct base verbs**: all **125 distinct verbs** in the five supplied workbooks, plus the five existing additional verbs. **102 entries were added**, preserving all 28 previous records and their stable base-form IDs. Favorites, completion marks, translations of personal practices and all user archives retain their existing keys and storage.

## Source reconciliation

| Workbook | Rows | Distinct verbs |
| --- | ---: | ---: |
| 100_AAA_Irregular_Verbs.xlsx | 28 | 24 |
| 100_ABB_Irregular_Verbs.xlsx | 43 | 43 |
| 100_ABC_Irregular_Verbs.xlsx | 47 | 47 |
| 100_ABA_Irregular_Verbs.xlsx | 4 | 4 |
| 100_AAB_Irregular_Verbs.xlsx | 7 | 7 |

The filenames do not imply 100 distinct verbs each. Duplicate base forms are consolidated. `verb-workbook-coverage.json` records the complete source inventory for repeatable coverage validation, without requiring the original workbooks at runtime.

## Corrections and editorial decisions

- The supplied AAB labels are not imported as classifications. Groups are calculated from the selected base/past/participle spelling. Hew/hewed/hewn, mow/mowed/mown, prove/proved/proven, show/showed/shown and sow/sowed/sown are ABC. Beat remains AAB.
- Crow/crowed/crowed and snow/snowed/snowed use standard contemporary forms and are regular. The supplied `crown` and `snown` participles are not included. Crow selects the rooster-call meaning.
- Bid selects the auction sense: bid/bid/bid (AAA), not the bade/bidden forms used in other senses.
- Get/got/gotten selects the American acquisition/result sense. Lie/lay/lain/lying selects reclining, not lying about the truth.
- Valid variant choices such as burnt, dreamt, learnt, smelt, spelt, spoilt, fit and wet are retained. The reference displays a selected valid paradigm, not every regional or historical alternative.
- Read belongs to AAA by spelling, with present /riːd/ and past/participle /rɛd/. A brief localized note explains the difference. Explicit IPA hints are limited to the reference's read/lead/tear/say playback, including example sentences. The normal shared speaker behavior is unchanged when no hints are supplied; no recording or audio network service is added.
- Weather snow and the selected animal crow examples use it. Arise, cost and mean use it/they for the selected event/object meanings. Stative senses omit continuous example tenses. Existing example behavior is retained for the previous 28 entries.
- Each new entry includes six content languages, five IPA forms, a selected meaning and a reusable example complement. The word glosses are contextual equivalents, not claims of one-to-one grammatical equivalence across languages.
- Two-pass lexical review included manual correction of Spanish `cupo` and `quema`, French participles and gerunds, reset stress, dreamt pronunciation, and competition-specific Japanese/Korean/Chinese glosses for lose. Automated review suggestions were checked rather than blindly applied; incorrect proposals about rises and proven were rejected. Sink uses an intransitive example consistently across its glosses; keep uses possession of a spare key.

## Reference sources

- [British Council — irregular verbs](https://learnenglish.britishcouncil.org/free-resources/grammar/english-grammar-reference/irregular-verbs)
- [Cambridge — irregular verb spelling and read pronunciation](https://dictionary.cambridge.org/grammar/british-grammar/verbs-irregular-verbs)
- [Cambridge — lay and lie meanings](https://dictionary.cambridge.org/grammar/british-grammar/word-choice-lay-and-lie)
- Merriam-Webster: [bid](https://www.merriam-webster.com/dictionary/bid), [crow](https://www.merriam-webster.com/dictionary/crow), [snow](https://www.merriam-webster.com/dictionary/snow), [get](https://www.merriam-webster.com/dictionary/get), [hew](https://www.merriam-webster.com/dictionary/hew), [mow](https://www.merriam-webster.com/dictionary/mow), [prove](https://www.merriam-webster.com/dictionary/prove), [reset](https://www.merriam-webster.com/dictionary/reset), [offset](https://www.merriam-webster.com/dictionary/offset), [forbid](https://www.merriam-webster.com/dictionary/forbid).
- Collins: [fit](https://www.collinsdictionary.com/us/dictionary/english/fit), [wet](https://www.collinsdictionary.com/dictionary/english/wet); Cambridge: [forecast](https://dictionary.cambridge.org/us/dictionary/english/forecast).
- [Apple — IPA speech attributes](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisipanotationattribute), [attributed utterances](https://developer.apple.com/documentation/avfaudio/avspeechutterance/init(attributedstring:)).

Sources were consulted for spelling, sense, variant and pronunciation facts. Definitions, glosses and example complements are concise educational content, not copied dictionary example sentences.

## Validation and limitations

The validator checks 130 unique complete records, coverage of every source base, the corrected paradigms, six languages, IPA keys, filters and project registration. Added native tests cover corrected forms/groups, natural subjects, homograph pronunciation with auxiliaries, whole-word IPA attributes, empty overrides and stable marks. Existing full-combination tests now honor the selected-subject constraints; search tests account for newly matching verbs.

Windows checks cannot establish native Swift compilation, voice quality or XCTest/VoiceOver behavior on iPhone. Xcode Cloud compilation and device playback/visual review remain necessary. The available system voice determines actual synthesis quality.
