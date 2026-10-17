import Foundation
import SwiftData

/// Una traducción es una copia derivada: nunca sustituye reconocimiento ni correcciones originales.
/// El snapshot exacto permite detectar cambios de origen sin depender de hashes o fechas.
struct TranslationSnapshot: Codable, Equatable, Sendable {
    let source: [ReviewParagraph]
    let generated: [ReviewParagraph]
    var edits: [String: String] = [:]

    // Optional for compatibility: payloads written before build 20 imply English source.
    var sourceLocale: String? = nil
    var targetLocale: String? = nil
    var target: CaptureLanguage { CaptureLanguage(rawValue: targetLocale ?? "") ?? language.defaultTarget }
    var language: CaptureLanguage { CaptureLanguage(rawValue: sourceLocale ?? "en-US") ?? .english }
    var english: [ReviewParagraph] { paragraphs(mode: .english) }
    var spanish: [ReviewParagraph] { paragraphs(mode: .spanish) }
    var translated: [ReviewParagraph] {
        TranscriptReview.paragraphs(originals: generated, corrections: edits)
    }
    /// Legacy nil locales and their explicit replacements represent the same document.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source == rhs.source && lhs.generated == rhs.generated && lhs.edits == rhs.edits &&
        lhs.language == rhs.language && lhs.target == rhs.target
    }
    func isCurrent(_ paragraphs: [ReviewParagraph]) -> Bool { source == paragraphs }
    func paragraphs(mode: TranscriptLanguage) -> [ReviewParagraph] {
        if mode == language.mode { return source }
        if mode == target.mode { return translated }
        if mode == .both {
            return zip(source, translated).map { ReviewParagraph(id: $0.id, text: $0.text + "\n" + $1.text) }
        }
        return []
    }
    func fileSuffix(mode: TranscriptLanguage) -> String {
        mode == .both ? language.code + "-" + target.code : mode.fileSuffix
    }

    func validate() throws {
        if let targetLocale, CaptureLanguage(rawValue: targetLocale) == nil { throw TranslationFailure.incomplete }
        guard language != target else { throw TranslationFailure.incomplete }
        if let sourceLocale, CaptureLanguage(rawValue: sourceLocale) == nil { throw TranslationFailure.incomplete }
        guard !source.isEmpty, Set(source.map(\.id)).count == source.count,
              source.map(\.id) == generated.map(\.id),
              edits.keys.allSatisfy({ key in source.contains { $0.id.uuidString == key } }),
              zip(source, generated).allSatisfy({
                  $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  !$1.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }) else { throw TranslationFailure.incomplete }
    }
}

enum TranscriptLanguage: String, CaseIterable, Identifiable {
    case english = "English", spanish = "Español", french = "Français", korean = "한국어", both = "Both"
    var id: Self { self }
    var fileSuffix: String {
        switch self { case .english: "en"; case .spanish: "es"; case .french: "fr"; case .korean: "ko"; case .both: "bilingual" }
    }
}

enum TranslationFailure: LocalizedError {
    case incomplete, sourceChanged, unsupported, unsupportedPair
    var errorDescription: String? {
        switch self {
        case .unsupportedPair: return "This language pair is not supported on this device. Choose another translation language."
        case .incomplete: return "The translation is incomplete. Please try again. Your saved text is unchanged."
        case .sourceChanged: return "The source transcript changed. Reopen Translation and translate again."
        case .unsupported: return "Translation requires iOS 18 or later and a compatible app build. Saved translations remain available."
        }
    }
}

@Model
final class SessionTranslation {
    @Attribute(.unique) var sessionID: UUID
    var payload: Data
    init(sessionID: UUID, payload: Data) { self.sessionID = sessionID; self.payload = payload }
    /// New payloads keep every destination. Legacy payloads decode as a one-item library.
    func library() throws -> TranslationLibrary {
        if let library = try? JSONDecoder().decode(TranslationLibrary.self, from: payload) {
            guard !library.snapshots.isEmpty, library.snapshots.contains(where: { $0.target == library.activeTarget }) else { throw TranslationFailure.incomplete }
            for snapshot in library.snapshots { try snapshot.validate() }
            return library
        }
        let old = try JSONDecoder().decode(TranslationSnapshot.self, from: payload)
        try old.validate()
        return TranslationLibrary(activeTarget: old.target, snapshots: [old])
    }
    func decoded() throws -> TranslationSnapshot {
        let library = try library()
        guard let result = library.snapshots.first(where: { $0.target == library.activeTarget }) else { throw TranslationFailure.incomplete }
        return result
    }
    func decoded(target: CaptureLanguage) throws -> TranslationSnapshot? {
        try library().snapshots.first { $0.target == target }
    }

}

struct TranslationLibrary: Codable {
    var activeTarget: CaptureLanguage
    var snapshots: [TranslationSnapshot]
}

enum SessionSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ConferenceSession.self, StoredCaption.self, CaptionBookmark.self, SessionReview.self,
         SessionMedia.self, SessionDraft.self, SessionTranslation.self]
    }
}

/// Conserva las ventanas del original. Reparte las palabras traducidas proporcionalmente entre ellas;
/// es sincronización aproximada dentro del párrafo, no alineación fonética entre idiomas.
enum TranslatedSubtitles {
    static func cues(snapshot: TranslationSnapshot, timings: [String: CaptionTiming],
                     mode: TranscriptLanguage) -> [SubtitleCue] {
        let original = SubtitleExport.cues(paragraphs: snapshot.source, timings: timings)
        guard mode != snapshot.language.mode else { return original }
        guard mode == snapshot.target.mode || mode == .both else { return [] }
        let spanish = Dictionary(uniqueKeysWithValues: snapshot.translated.map { ($0.id, $0.text) })
        let grouped = Dictionary(grouping: original, by: \.paragraphID)
        var result: [SubtitleCue] = []
        for paragraph in snapshot.source {
            let cues = grouped[paragraph.id] ?? []
            let words = (spanish[paragraph.id] ?? "").split(whereSeparator: \.isWhitespace)
            let total = cues.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
            guard total > 0 else { continue }
            var offset = 0
            for cue in cues {
                let start = offset * words.count / total
                offset += cue.text.split(whereSeparator: \.isWhitespace).count
                let end = offset * words.count / total
                let translated = words[start..<end].joined(separator: " ")
                let text = mode == .both ? cue.text + (translated.isEmpty ? "" : "\n" + translated) : translated
                guard !text.isEmpty else { continue }
                result.append(SubtitleCue(id: cue.id, paragraphID: cue.paragraphID,
                    start: cue.start, end: cue.end, text: text))
            }
        }
        return result.sorted { $0.start < $1.start }
    }
}


/// Plan puro: solo solicita párrafos nuevos/modificados; UUID + texto identifican lo reutilizable.
/// Las correcciones del destino se conservan si el texto y el idioma de origen siguen siendo idénticos.
struct IncrementalTranslation {
    let source: [ReviewParagraph]
    let previous: TranslationSnapshot?
    var language: CaptureLanguage = .english
    var targetLanguage: CaptureLanguage? = nil
    var target: CaptureLanguage { targetLanguage ?? language.defaultTarget }
    private var compatiblePrevious: TranslationSnapshot? { previous?.language == language && previous?.target == target ? previous : nil }
    var pending: [ReviewParagraph] {
        source.filter { paragraph in
            compatiblePrevious?.source.contains(paragraph) != true
        }
    }
    func merging(_ responses: [ReviewParagraph]) throws -> TranslationSnapshot {
        guard responses.map(\.id) == pending.map(\.id) else { throw TranslationFailure.incomplete }
        let fresh = Dictionary(uniqueKeysWithValues: responses.map { ($0.id, $0) })
        let retained = Set(source.filter { compatiblePrevious?.source.contains($0) == true }.map { $0.id.uuidString })
        let generated = try source.map { paragraph -> ReviewParagraph in
            if let response = fresh[paragraph.id] { return response }
            guard let old = compatiblePrevious?.generated.first(where: { $0.id == paragraph.id }) else {
                throw TranslationFailure.incomplete
            }
            return old
        }
        let result = TranslationSnapshot(source: source, generated: generated,
            edits: compatiblePrevious?.edits.filter { retained.contains($0.key) } ?? [:], sourceLocale: language.rawValue, targetLocale: target.rawValue)
        try result.validate()
        return result
    }
}

/// Diccionario sencillo editable: una entrada por línea, «English = español» o solo un nombre.
/// Máximo 100 frases breves. No sustituye partes de palabras ni interpreta expresiones regulares.
enum PersonalVocabulary {
    static let key = "personalVocabulary"
    struct Term: Equatable, Sendable { let source: String; let target: String }
    struct Part: Equatable, Sendable { let text: String; let literal: Bool }
    static func terms(_ raw: String) -> [Term] {
        var seen = Set<String>()
        return Array(raw.components(separatedBy: .newlines).compactMap { line -> Term? in
            let pieces = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let first = pieces.first else { return nil }
            let source = first.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = pieces.count == 2 ? pieces[1].trimmingCharacters(in: .whitespacesAndNewlines) : source
            guard !source.isEmpty, !target.isEmpty, source.count <= 80, target.count <= 120,
                  seen.insert(source.lowercased()).inserted else { return nil }
            return Term(source: source, target: target)
        }.prefix(100))
    }
    static func saved(defaults: UserDefaults = .standard) -> [Term] {
        terms(defaults.string(forKey: key) ?? "")
    }
    static func saved(for language: CaptureLanguage, target: CaptureLanguage? = nil, defaults: UserDefaults = .standard) -> [Term] {
        // The existing personal dictionary is explicitly English/Spanish. Never apply it to another pair.
        guard Set([language, target ?? language.defaultTarget]) == Set([CaptureLanguage.english, .spanish]) else { return [] }
        let entries = saved(defaults: defaults)
        guard language == .spanish else { return entries }
        var seen = Set<String>()
        return entries.compactMap { term in
            guard seen.insert(term.target.lowercased()).inserted else { return nil }
            return Term(source: term.target, target: term.source)
        }
    }
    static func parts(_ text: String, terms: [Term]) -> [Part] {
        guard !terms.isEmpty else { return [Part(text: text, literal: false)] }
        let ordered = terms.sorted { $0.source.count > $1.source.count }
        let alternatives = ordered.map { NSRegularExpression.escapedPattern(for: $0.source) }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])(?:" + alternatives + ")(?![\\p{L}\\p{N}_])", options: [.caseInsensitive]) else {
            return [Part(text: text, literal: false)]
        }
        let ns = text as NSString
        var offset = 0
        var result: [Part] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > offset {
                result.append(Part(text: ns.substring(with: NSRange(location: offset, length: match.range.location - offset)), literal: false))
            }
            let found = ns.substring(with: match.range)
            let term = ordered.first { $0.source.caseInsensitiveCompare(found) == .orderedSame }
            result.append(Part(text: term?.target ?? found, literal: true))
            offset = NSMaxRange(match.range)
        }
        if offset < ns.length { result.append(Part(text: ns.substring(from: offset), literal: false)) }
        return result
    }
    /// Traduce fragmentos libres y conserva literalmente los términos preferidos y espacios externos.
    /// Es determinista; la concordancia alrededor del término requiere revisión humana.
    static func translate(_ text: String, terms: [Term], using translate: (String) async throws -> String) async throws -> String {
        var result = ""
        for part in parts(text, terms: terms) {
            try Task.checkCancellation()
            let core = part.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.literal || core.isEmpty || !core.unicodeScalars.contains(where: CharacterSet.letters.contains) {
                result += part.text
            } else {
                let prefix = String(part.text.prefix(while: \.isWhitespace))
                let suffix = String(part.text.reversed().prefix(while: \.isWhitespace).reversed())
                result += prefix + (try await translate(core)) + suffix
            }
        }
        return result
    }
}


/// Preferencia de lectura, independiente del idioma de captura y del idioma de los menús.
enum LiveCaptionDisplay: String, CaseIterable {
    case original, translation, both
}

/// Cola acotada para lectura en directo. Los resultados tardíos nunca sustituyen texto actualizado.
/// Solo vive en memoria: cerrar la vista no modifica ni borra la transcripción inglesa guardada.
struct LiveTranslationBuffer {
    private(set) var source: [ReviewParagraph] = []
    private(set) var translated: [UUID: String] = [:]
    mutating func synchronize(_ paragraphs: [ReviewParagraph]) {
        let next = Array(paragraphs.suffix(40))
        let unchanged = Set(next.filter { source.contains($0) }.map(\.id))
        translated = translated.filter { unchanged.contains($0.key) }
        source = next
    }
    var pending: [ReviewParagraph] { Array(source.filter { translated[$0.id] == nil }.prefix(4)) }
    mutating func accept(_ values: [ReviewParagraph], for requested: [ReviewParagraph]) throws {
        try TranslationSnapshot(source: requested, generated: values).validate()
        for (original, response) in zip(requested, values) where source.contains(original) {
            translated[original.id] = response.text
        }
    }
}
