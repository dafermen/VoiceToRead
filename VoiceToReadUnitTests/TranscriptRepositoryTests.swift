import XCTest
import SwiftData
@testable import VoiceToRead

@MainActor
final class TranscriptRepositoryTests: XCTestCase {
    func testV9MigrationBookmarkNotesPersistAndDeleteWithMarker() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ids = try autoreleasepool { () throws -> (UUID, UUID) in
            let schema = Schema(versionedSchema: SessionSchemaV9.self)
            let config = ModelConfiguration("Sessions", schema: schema, url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Before notes")
            let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Keep original")
            container.mainContext.insert(session)
            let caption = StoredCaption(segment: segment, order: 0)
            container.mainContext.insert(caption); session.captions.append(caption)
            let bookmark = CaptionBookmark(sessionID: session.id, segment: segment)
            container.mainContext.insert(bookmark)
            try container.mainContext.save()
            return (session.id, bookmark.id)
        }
        try autoreleasepool {
            let repo = try TranscriptRepository(directory: directory)
            let bookmark = try XCTUnwrap(repo.bookmarks(for: ids.0).first)
            XCTAssertEqual(bookmark.id, ids.1)
            try repo.saveBookmarkNote("  Practice this phrase  ", for: bookmark)
        }
        let repo = try TranscriptRepository(directory: directory)
        let bookmark = try XCTUnwrap(repo.bookmarks(for: ids.0).first)
        XCTAssertEqual(try repo.bookmarkNote(for: ids.1)?.text, "Practice this phrase")
        XCTAssertEqual(bookmark.text, "Keep original")
        try repo.saveBookmarkNote(" ", for: bookmark)
        XCTAssertNil(try repo.bookmarkNote(for: ids.1))
        try repo.saveBookmarkNote("New note", for: bookmark)
        try repo.removeBookmark(bookmark)
        XCTAssertNil(try repo.bookmarkNote(for: ids.1))
        XCTAssertTrue(try repo.bookmarks(for: ids.0).isEmpty)
        XCTAssertEqual(try repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first?.fullTranscript, "Keep original")
    }

    func testBookmarkFromSavedOrTranslatedParagraphUsesSameIDAndSurvivesReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try autoreleasepool { () throws -> UUID in
            let repo = try TranscriptRepository(directory: directory)
            let session = try repo.create(title: "Bookmark")
            let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Wrong word")
            try repo.apply(.init(removedIDs: [], upserted: [segment]), to: session)
            try repo.checkpoint(session, duration: 1, ended: true)
            let corrected = [ReviewParagraph(id: segment.id, text: "Correct word")]
            try repo.saveCorrections(corrected, for: session)
            try repo.saveTranslation(TranslationSnapshot(source: corrected, generated: [.init(id: segment.id, text: "Palabra correcta")]), for: session)
            try repo.toggleBookmark(paragraphID: segment.id, in: session)
            XCTAssertEqual(try repo.bookmarks(for: session.id).first?.text, "Correct word")
            return session.id
        }
        let repo = try TranscriptRepository(directory: directory)
        let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first { $0.id == id })
        let marker = try XCTUnwrap(repo.bookmarks(for: id).first)
        XCTAssertEqual(marker.segmentID, session.captions.first?.id)
        try repo.toggleBookmark(paragraphID: marker.segmentID, in: session)
        XCTAssertTrue(try repo.bookmarks(for: id).isEmpty)
        XCTAssertThrowsError(try repo.toggleBookmark(paragraphID: UUID(), in: session))
    }

    func testV8MigrationTrashRestoreAndExpiryPreserveOriginalData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Trash-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV8.self)
            let config = ModelConfiguration("Sessions", schema: schema, url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Keep everything")
            session.endedAt = Date()
            container.mainContext.insert(session)
            let caption = StoredCaption(segment: CaptionSegment(runID: UUID(), start: 0, end: 2, text: "Original"), order: 0)
            container.mainContext.insert(caption); session.captions.append(caption)
            try container.mainContext.save()
            return session.id
        }
        let now = Date()
        try autoreleasepool {
            let repo = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            XCTAssertEqual(session.id, id)
            let original = try repo.reviewedParagraphs(for: session)
            try repo.saveTranslation(TranslationSnapshot(source: original, generated: original.map { .init(id: $0.id, text: "Traducido") }), for: session)
            let audio = try repo.prepareRecording(for: session)
            try Data("recording".utf8).write(to: audio)
            try repo.setFavorite(true, for: session)
            XCTAssertThrowsError(try repo.moveToTrash(session))
            try repo.setFavorite(false, for: session)
            try repo.moveToTrash(session, now: now)
            XCTAssertNotNil(try repo.trash(for: id))
            XCTAssertThrowsError(try repo.setFavorite(true, for: session))
            XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
        }
        try autoreleasepool {
            let repo = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            let audio = try XCTUnwrap(repo.audioURL(for: id))
            XCTAssertNotNil(try repo.trash(for: id))
            try repo.restore(session)
            XCTAssertNil(try repo.trash(for: id))
            XCTAssertEqual(try repo.translation(for: id)?.decoded().translated.first?.text, "Traducido")
            XCTAssertEqual(try Data(contentsOf: audio), Data("recording".utf8))
            try repo.moveToTrash(session, now: now)
            try repo.moveToTrash(session, now: now.addingTimeInterval(100))
            XCTAssertEqual(try repo.trash(for: id)?.deletedAt, now, "Repeated removal must not extend retention")
            try repo.purgeExpiredTrash(now: now.addingTimeInterval(29 * 86400))
            XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
            try repo.purgeExpiredTrash(now: now.addingTimeInterval(30 * 86400))
            XCTAssertTrue(try repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).isEmpty)
            XCTAssertNil(try repo.trash(for: id)); XCTAssertNil(try repo.translation(for: id))
            XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
        }
    }

    func testTrashRefusesDraftAndLateTranslation() throws {
        let repo = try TranscriptRepository(inMemory: true)
        let draft = try repo.create(title: "Draft", draft: true)
        XCTAssertThrowsError(try repo.moveToTrash(draft))
        let session = try repo.create(title: "Finished")
        let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Hello")
        try repo.apply(.init(removedIDs: [], upserted: [segment]), to: session)
        try repo.checkpoint(session, duration: 1, ended: true)
        let source = try repo.reviewedParagraphs(for: session)
        try repo.moveToTrash(session)
        XCTAssertThrowsError(try repo.saveTranslation(TranslationSnapshot(source: source, generated: source), for: session))
        try repo.restore(session)
        XCTAssertNoThrow(try repo.saveTranslation(TranslationSnapshot(source: source, generated: source), for: session))
    }

    func testV7MigrationFavoriteProtectionAndExplicitRemovalSurviveReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Favorites-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV7.self)
            let config = ModelConfiguration("Sessions", schema: schema,
                url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Keep this meeting")
            container.mainContext.insert(session)
            let caption = StoredCaption(segment: CaptionSegment(runID: UUID(), start: 0, end: 2, text: "Keep my words"), order: 0)
            container.mainContext.insert(caption); session.captions.append(caption)
            let review = SessionReview(sessionID: session.id)
            review.corrections = try JSONEncoder().encode([caption.id.uuidString: "Keep my corrected words"])
            container.mainContext.insert(review)
            try container.mainContext.save()
            return session.id
        }
        try autoreleasepool {
            let repo = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            XCTAssertEqual(session.id, id)
            XCTAssertEqual(try repo.reviewedParagraphs(for: session).first?.text, "Keep my corrected words")
            XCTAssertNil(try repo.favorite(for: id))
            let url = try repo.prepareRecording(for: session)
            try Data("audio must survive".utf8).write(to: url)
            try repo.setFavorite(true, for: session)
            try repo.setFavorite(true, for: session)
            XCTAssertEqual(try repo.container.mainContext.fetch(FetchDescriptor<SessionFavorite>()).count, 1)
        }
        try autoreleasepool {
            let repo = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            let url = try XCTUnwrap(repo.audioURL(for: id))
            XCTAssertNotNil(try repo.favorite(for: id))
            XCTAssertThrowsError(try repo.deleteAudio(for: id)) { XCTAssertTrue($0 is SessionProtectionFailure) }
            XCTAssertThrowsError(try repo.delete(session)) { XCTAssertTrue($0 is SessionProtectionFailure) }
            XCTAssertEqual(try Data(contentsOf: url), Data("audio must survive".utf8))
            XCTAssertEqual(session.fullTranscript, "Keep my words")
            try repo.setFavorite(false, for: session)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Unprotecting must never delete data")
        }
        try autoreleasepool {
            let repo = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            XCTAssertNil(try repo.favorite(for: id))
            let url = try XCTUnwrap(repo.audioURL(for: id))
            try repo.delete(session)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            XCTAssertTrue(try repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).isEmpty)
            XCTAssertNil(try repo.review(for: id))
        }
    }

    func testRecoveryDraftCannotBeProtectedBeforePublishing() throws {
        let repo = try TranscriptRepository(inMemory: true)
        let session = try repo.create(title: "Draft", draft: true)
        XCTAssertThrowsError(try repo.setFavorite(true, for: session))
        try repo.publish(session)
        try repo.setFavorite(true, for: session)
        XCTAssertThrowsError(try repo.delete(session))
    }

    func testV4MigrationAndDraftRecoveryPublishAndAudioDiscard() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DraftMigration-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let oldID = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV4.self)
            let config = ModelConfiguration("Sessions", schema: schema,
                url: folder.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let old = ConferenceSession(title: "Existing library session")
            container.mainContext.insert(old)
            try container.mainContext.save()
            return old.id
        }
        let draftID = try autoreleasepool { () throws -> UUID in
            let repository = try TranscriptRepository(directory: folder)
            XCTAssertNil(try repository.draft(for: oldID))
            let draft = try repository.create(title: "Recover me", draft: true)
            let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Retain my words")
            try repository.apply(.init(removedIDs: [], upserted: [segment]), to: draft)
            let audio = try repository.prepareRecording(for: draft)
            try Data([1, 2, 3]).write(to: audio)
            return draft.id
        }
        try autoreleasepool {
            let repository = try TranscriptRepository(directory: folder)
            let sessions = try repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>())
            let recovered = try XCTUnwrap(sessions.first { $0.id == draftID })
            XCTAssertEqual(recovered.fullTranscript, "Retain my words")
            XCTAssertNotNil(try repository.draft(for: draftID))
            let audio = try XCTUnwrap(repository.audioURL(for: draftID))
            XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
            try repository.publish(recovered)
            XCTAssertNil(try repository.draft(for: draftID))
            XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
            try repository.delete(recovered)
            XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
            XCTAssertNil(try repository.media(for: draftID))
            XCTAssertEqual(try repository.container.mainContext.fetchCount(FetchDescriptor<ConferenceSession>()), 1)
            let draft = try repository.create(title: "Discard me", draft: true)
            let id = draft.id
            try repository.delete(draft)
            XCTAssertNil(try repository.draft(for: id))
        }
    }

    func testOutOfOrderFinalResultsAreStoredInAudioOrder() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let session = try repository.create(title: "Ordering")
        let run = UUID()
        try repository.apply(.init(removedIDs: [], upserted: [
            CaptionSegment(runID: run, start: 2, end: 3, text: "Second")
        ]), to: session)
        try repository.apply(.init(removedIDs: [], upserted: [
            CaptionSegment(runID: run, start: 0, end: 1, text: "First")
        ]), to: session)
        XCTAssertEqual(session.fullTranscript, "First\nSecond")
    }

    func testFinalCaptionsSurviveStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceToReadTests-\(UUID().uuidString)", isDirectory: true)
        // SwiftData can retain SQLite handles beyond an autoreleasepool on iOS 17.
        // Leave this unique temporary store for OS cleanup instead of unlinking an open database.
        let identifier: UUID = try autoreleasepool {
            let repository = try TranscriptRepository(directory: directory)
            let session = try repository.create(title: "Persisted")
            try repository.apply(.init(removedIDs: [], upserted: [
                CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Recovered")
            ]), to: session)
            return session.id
        }
        try autoreleasepool {
            let reopened = try TranscriptRepository(directory: directory)
            let sessions = try reopened.container.mainContext.fetch(FetchDescriptor<ConferenceSession>())
            let session = try XCTUnwrap(sessions.first { $0.id == identifier })
            XCTAssertEqual(session.fullTranscript, "Recovered")
            XCTAssertNil(session.endedAt)
        }
    }
    func testV1StoreMigratesWithoutLosingSessionsAndBookmarksPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Migration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let identifier = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV1.self)
            let config = ModelConfiguration("Sessions", schema: schema,
                url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Before update")
            let caption = StoredCaption(segment: CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Keep my words"), order: 0)
            container.mainContext.insert(session)
            container.mainContext.insert(caption)
            session.captions.append(caption)
            try container.mainContext.save()
            return session.id
        }
        try autoreleasepool {
            let repository = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            XCTAssertEqual(session.id, identifier)
            XCTAssertEqual(session.fullTranscript, "Keep my words")
            let stored = try XCTUnwrap(session.captions.first)
            let segment = CaptionSegment(id: stored.id, runID: stored.runID, start: stored.start, end: stored.end, text: stored.text)
            try repository.toggleBookmark(segment, in: session)
            let revision = CaptionSegment(id: stored.id, runID: stored.runID, start: 0, end: 2, text: "Revised words")
            try repository.apply(.init(removedIDs: [], upserted: [revision]), to: session)
            XCTAssertEqual(try repository.bookmarks(for: identifier).first?.text, "Keep my words")
        }
        try autoreleasepool {
            let repository = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            XCTAssertEqual(session.fullTranscript, "Revised words")
            XCTAssertEqual(try repository.bookmarks(for: identifier).count, 1)
            try repository.delete(session)
            XCTAssertTrue(try repository.bookmarks(for: identifier).isEmpty)
        }
    }

    func testIdempotentUpsertRenameAndCascadeDelete() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let session = try repository.create(title: "Training")
        let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Hello")
        let change = FinalizedChange(removedIDs: [], upserted: [segment])
        try repository.apply(change, to: session)
        try repository.apply(change, to: session)
        XCTAssertEqual(session.captions.count, 1)
        try repository.rename(session, title: "  Meeting  ")
        XCTAssertEqual(session.title, "Meeting")
        try repository.checkpoint(session, duration: 10, ended: true)
        XCTAssertEqual(session.transcript, "Hello")
        XCTAssertNotNil(session.endedAt)
        try repository.delete(session)
        XCTAssertEqual(try repository.container.mainContext.fetchCount(FetchDescriptor<StoredCaption>()), 0)
    }
    func testV2MigrationPreservesOriginalsBookmarksCorrectionsAndReadingPosition() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReviewMigration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let identifiers = try autoreleasepool { () throws -> (UUID, UUID) in
            let schema = Schema(versionedSchema: SessionSchemaV2.self)
            let configuration = ModelConfiguration("Sessions", schema: schema,
                url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let session = ConferenceSession(title: "Existing session")
            let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Acmee original")
            let caption = StoredCaption(segment: segment, order: 0)
            container.mainContext.insert(session)
            container.mainContext.insert(caption)
            session.captions.append(caption)
            container.mainContext.insert(CaptionBookmark(sessionID: session.id, segment: segment))
            try container.mainContext.save()
            return (session.id, caption.id)
        }
        try autoreleasepool {
            let repository = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            XCTAssertEqual(session.id, identifiers.0)
            XCTAssertEqual(session.fullTranscript, "Acmee original")
            XCTAssertEqual(try repository.bookmarks(for: session.id).count, 1)
            try repository.saveCorrections([ReviewParagraph(id: identifiers.1, text: "Acme corrected\nSecond line")], for: session)
            try repository.saveReadingPosition(identifiers.1, for: session)
        }
        try autoreleasepool {
            let repository = try TranscriptRepository(directory: directory)
            let session = try XCTUnwrap(repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
            let review = try XCTUnwrap(repository.review(for: session.id))
            XCTAssertEqual(try review.decodedCorrections()[identifiers.1.uuidString], "Acme corrected\nSecond line")
            XCTAssertEqual(review.lastReadCaptionID, identifiers.1)
            XCTAssertEqual(session.fullTranscript, "Acmee original")
            XCTAssertEqual(try repository.bookmarks(for: session.id).first?.text, "Acmee original")
            try repository.saveCorrections([ReviewParagraph(id: identifiers.1, text: "Acmee original")], for: session)
            XCTAssertTrue(try review.decodedCorrections().isEmpty)
            XCTAssertEqual(review.lastReadCaptionID, identifiers.1)
            try repository.delete(session)
            XCTAssertNil(try repository.review(for: identifiers.0))
            XCTAssertTrue(try repository.bookmarks(for: identifiers.0).isEmpty)
        }
    }

    func testStaleEditorCannotReplaceADifferentTranscript() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let session = try repository.create(title: "Safe edits")
        let segment = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Original")
        try repository.apply(.init(removedIDs: [], upserted: [segment]), to: session)
        try repository.saveCorrections([ReviewParagraph(id: segment.id, text: "Corrected")], for: session)
        XCTAssertThrowsError(try repository.saveCorrections([ReviewParagraph(id: UUID(), text: "Wrong session")], for: session))
        XCTAssertEqual(try repository.review(for: session.id)?.decodedCorrections()[segment.id.uuidString], "Corrected")
        XCTAssertEqual(session.fullTranscript, "Original")
    }

}
