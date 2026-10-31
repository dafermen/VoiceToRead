import Foundation

/// A small, reviewed reference catalog. No user training archive or translation is modified.
enum VerbTense: String, CaseIterable, Identifiable {
    case all = "All tenses"
    case presentSimple = "Simple present"
    case presentContinuous = "Present continuous"
    case presentPerfect = "Present perfect"
    case presentPerfectContinuous = "Present perfect continuous"
    case pastSimple = "Simple past"
    var id: Self { self }
    static var concrete: [Self] { allCases.filter { $0 != .all } }
    var explanation: String {
        switch self {
        case .all: return "Compare the same verb across tenses."
        case .presentSimple: return "Habits, routines and general facts."
        case .presentContinuous: return "Actions happening now or around now."
        case .presentPerfect: return "Past experiences or results connected to the present."
        case .presentPerfectContinuous: return "An activity continuing up to now, or with a present result."
        case .pastSimple: return "Actions completed in the past."
        }
    }
}

enum VerbSentenceForm: String, CaseIterable, Identifiable {
    case all = "All sentence forms", affirmative = "Affirmative", negative = "Negative", question = "Question"
    var id: Self { self }
    static var concrete: [Self] { allCases.filter { $0 != .all } }
}

enum VerbSubject: String, CaseIterable, Identifiable {
    case all = "All pronouns", i = "I", you = "You", he = "He", she = "She", it = "It", we = "We", they = "They"
    var id: Self { self }
    var third: Bool { self == .he || self == .she || self == .it }
    var amIsAre: String { self == .i ? "am" : third ? "is" : "are" }
    var wasWere: String { self == .i || third ? "was" : "were" }
    var questionText: String { self == .i ? "I" : rawValue.lowercased() }
    static var concrete: [Self] { allCases.filter { $0 != .all } }
}

enum VerbPattern: String, CaseIterable, Identifiable {
    case all = "All verb groups", regular = "Regular verbs", aaa = "AAA", abb = "ABB", abc = "ABC", aba = "ABA", aab = "AAB"
    var id: Self { self }
    var explanation: String {
        switch self {
        case .all: return "Base form → simple past → past participle"
        case .regular: return "Regular verbs: work → worked → worked"
        case .aaa: return "AAA: cut → cut → cut"
        case .abb: return "ABB: buy → bought → bought"
        case .abc: return "ABC: write → wrote → written"
        case .aba: return "ABA: come → came → come"
        case .aab: return "AAB: beat → beat → beaten"
        }
    }
}

struct ConjugationVerb: Codable, Equatable, Identifiable {
    let base: String
    let past: String
    let participle: String
    let thirdPerson: String
    let ing: String
    let meaningEs: String
    let meaningEn: String
    let complement: String
    let regular: Bool
    let continuous: Bool
    let translations: [String: [String: String]]
    let ipaUS: [String: String]
    func meaning(in language: CaptureLanguage) -> String {
        translations[language.code]?["meaning"] ?? (language == .spanish ? meaningEs : meaningEn)
    }
    func translatedForm(_ form: String, language: CaptureLanguage) -> String? {
        translations[language.code]?[form]
    }
    func pronunciation(_ form: String) -> String? { ipaUS[form] }
    func translatedPronunciation(_ form: String, language: CaptureLanguage) -> String {
        [translatedForm(form, language: language), pronunciation(form)].compactMap { $0 }.joined(separator: "  ")
    }
    func meaningAndPronunciation(in language: CaptureLanguage) -> String {
        [meaning(in: language), pronunciation("base")].compactMap { $0 }.joined(separator: "  ")
    }
    var id: String { base }
    /// Patterns compare spelling. Read is deliberately absent from this first catalog:
    /// equal spelling alone would conceal its changing pronunciation.
    var pattern: VerbPattern {
        if regular { return .regular }
        if base == past && past == participle { return .aaa }
        if past == participle { return .abb }
        if base == participle { return .aba }
        if base == past { return .aab }
        return .abc
    }
    func supports(_ tense: VerbTense) -> Bool {
        tense != .all && (continuous || (tense != .presentContinuous && tense != .presentPerfectContinuous))
    }
    func sentence(tense: VerbTense, form: VerbSentenceForm, subject: VerbSubject) -> String? {
        guard supports(tense), form != .all, subject != .all else { return nil }
        let predicate: String
        let auxiliary: String?
        switch tense {
        case .all: return nil
        case .presentSimple:
            if base == "be" { auxiliary = subject.amIsAre; predicate = complement }
            else if form == .affirmative { auxiliary = nil; predicate = (subject.third ? thirdPerson : base) + " " + complement }
            else { auxiliary = subject.third ? "does" : "do"; predicate = base + " " + complement }
        case .pastSimple:
            if base == "be" { auxiliary = subject.wasWere; predicate = complement }
            else if form == .affirmative { auxiliary = nil; predicate = past + " " + complement }
            else { auxiliary = "did"; predicate = base + " " + complement }
        case .presentContinuous:
            auxiliary = subject.amIsAre; predicate = ing + " " + complement
        case .presentPerfect:
            auxiliary = subject.third ? "has" : "have"; predicate = participle + " " + complement
        case .presentPerfectContinuous:
            auxiliary = subject.third ? "has" : "have"; predicate = "been " + ing + " " + complement
        }
        let tail = predicate.trimmingCharacters(in: .whitespaces)
        switch form {
        case .all: return nil
        case .affirmative:
            return [subject.rawValue, auxiliary, tail].compactMap { $0 }.joined(separator: " ") + "."
        case .negative:
            guard let auxiliary else { return nil }
            return "\(subject.rawValue) \(auxiliary) not \(tail)."
        case .question:
            guard let auxiliary else { return nil }
            return "\(auxiliary.prefix(1).uppercased() + String(auxiliary.dropFirst())) \(subject.questionText) \(tail)?"
        }
    }
    static func matching(_ catalog: [Self], query: String, pattern: VerbPattern, tense: VerbTense) -> [Self] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.filter {
            (pattern == .all || $0.pattern == pattern) && (tense == .all || $0.supports(tense)) &&
            (search.isEmpty || ([$0.base, $0.past, $0.participle, $0.meaningEs, $0.meaningEn] + $0.translations.values.compactMap { $0["meaning"] }).contains { $0.localizedStandardContains(search) })
        }.sorted { $0.base < $1.base }
    }
    static func load(bundle: Bundle = .main) throws -> [Self] {
        guard let url = bundle.url(forResource: "verbs", withExtension: "json", subdirectory: "VerbReference") else { throw CatalogFailure.invalid }
        let verbs = try JSONDecoder().decode([Self].self, from: Data(contentsOf: url))
        guard !verbs.isEmpty, Set(verbs.map(\.base)).count == verbs.count,
              verbs.allSatisfy({ ![$0.base, $0.past, $0.participle, $0.thirdPerson, $0.ing, $0.meaningEs, $0.meaningEn, $0.complement].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) })
        else { throw CatalogFailure.invalid }
        for verb in verbs {
            let keys = ["meaning", "base", "past", "participle", "third", "ing"] + (verb.base == "be" ? ["past-was", "past-were"] : [])
            guard keys.filter({ $0 != "meaning" }).allSatisfy({
                let ipa = verb.ipaUS[$0] ?? ""
                return ipa.hasPrefix("/") && ipa.hasSuffix("/") && ipa.count > 2
            }) else { throw CatalogFailure.invalid }
            guard CaptureLanguage.allCases.allSatisfy({ language in
                keys.allSatisfy { !(verb.translations[language.code]?[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }) else { throw CatalogFailure.invalid }
        }
        return verbs.sorted { $0.base < $1.base }
    }
    private enum CatalogFailure: Error { case invalid }
}

/// A manual content-language choice is separate from interface localization. Changing the
/// interface in Settings returns this reference to the new app language, even after reopening.
enum VerbTranslationPreference {
    static func language(saved: String, interfaceAtSelection: String, currentInterface: String) -> CaptureLanguage {
        if interfaceAtSelection == currentInterface, let value = CaptureLanguage(rawValue: saved) { return value }
        return CaptureLanguage.allCases.first { $0.code == currentInterface } ?? .english
    }
}

/// Manual, independent marks keyed by the stable English base form. These never assess
/// pronunciation or alter personal practices, examples, audio or the conjugation catalog.
struct VerbLibraryMarks: Codable, Equatable {
    var favorites: Set<String> = []
    var completed: Set<String> = []
    init(favorites: Set<String> = [], completed: Set<String> = []) {
        self.favorites = favorites; self.completed = completed
    }
    init(data: Data) { self = (try? JSONDecoder().decode(Self.self, from: data)) ?? Self() }
    var data: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    mutating func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }
    mutating func toggleCompleted(_ id: String) {
        if completed.contains(id) { completed.remove(id) } else { completed.insert(id) }
    }
    func includes(_ id: String, favoritesOnly: Bool, completedOnly: Bool) -> Bool {
        (!favoritesOnly || favorites.contains(id)) && (!completedOnly || completed.contains(id))
    }
}
