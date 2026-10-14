import Foundation

struct ReviewParagraph: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var text: String
}

enum ReviewFailure: LocalizedError {
    case sessionChanged
    var errorDescription: String? { "This session changed. Reopen the editor before saving corrections." }
}

/// Borrador con snapshots de Undo/Redo; una nueva edición descarta el futuro y limita el pasado a 100.
struct EditHistory<Value: Equatable> {
    private(set) var value: Value
    private var past: [Value] = []
    private var future: [Value] = []
    init(_ value: Value) { self.value = value }
    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }
    mutating func set(_ newValue: Value) {
        guard newValue != value else { return }
        past.append(value)
        if past.count > 100 { past.removeFirst() }
        value = newValue
        future.removeAll()
    }
    mutating func undo() {
        guard let previous = past.popLast() else { return }
        future.append(value)
        value = previous
    }
    mutating func redo() {
        guard let next = future.popLast() else { return }
        past.append(value)
        value = next
    }
}

/// Resuelve una única versión visible del texto: corrección por UUID si existe, original en otro caso.
/// Reutilizar esta regla evita diferencias entre lectura, búsqueda y archivos compartidos.
enum TranscriptReview {
    static func paragraphs(originals: [ReviewParagraph], corrections: [String: String]) -> [ReviewParagraph] {
        originals.map { ReviewParagraph(id: $0.id, text: corrections[$0.id.uuidString] ?? $0.text) }
    }
    static func text(_ paragraphs: [ReviewParagraph]) -> String {
        paragraphs.map(\.text).joined(separator: "\n\n")
    }
}

struct TextMatch: Identifiable {
    let paragraphID: UUID
    let range: NSRange
    let source: String
    var id: String { "\(paragraphID)-\(range.location)-\(range.length)" }
    var before: String { (source as NSString).substring(to: range.location) }
    var matched: String { (source as NSString).substring(with: range) }
    var after: String { (source as NSString).substring(from: NSMaxRange(range)) }
}

struct TranscriptSearch {
    var query: String
    var replacement: String
    var wholeWords = true
    var caseSensitive = false

    func matches(in paragraphs: [ReviewParagraph]) -> [TextMatch] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let literal = NSRegularExpression.escapedPattern(for: query)
        let pattern = wholeWords ? "(?<![\\p{L}\\p{M}\\p{N}_])" + literal + "(?![\\p{L}\\p{M}\\p{N}_])" : literal
        guard let regex = try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive]) else { return [] }
        return paragraphs.flatMap { paragraph in
            regex.matches(in: paragraph.text, range: NSRange(paragraph.text.startIndex..., in: paragraph.text)).map {
                TextMatch(paragraphID: paragraph.id, range: $0.range, source: paragraph.text)
            }
        }
    }

    func replacing(_ match: TextMatch, in paragraphs: [ReviewParagraph]) -> [ReviewParagraph] {
        paragraphs.map { paragraph in
            guard paragraph.id == match.paragraphID, paragraph.text == match.source else { return paragraph }
            return ReviewParagraph(id: paragraph.id,
                text: (paragraph.text as NSString).replacingCharacters(in: match.range, with: replacement))
        }
    }

    func replacingAll(in paragraphs: [ReviewParagraph]) -> [ReviewParagraph] {
        let found = Dictionary(grouping: matches(in: paragraphs), by: \.paragraphID)
        return paragraphs.map { paragraph in
            var text = paragraph.text
            for match in (found[paragraph.id] ?? []).reversed() {
                text = (text as NSString).replacingCharacters(in: match.range, with: replacement)
            }
            return ReviewParagraph(id: paragraph.id, text: text)
        }
    }
}
