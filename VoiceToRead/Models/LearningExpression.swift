import Foundation
import SwiftData

/// Copia de estudio: corregir la transcripción después no reescribe lo que el alumno guardó.
/// Se elimina con su sesión; no se mezcla con el diccionario de reconocimiento.
@Model
final class LearningExpression {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var paragraphID: UUID
    // Historical field names retained for V7 stores: original text and opposite-language note.
    var english: String
    var spanish: String
    var context: String
    var start: Double?
    var end: Double?
    var createdAt: Date
    init(sessionID: UUID, unit: LearningUnit, english: String, spanish: String) {
        id = UUID(); self.sessionID = sessionID; paragraphID = unit.paragraphID
        self.english = english; self.spanish = spanish; context = unit.context
        start = unit.start; end = unit.end; createdAt = Date()
    }
    var unit: LearningUnit {
        LearningUnit(id: id.uuidString, paragraphID: paragraphID, english: english,
                     spanish: spanish.isEmpty ? nil : spanish, context: context, start: start, end: end)
    }
}

enum SessionSchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(7, 0, 0) }
    static var models: [any PersistentModel.Type] { SessionSchemaV6.models + [LearningExpression.self] }
}

struct LearningUnit: Identifiable, Equatable {
    let id: String
    let paragraphID: UUID
    let english: String
    let spanish: String?
    let context: String
    let start: Double?
    let end: Double?

    func audioRange(duration: Double) -> ClosedRange<Double>? {
        guard duration.isFinite, duration > 0, let start, let end, start.isFinite, end.isFinite,
              start >= 0, start < duration, end > start else { return nil }
        return start...min(end, duration)
    }
    static func make(paragraphs: [ReviewParagraph], timings: [String: CaptionTiming],
                     translation: TranslationSnapshot?) -> [LearningUnit] {
        let current = translation?.isCurrent(paragraphs) == true ? translation : nil
        let translatedCues = current.map { TranslatedSubtitles.cues(snapshot: $0, timings: timings, mode: $0.target.mode) } ?? []
        let spanishByCue = Dictionary(uniqueKeysWithValues: translatedCues.map { ($0.id, $0.text) })
        let spanishByParagraph = Dictionary(uniqueKeysWithValues: (current?.translated ?? []).map { ($0.id, $0.text) })
        let cues = Dictionary(grouping: SubtitleExport.cues(paragraphs: paragraphs, timings: timings), by: \.paragraphID)
        return paragraphs.flatMap { paragraph -> [LearningUnit] in
            guard !paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
            let timed = cues[paragraph.id] ?? []
            if timed.isEmpty {
                return [.init(id: paragraph.id.uuidString, paragraphID: paragraph.id, english: paragraph.text,
                    spanish: spanishByParagraph[paragraph.id], context: paragraph.text, start: nil, end: nil)]
            }
            return timed.map {
                LearningUnit(id: "cue-\($0.id)", paragraphID: paragraph.id, english: $0.text,
                    spanish: spanishByCue[$0.id], context: paragraph.text, start: $0.start, end: $0.end)
            }
        }
    }
}
