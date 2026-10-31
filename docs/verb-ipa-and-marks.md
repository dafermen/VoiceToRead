# Verb IPA and manual library marks

The catalog now includes a broad American English IPA transcription for all five displayed
forms of every verb, with separate was/were entries. Translation and IPA are shown together
on the existing secondary-text line; the base transcription is also next to the meaning in
the library and detail heading. Changing the support language changes the gloss, never the
English transcription. The pronunciation section identifies the American English reference.
Audio still speaks the English word through the existing selected voice; IPA is not spoken
or used to synthesize it, and its broad notation is not an exact phonetic trace of that voice.

Reference checks: Oxford's irregular-verb table for common base/past/participle relationships
and Cambridge pronunciation entries for the American variants and strong does/been/work.
Transcriptions of productive endings use broad phonemic notation (not every American flap
or reduction). No dictionary definitions, example sentences or audio recordings were copied.

- https://librodigital.oupe.es/eltdemos/swbook/irregular_verbs_list.html
- https://dictionary.cambridge.org/pronunciation/english/work
- https://dictionary.cambridge.org/pronunciation/english/bought
- https://dictionary.cambridge.org/us/pronunciation/english/does
- https://dictionary.cambridge.org/us/pronunciation/english/been

Each library row has independent Favorite and Done controls, separate from its NavigationLink
and using borderless button behavior. These are reversible manual marks, never automatic
assessments. The state is stored in the module-specific verbReferenceMarks UserDefaults Data
key, as two sets of stable base-form IDs. Other preferences and saved practice archives are
untouched; missing/corrupt preference data loads safely without an automatic overwrite.

Two independent filter buttons appear immediately above Choose a verb. Alone they show the
selected marked set; together they show its intersection, also respecting search/group/tense.
Turning off filters and Clear filters do not erase marks. Filters themselves reset on leaving
the library, while marks persist. Accessibility sizes stack row actions and filters, controls
retain 44-point targets, and names/VoiceOver state follow the existing UI preferences.

Validation covers catalog IPA completeness, representative irregular pronunciations, language
independence, independent toggles, preference serialization/reload and filter intersections.
XCUI coverage checks marking without navigation, relaunch persistence and combined filtering.
The previous language-selection test now expects translation followed by IPA. Local Windows
checks cannot execute native Swift compilation, XCTest, VoiceOver or iPhone visual testing.
