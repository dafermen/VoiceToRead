import Foundation
import SwiftData

/// Palabra y rango de audio en segundos; Codable permite guardarla dentro del JSON de tiempos.
struct TimedWord: Codable, Equatable, Sendable {
    let text: String
    let start: Double
    let end: Double
}

struct CaptionTiming: Codable, Sendable {
    let start: Double
    let end: Double
    let words: [TimedWord]
}

/// Additive migration: the original transcript, bookmarks and corrections are unchanged.
@Model
final class SessionMedia {
    @Attribute(.unique) var sessionID: UUID
    var audioName: String?
    /// JSON de UUID de párrafo a CaptionTiming: separado del texto para conservar correcciones/originales.
    var timings: Data
    init(sessionID: UUID, audioName: String? = nil) {
        self.sessionID = sessionID
        self.audioName = audioName
        timings = Data("{}".utf8)
    }
    func decodedTimings() throws -> [String: CaptionTiming] {
        try JSONDecoder().decode([String: CaptionTiming].self, from: timings)
    }
}

enum SessionSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ConferenceSession.self, StoredCaption.self, CaptionBookmark.self, SessionReview.self, SessionMedia.self]
    }
}

/// A separate marker keeps every pre-update session saved during the additive migration.
/// Removing this marker publishes the existing data; it does not copy or recreate the audio.
@Model
final class SessionDraft {
    @Attribute(.unique) var sessionID: UUID
    init(sessionID: UUID) { self.sessionID = sessionID }
}

enum SessionSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ConferenceSession.self, StoredCaption.self, CaptionBookmark.self, SessionReview.self,
         SessionMedia.self, SessionDraft.self]
    }
}
