import Foundation
import SwiftData

@Model
final class ConferenceSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var startedAt: Date
    var endedAt: Date?
    var duration: Double
    var language: String
    var transcript: String
    @Relationship(deleteRule: .cascade, inverse: \StoredCaption.session)
    var captions: [StoredCaption] = []

    init(title: String, startedAt: Date = Date()) {
        id = UUID()
        self.title = title
        createdAt = Date()
        self.startedAt = startedAt
        duration = 0
        language = "en-US"
        transcript = ""
    }

    var orderedCaptions: [StoredCaption] {
        captions.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.start < $1.start
        }
    }
    var fullTranscript: String { orderedCaptions.map(\.text).joined(separator: "\n") }
}

@Model
final class StoredCaption {
    @Attribute(.unique) var id: UUID
    var runID: UUID
    var start: Double
    var end: Double
    var text: String
    var order: Int
    var session: ConferenceSession?

    init(segment: CaptionSegment, order: Int) {
        id = segment.id
        runID = segment.runID
        start = segment.start
        end = segment.end
        text = segment.text
        self.order = order
    }
}

enum SessionSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [ConferenceSession.self, StoredCaption.self] }
}

/// Snapshots are independent of speech revisions, so a selected quote stays intact.
@Model
final class CaptionBookmark {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var segmentID: UUID
    var text: String
    var createdAt: Date

    init(sessionID: UUID, segment: CaptionSegment) {
        id = UUID()
        self.sessionID = sessionID
        segmentID = segment.id
        text = segment.text
        createdAt = Date()
    }
}

enum SessionSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ConferenceSession.self, StoredCaption.self, CaptionBookmark.self]
    }
}

enum SessionMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SessionSchemaV1.self, SessionSchemaV2.self, SessionSchemaV3.self, SessionSchemaV4.self, SessionSchemaV5.self, SessionSchemaV6.self, SessionSchemaV7.self, SessionSchemaV8.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SessionSchemaV1.self, toVersion: SessionSchemaV2.self),
         .lightweight(fromVersion: SessionSchemaV2.self, toVersion: SessionSchemaV3.self),
         .lightweight(fromVersion: SessionSchemaV3.self, toVersion: SessionSchemaV4.self),
         .lightweight(fromVersion: SessionSchemaV4.self, toVersion: SessionSchemaV5.self),
         .lightweight(fromVersion: SessionSchemaV5.self, toVersion: SessionSchemaV6.self),
         .lightweight(fromVersion: SessionSchemaV6.self, toVersion: SessionSchemaV7.self),
         .lightweight(fromVersion: SessionSchemaV7.self, toVersion: SessionSchemaV8.self)]
    }
}

/// Corrections and reading position do not change the original recognition data.
@Model
final class SessionReview {
    @Attribute(.unique) var sessionID: UUID
    var corrections: Data
    var lastReadCaptionID: UUID?
    var updatedAt: Date?

    init(sessionID: UUID) {
        self.sessionID = sessionID
        corrections = Data("{}".utf8)
    }

    func decodedCorrections() throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: corrections)
    }
}

enum SessionSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [ConferenceSession.self, StoredCaption.self, CaptionBookmark.self, SessionReview.self]
    }
}

/// Marcador independiente: migrar agrega una tabla, no modifica ni duplica las sesiones V7.
/// Ser favorita implica protección contra borrado de sesión y audio; no es una copia de seguridad.
@Model
final class SessionFavorite {
    @Attribute(.unique) var sessionID: UUID
    init(sessionID: UUID) { self.sessionID = sessionID }
}

enum SessionSchemaV8: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(8, 0, 0) }
    static var models: [any PersistentModel.Type] { SessionSchemaV7.models + [SessionFavorite.self] }
}

enum SessionProtectionFailure: LocalizedError {
    case protected
    var errorDescription: String? { "Remove favorite protection before deleting this session or its audio." }
}
