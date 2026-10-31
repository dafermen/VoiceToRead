import SwiftUI

@MainActor
struct VerbReferenceLibraryView: View {
    @State private var verbs: [ConjugationVerb] = []
    @State private var query = ""
    @State private var pattern: VerbPattern = .all
    @State private var tense: VerbTense = .all
    @State private var failed = false
    @Environment(AppSettings.self) private var settings
    @AppStorage("verbReferenceTranslationLocale") private var translationLocale = ""
    @AppStorage("verbReferenceInterfaceAtSelection") private var interfaceAtSelection = ""
    private var translationLanguage: CaptureLanguage {
        VerbTranslationPreference.language(saved: translationLocale, interfaceAtSelection: interfaceAtSelection,
                                           currentInterface: settings.interfaceLanguage.rawValue)
    }
    private var translationSelection: Binding<CaptureLanguage> {
        Binding(get: { translationLanguage }, set: {
            translationLocale = $0.rawValue
            interfaceAtSelection = settings.interfaceLanguage.rawValue
        })
    }
    private var matches: [ConjugationVerb] { ConjugationVerb.matching(verbs, query: query, pattern: pattern, tense: tense) }
    var body: some View {
        List {
            Section {
                Text("Choose a verb to read its conjugations and listen to its pronunciation.").font(.subheadline)
                Picker("Verb group", selection: $pattern) {
                    ForEach(VerbPattern.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }.accessibilityIdentifier("verbGroupFilter")
                Picker("Verb tense", selection: $tense) {
                    ForEach(VerbTense.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }.accessibilityIdentifier("verbLibraryTenseFilter")
                LanguagePickerControl(title: "Translation language", selection: translationSelection,
                                      choices: CaptureLanguage.allCases, showRole: true)
                    .accessibilityIdentifier("verbLibraryTranslationLanguage")
                Text(LocalizedStringKey(pattern.explanation)).font(.caption).foregroundStyle(.secondary)
            }
            if failed {
                Section {
                    Text("The verb reference could not be opened. Please try again.")
                    Button("Retry") { load() }
                }
            } else if matches.isEmpty && !verbs.isEmpty {
                Section {
                    ContentUnavailableView.search(text: query)
                    Button("Clear filters") { query = ""; pattern = .all; tense = .all }
                }
            } else {
                Section("Choose a verb") {
                    ForEach(matches) { verb in
                        NavigationLink { VerbConjugationView(verb: verb, initialTense: tense) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: verb.base).font(.headline)
                                Text(verbatim: verb.meaning(in: translationLanguage))
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(verbatim: "\(verb.base) · \(verb.past) · \(verb.participle)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }.accessibilityIdentifier("verb-" + verb.base)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search verb or meaning")
        .navigationTitle("Verbs and sentences").navigationBarTitleDisplayMode(.inline)
        .task { if verbs.isEmpty { load() } }
        .onAppear { followAppLanguage() }
        .onChange(of: settings.interfaceLanguage) { _, _ in translationLocale = ""; interfaceAtSelection = "" }
    }
    private func followAppLanguage() {
        if interfaceAtSelection != settings.interfaceLanguage.rawValue { translationLocale = ""; interfaceAtSelection = "" }
    }
    private func load() {
        do { verbs = try ConjugationVerb.load(); failed = false }
        catch { failed = true }
    }
}

@MainActor
private struct VerbConjugationView: View {
    let verb: ConjugationVerb
    @State private var tense: VerbTense
    @State private var form: VerbSentenceForm = .all
    @State private var subject: VerbSubject = .all
    @State private var slow = true
    @State private var player = TranslationSpeechPlayer()
    @State private var activeClip: String?
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("verbReferenceTranslationLocale") private var translationLocale = ""
    @AppStorage("verbReferenceInterfaceAtSelection") private var interfaceAtSelection = ""
    private var translationLanguage: CaptureLanguage {
        VerbTranslationPreference.language(saved: translationLocale, interfaceAtSelection: interfaceAtSelection,
                                           currentInterface: settings.interfaceLanguage.rawValue)
    }
    private var translationSelection: Binding<CaptureLanguage> {
        Binding(get: { translationLanguage }, set: {
            translationLocale = $0.rawValue
            interfaceAtSelection = settings.interfaceLanguage.rawValue
        })
    }
    @ScaledMetric(relativeTo: .body) private var minimumTextSize = 20.0
    init(verb: ConjugationVerb, initialTense: VerbTense) {
        self.verb = verb
        _tense = State(initialValue: initialTense)
    }
    private var tenses: [VerbTense] { VerbTense.concrete.filter { verb.supports($0) && (tense == .all || tense == $0) } }
    private var subjects: [VerbSubject] { VerbSubject.concrete.filter { subject == .all || subject == $0 } }
    private var forms: [VerbSentenceForm] { VerbSentenceForm.concrete.filter { form == .all || form == $0 } }
    var body: some View {
        List {
            Section {
                Text(verbatim: verb.meaning(in: translationLanguage)).font(.headline)
                Text(LocalizedStringKey(verb.pattern.explanation)).font(.caption).foregroundStyle(.secondary)
                Picker("Verb tense", selection: $tense) {
                    Text("All tenses").tag(VerbTense.all)
                    ForEach(VerbTense.concrete.filter { verb.supports($0) }) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }.accessibilityIdentifier("verbTenseFilter")
                Picker("Sentence form", selection: $form) {
                    ForEach(VerbSentenceForm.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }.accessibilityIdentifier("verbSentenceFilter")
                DisclosureGroup("Filters and pronunciation") {
                    Picker("Pronoun", selection: $subject) {
                        ForEach(VerbSubject.allCases) { value in
                            if value == .all { Text("All pronouns").tag(value) }
                            else { Text(verbatim: value.rawValue).tag(value) }
                        }
                    }.accessibilityIdentifier("verbPronounFilter")
                    Toggle("Slow pronunciation", isOn: $slow).accessibilityIdentifier("verbSlowPronunciation")
                    Button("Clear filters") { tense = .all; form = .all; subject = .all }
                }.accessibilityIdentifier("verbDetailFilters")
                LanguagePickerControl(title: "Translation language", selection: translationSelection,
                                      choices: CaptureLanguage.allCases, showRole: true)
                    .accessibilityIdentifier("verbTranslationLanguage")
                if !translationLocale.isEmpty && interfaceAtSelection == settings.interfaceLanguage.rawValue {
                    Button("Use app language") { translationLocale = ""; interfaceAtSelection = "" }
                        .font(.subheadline).accessibilityIdentifier("verbUseAppLanguage")
                }
                Text("Meanings vary with context and may not match word for word.")
                    .font(.caption).foregroundStyle(.secondary)
                if !verb.continuous {
                    Text("This meaning is shown in simple and perfect forms. Continuous forms are omitted to keep the examples natural.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = player.message { interfaceMessage(message).font(.subheadline).foregroundStyle(.red) }
            }
            Section("Verb pronunciation") {
                wordRow("Base form", word: verb.base, id: "base")
                if verb.base == "be" {
                    wordRow("Simple past", word: "was", id: "past-was")
                    wordRow("Simple past", word: "were", id: "past-were")
                } else { wordRow("Simple past", word: verb.past, id: "past") }
                wordRow("Past participle", word: verb.participle, id: "participle")
                wordRow("He / she / it", word: verb.thirdPerson, id: "third")
                wordRow("-ing form", word: verb.ing, id: "ing")
            }
            ForEach(tenses) { item in
                Section {
                    Text(LocalizedStringKey(item.explanation)).font(.subheadline).foregroundStyle(.secondary)
                    ForEach(subjects) { person in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(verbatim: person.rawValue).font(.headline).foregroundStyle(.secondary)
                            ForEach(forms) { kind in
                                if let sentence = verb.sentence(tense: item, form: kind, subject: person) {
                                    example(sentence, kind: kind, id: item.rawValue + "-" + person.rawValue + "-" + kind.rawValue)
                                }
                            }
                        }.padding(.vertical, 8)
                    }
                } header: { Text(LocalizedStringKey(item.rawValue)) }
            }
        }
        .navigationTitle(verb.base).navigationBarTitleDisplayMode(.inline)
        .onAppear { followAppLanguage(); player.observeInterruptions() }
        .onChange(of: settings.interfaceLanguage) { _, _ in translationLocale = ""; interfaceAtSelection = "" }
        .onDisappear { player.close() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        .onChange(of: tense) { _, _ in stop() }
        .onChange(of: form) { _, _ in stop() }
        .onChange(of: subject) { _, _ in stop() }
        .onChange(of: slow) { _, _ in stop() }
        .onChange(of: translationLanguage) { _, _ in stop() }
    }
    private func wordRow(_ label: String, word: String, id: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: word).font(.title3).textSelection(.enabled)
                if let translation = verb.translatedForm(id, language: translationLanguage) {
                    Text(verbatim: translation).font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled).accessibilityIdentifier("verbGloss-" + id)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            audioButton(text: word, id: "word-" + id)
        }
    }
    private func example(_ sentence: String, kind: VerbSentenceForm, id: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(kind.rawValue)).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: sentence)
                    .font(.system(size: max(minimumTextSize, settings.captionSize), weight: settings.boldCaptions ? .semibold : .regular))
                    .lineSpacing(settings.lineSpacing).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading)
            audioButton(text: sentence, id: id)
        }.accessibilityIdentifier("conjugation-" + id)
    }
    private func audioButton(text: String, id: String) -> some View {
        let playing = activeClip == id && player.state != .idle
        return Button {
            if playing { stop() }
            else {
                activeClip = id
                player.start([ReviewParagraph(id: UUID(), text: text)], language: .english, speed: slow ? .slow : .normal)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: playing ? "stop.fill" : "play.fill").font(.system(size: 18, weight: .semibold))
                if settings.showButtonNames { Text(LocalizedStringKey(playing ? "Stop" : "Play")).font(.caption2) }
            }.frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(LocalizedStringKey(playing ? "Stop" : "Play")) + Text(verbatim: ": " + text))
        .accessibilityIdentifier("verbAudio-" + id)
    }
    private func followAppLanguage() {
        if interfaceAtSelection != settings.interfaceLanguage.rawValue { translationLocale = ""; interfaceAtSelection = "" }
    }
    private func stop() { player.stop(); activeClip = nil }
}
