import Foundation

struct TranscriptionUpdate: Sendable {
    let runID: UUID
    let start: Double
    let end: Double
    let text: String
    let isFinal: Bool
    var words: [TimedWord]? = nil
    var sessionTime: Bool? = nil
}

struct CaptionSegment: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    let runID: UUID
    let start: Double
    let end: Double
    let text: String
    var words: [TimedWord]? = nil
    var sessionTime: Bool? = nil
}

struct FinalizedChange {
    let removedIDs: [UUID]
    let upserted: [CaptionSegment]
}

/// Replaces revisions by audio range within an analyzer run, never by text equality.
struct TranscriptAssembler {
    private(set) var finalized: [CaptionSegment] = []
    private(set) var partial: [CaptionSegment] = []
    private var runOrder: [UUID: Int] = [:]

    /// Sustituye revisiones solapadas del mismo run, conservando identidad y orden de lectura.
    /// Devuelve un delta persistible: eliminaciones y upserts. Repetir palabras no equivale a duplicar.
    mutating func apply(_ update: TranscriptionUpdate) -> FinalizedChange {
        guard update.start.isFinite, update.end.isFinite,
              update.start >= 0, update.end >= update.start else {
            return FinalizedChange(removedIDs: [], upserted: [])
        }
        let overlaps: (CaptionSegment) -> Bool = {
            $0.runID == update.runID &&
            (($0.start == update.start && $0.end == update.end) ||
             ($0.start < update.end && update.start < $0.end))
        }
        let previousPartial = partial.first(where: overlaps)
        partial.removeAll(where: overlaps)
        let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return FinalizedChange(removedIDs: [], upserted: []) }
        var segment = CaptionSegment(runID: update.runID, start: update.start, end: update.end, text: text, words: update.words, sessionTime: update.sessionTime)
        if let previousPartial { segment.id = previousPartial.id }
        if update.isFinal {
            if runOrder[update.runID] == nil {
                runOrder[update.runID] = runOrder.count
                finalized.append(segment)
                return FinalizedChange(removedIDs: [], upserted: [segment])
            }
            if let last = finalized.last,
               (last.runID == update.runID && update.start >= last.end),
               !(last.runID == update.runID && last.start == update.start && last.end == update.end) {
                finalized.append(segment)
                return FinalizedChange(removedIDs: [], upserted: [segment])
            }
            let replaced = finalized.filter(overlaps)
            if let existing = replaced.first { segment.id = existing.id }
            finalized.removeAll(where: overlaps)
            // Insert in time order within this run; keep earlier runs before later ones.
            let insertion = finalized.firstIndex { $0.runID == update.runID && $0.start > segment.start }
                ?? finalized.lastIndex(where: { $0.runID == update.runID }).map { $0 + 1 }
                // Replacing every segment of an earlier run must retain its position.
                ?? finalized.firstIndex { runOrder[$0.runID, default: 0] > runOrder[update.runID, default: 0] }
                ?? finalized.endIndex
            finalized.insert(segment, at: insertion)
            return FinalizedChange(removedIDs: replaced.filter { $0.id != segment.id }.map(\.id),
                                   upserted: [segment])
        }
        guard !finalized.contains(where: overlaps) else {
            return FinalizedChange(removedIDs: [], upserted: [])
        }
        partial.append(segment)
        partial.sort { $0.start < $1.start }
        return FinalizedChange(removedIDs: [], upserted: [])
    }

    mutating func discardPartial() { partial.removeAll() }
    var text: String { finalized.map(\.text).joined(separator: "\n") }
}
