import Foundation
import SwiftData

/// Frontera de persistencia: el resto de la app solicita operaciones sin gestionar ModelContext.
/// Conserva modelos originales, aplica migraciones y mantiene rutas de audio dentro del almacén.
/// El contexto vive en MainActor; los fallos se propagan para que la interfaz permita recuperación.
@MainActor
final class TranscriptRepository {
    let container: ModelContainer
    private let context: ModelContext
    private var cacheSessionID: UUID?
    private var currentCaptions: [UUID: StoredCaption] = [:]
    private var nextOrder = 0
    private var runOrder: [UUID: Int] = [:]
    let storageURL: URL?

    init(inMemory: Bool = false, directory: URL? = nil) throws {
        let schema = Schema(versionedSchema: SessionSchemaV10.self)
        let configuration: ModelConfiguration
        if inMemory {
            storageURL = nil
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        } else {
            // Keep the original storage directory so existing sessions survive the app rename.
            var folder = try directory ?? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("VoiceToRead", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let file = folder.appendingPathComponent("Sessions.store")
            storageURL = file
            configuration = ModelConfiguration("Sessions", schema: schema, url: file, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, migrationPlan: SessionMigrationPlan.self, configurations: [configuration])
        context = container.mainContext
        context.autosaveEnabled = false
    }

    func create(title: String, draft: Bool = false, language: CaptureLanguage = .english) throws -> ConferenceSession {
        let session = ConferenceSession(title: title)
        session.language = language.rawValue
        context.insert(session)
        if draft { context.insert(SessionDraft(sessionID: session.id)) }
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
        currentCaptions = [:]
        nextOrder = 0
        runOrder = [:]
        cacheSessionID = session.id
        return session
    }

    /// Aplica cambios por UUID para que reintentar un guardado no duplique párrafos.
    /// Solo los segmentos con tiempo de sesión válido alimentan el mapa de subtítulos.
    func apply(_ change: FinalizedChange, to session: ConferenceSession) throws {
        if cacheSessionID != session.id {
            currentCaptions = Dictionary(uniqueKeysWithValues: session.captions.map { ($0.id, $0) })
            runOrder = [:]
            for caption in session.captions { runOrder[caption.runID] = caption.order }
            nextOrder = (session.captions.map { $0.order }.max() ?? -1) + 1
            cacheSessionID = session.id
        }
        for id in change.removedIDs {
            if let caption = currentCaptions.removeValue(forKey: id) {
                session.captions.removeAll { $0.id == id }
                context.delete(caption)
            }
        }
        for segment in change.upserted {
            if let existing = currentCaptions[segment.id] {
                existing.text = segment.text
                existing.start = segment.start
                existing.end = segment.end
            } else {
                let rank: Int
                if let existingRank = runOrder[segment.runID] {
                    rank = existingRank
                } else {
                    rank = nextOrder
                    nextOrder += 1
                    runOrder[segment.runID] = rank
                }
                let caption = StoredCaption(segment: segment, order: rank)
                context.insert(caption)
                session.captions.append(caption)
                currentCaptions[caption.id] = caption
            }
        }
        let existingMedia = try media(for: session.id)
        if change.upserted.contains(where: { $0.sessionTime == true }) ||
            (!change.removedIDs.isEmpty && existingMedia != nil) {
            let media = existingMedia ?? SessionMedia(sessionID: session.id)
            var timing = try media.decodedTimings()
            for id in change.removedIDs { timing.removeValue(forKey: id.uuidString) }
            for segment in change.upserted where segment.sessionTime == true {
                timing[segment.id.uuidString] = CaptionTiming(start: segment.start, end: segment.end, words: segment.words ?? [])
            }
            context.insert(media)
            media.timings = try JSONEncoder().encode(timing)
        }
        try context.save()
    }

    func checkpoint(_ session: ConferenceSession, duration: TimeInterval, ended: Bool) throws {
        session.duration = duration
        if ended {
            session.endedAt = Date()
            session.transcript = session.fullTranscript
        }
        try context.save()
    }

    func rename(_ session: ConferenceSession, title: String) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        session.title = clean
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    func draft(for sessionID: UUID) throws -> SessionDraft? {
        var request = FetchDescriptor<SessionDraft>(predicate: #Predicate { $0.sessionID == sessionID })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Save is a state transition: completed draft → library session, with the same identity.
    func publish(_ session: ConferenceSession) throws {
        guard let marker = try draft(for: session.id) else { return }
        context.delete(marker)
        if session.endedAt == nil { session.endedAt = Date() }
        session.transcript = session.fullTranscript
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    func favorite(for sessionID: UUID) throws -> SessionFavorite? {
        var request = FetchDescriptor<SessionFavorite>(predicate: #Predicate { $0.sessionID == sessionID })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func setFavorite(_ enabled: Bool, for session: ConferenceSession) throws {
        // Los borradores deben guardarse antes de protegerse: Discard siempre conserva su significado.
        guard try draft(for: session.id) == nil, try trash(for: session.id) == nil else { throw ReviewFailure.sessionChanged }
        if let existing = try favorite(for: session.id) {
            if !enabled { context.delete(existing) }
        } else if enabled { context.insert(SessionFavorite(sessionID: session.id)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    /// Validar en persistencia protege también llamadas futuras (por ejemplo borrado por lotes).
    private func requireUnprotected(_ sessionID: UUID) throws {
        if try favorite(for: sessionID) != nil { throw SessionProtectionFailure.protected }
    }

    func trash(for id: UUID) throws -> SessionTrash? {
        try context.fetch(FetchDescriptor<SessionTrash>(predicate: #Predicate { $0.sessionID == id })).first
    }
    /// Soft deletion is only available for completed library sessions, never active drafts.
    func moveToTrash(_ session: ConferenceSession, now: Date = Date()) throws {
        try requireUnprotected(session.id)
        guard try draft(for: session.id) == nil, session.endedAt != nil else { throw ReviewFailure.sessionChanged }
        guard try trash(for: session.id) == nil else { return }
        context.insert(SessionTrash(sessionID: session.id, deletedAt: now))
        do { try context.save() } catch { context.rollback(); throw error }
    }
    func restore(_ session: ConferenceSession) throws {
        guard let marker = try trash(for: session.id) else { return }
        context.delete(marker)
        do { try context.save() } catch { context.rollback(); throw error }
    }
    /// Expiry is applied when the app opens/returns to the foreground, not by a background timer.
    func purgeExpiredTrash(now: Date = Date()) throws {
        for marker in try context.fetch(FetchDescriptor<SessionTrash>()) where marker.expiresAt <= now {
            let id = marker.sessionID
            if let session = try context.fetch(FetchDescriptor<ConferenceSession>(predicate: #Predicate { $0.id == id })).first {
                try delete(session)
            }
        }
    }

    func delete(_ session: ConferenceSession) throws {
        try requireUnprotected(session.id)
        let identifier = session.id
        let savedTrash = try trash(for: identifier)
        let savedBookmarks = try bookmarks(for: identifier)
        let savedReview = try review(for: identifier)
        let savedMedia = try media(for: identifier)
        let savedDraft = try draft(for: identifier)
        let savedTranslation = try translation(for: identifier)
        let savedExpressions = try learningExpressions(for: identifier)
        let audioURL = try audioURL(for: identifier)
        if let audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
            try FileManager.default.removeItem(at: audioURL)
        }
        if let savedMedia { context.delete(savedMedia) }
        if let savedDraft { context.delete(savedDraft) }
        if let savedTranslation { context.delete(savedTranslation) }
        for expression in savedExpressions { context.delete(expression) }
        // Explicit deletion also covers iOS 17 stores where cascade propagation
        // can leave registered caption objects behind in the context.
        for caption in session.captions { context.delete(caption) }
        for bookmark in savedBookmarks {
            if let note = try bookmarkNote(for: bookmark.id) { context.delete(note) }
            context.delete(bookmark)
        }
        if let savedReview { context.delete(savedReview) }
        if let savedTrash { context.delete(savedTrash) }
        context.delete(session)
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
        if cacheSessionID == identifier {
            cacheSessionID = nil
            currentCaptions = [:]
            runOrder = [:]
            nextOrder = 0
        }
    }

    func bookmarks(for sessionID: UUID) throws -> [CaptionBookmark] {
        try context.fetch(FetchDescriptor<CaptionBookmark>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.createdAt)]))
    }

    func toggleBookmark(_ segment: CaptionSegment, in session: ConferenceSession) throws {
        if let existing = try bookmarks(for: session.id).first(where: { $0.segmentID == segment.id }) {
            if let note = try bookmarkNote(for: existing.id) { context.delete(note) }
            context.delete(existing)
        } else {
            context.insert(CaptionBookmark(sessionID: session.id, segment: segment))
        }
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    /// A marker points to the stable original paragraph ID, even when created from a translation.
    func toggleBookmark(paragraphID: UUID, in session: ConferenceSession) throws {
        guard let paragraph = session.captions.first(where: { $0.id == paragraphID }),
              try trash(for: session.id) == nil else { throw ReviewFailure.sessionChanged }
        let text = try reviewedParagraphs(for: session).first { $0.id == paragraphID }?.text ?? paragraph.text
        try toggleBookmark(CaptionSegment(id: paragraph.id, runID: paragraph.runID,
            start: paragraph.start, end: paragraph.end, text: text), in: session)
    }

    func bookmarkNote(for bookmarkID: UUID) throws -> BookmarkNote? {
        try context.fetch(FetchDescriptor<BookmarkNote>(predicate: #Predicate { $0.bookmarkID == bookmarkID })).first
    }

    func saveBookmarkNote(_ text: String, for bookmark: CaptionBookmark) throws {
        guard try trash(for: bookmark.sessionID) == nil,
              try bookmarks(for: bookmark.sessionID).contains(where: { $0.id == bookmark.id }) else { throw ReviewFailure.sessionChanged }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note = try bookmarkNote(for: bookmark.id) {
            if trimmed.isEmpty { context.delete(note) } else { note.text = trimmed }
        } else if !trimmed.isEmpty { context.insert(BookmarkNote(bookmarkID: bookmark.id, text: trimmed)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func removeBookmark(_ bookmark: CaptionBookmark) throws {
        if let note = try bookmarkNote(for: bookmark.id) { context.delete(note) }
        context.delete(bookmark)
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    func review(for sessionID: UUID) throws -> SessionReview? {
        var request = FetchDescriptor<SessionReview>(predicate: #Predicate { $0.sessionID == sessionID })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Guarda diferencias respecto al reconocimiento original, no reemplaza el original.
    /// Rechaza borradores cuyos IDs ya no corresponden a la sesión para evitar guardar texto obsoleto.
    func saveCorrections(_ paragraphs: [ReviewParagraph], for session: ConferenceSession) throws {
        let originals = session.orderedCaptions.map { ReviewParagraph(id: $0.id, text: $0.text) }
        guard paragraphs.map(\.id) == originals.map(\.id) else { throw ReviewFailure.sessionChanged }
        let changes = Dictionary(uniqueKeysWithValues: zip(originals, paragraphs).compactMap { original, edited in
            original.text == edited.text ? nil : (original.id.uuidString, edited.text)
        })
        let encoded = try JSONEncoder().encode(changes)
        let record = try review(for: session.id) ?? SessionReview(sessionID: session.id)
        context.insert(record)
        record.corrections = encoded
        record.updatedAt = changes.isEmpty ? nil : Date()
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    func saveReadingPosition(_ captionID: UUID, for session: ConferenceSession) throws {
        guard session.captions.contains(where: { $0.id == captionID }) else { return }
        let record = try review(for: session.id) ?? SessionReview(sessionID: session.id)
        guard record.lastReadCaptionID != captionID else { return }
        context.insert(record)
        record.lastReadCaptionID = captionID
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    func media(for sessionID: UUID) throws -> SessionMedia? {
        var request = FetchDescriptor<SessionMedia>(predicate: #Predicate { $0.sessionID == sessionID })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Acepta únicamente el nombre esperado para la sesión; no interpreta rutas arbitrarias guardadas.
    func audioURL(for sessionID: UUID) throws -> URL? {
        guard let name = try media(for: sessionID)?.audioName,
              name == sessionID.uuidString + ".caf" else { return nil }
        return try audioDirectory().appendingPathComponent(name)
    }

    private func audioDirectory() throws -> URL {
        var folder = (storageURL?.deletingLastPathComponent() ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        return folder
    }

    func prepareRecording(for session: ConferenceSession) throws -> URL {
        let record = try media(for: session.id) ?? SessionMedia(sessionID: session.id)
        let name = session.id.uuidString + ".caf"
        let url = try audioDirectory().appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else { throw RecordingFailure.unavailable }
        context.insert(record)
        record.audioName = name
        try context.save()
        return url
    }

    /// Elimina el archivo y su referencia; conserva transcripción, correcciones y tiempos de subtítulos.
    func deleteAudio(for sessionID: UUID) throws {
        try requireUnprotected(sessionID)
        guard let record = try media(for: sessionID) else { return }
        if let url = try audioURL(for: sessionID), FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        record.audioName = nil
        try context.save()
    }

    func learningExpressions(for sessionID: UUID) throws -> [LearningExpression] {
        try context.fetch(FetchDescriptor<LearningExpression>(
            predicate: #Predicate { $0.sessionID == sessionID }, sortBy: [SortDescriptor(\.createdAt)]))
    }

    /// Validación antes de mutar: no aceptar expresiones ajenas a su contexto ni borradores activos.
    func saveLearningExpression(unit: LearningUnit, english: String, spanish: String,
                                for session: ConferenceSession) throws {
        let text = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard try draft(for: session.id) == nil, !text.isEmpty, text.count <= 500,
              unit.english.localizedStandardContains(text),
              try reviewedParagraphs(for: session).contains(where: { $0.id == unit.paragraphID && $0.text == unit.context })
        else { throw ReviewFailure.sessionChanged }
        guard !(try learningExpressions(for: session.id)).contains(where: {
            $0.paragraphID == unit.paragraphID && $0.english == text && $0.context == unit.context
        }) else { return }
        context.insert(LearningExpression(sessionID: session.id, unit: unit, english: text,
            spanish: String(spanish.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))))
        do { try context.save() } catch { context.rollback(); throw error }
    }
    func removeLearningExpression(_ expression: LearningExpression) throws {
        context.delete(expression)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func translation(for sessionID: UUID) throws -> SessionTranslation? {
        var request = FetchDescriptor<SessionTranslation>(predicate: #Predicate { $0.sessionID == sessionID })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func reviewedParagraphs(for session: ConferenceSession) throws -> [ReviewParagraph] {
        let originals = session.orderedCaptions.map { ReviewParagraph(id: $0.id, text: $0.text) }
        return TranscriptReview.paragraphs(originals: originals,
            corrections: try review(for: session.id)?.decodedCorrections() ?? [:])
    }

    /// Guarda el lote completo de forma atómica. Nunca publica resultados parciales ni obsoletos.
    func saveTranslation(_ snapshot: TranslationSnapshot, for session: ConferenceSession, allowCompletedDraft: Bool = false) throws {
        try snapshot.validate()
        guard try trash(for: session.id) == nil else { throw ReviewFailure.sessionChanged }
        let identifier = session.id
        var request = FetchDescriptor<ConferenceSession>(predicate: #Predicate { $0.id == identifier })
        request.fetchLimit = 1
        guard try context.fetch(request).first != nil else { throw TranslationFailure.sourceChanged }
        guard try draft(for: session.id) == nil || (allowCompletedDraft && session.endedAt != nil),
              snapshot.language.rawValue == session.language,
              snapshot.isCurrent(try reviewedParagraphs(for: session)) else { throw TranslationFailure.sourceChanged }
        let encoded = try JSONEncoder().encode(snapshot)
        let record = try translation(for: session.id) ?? SessionTranslation(sessionID: session.id, payload: encoded)
        context.insert(record)
        record.payload = encoded
        do { try context.save() } catch { context.rollback(); cacheSessionID = nil; throw error }
    }

    func save() throws { try context.save() }
}
