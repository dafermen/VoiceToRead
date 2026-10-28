import XCTest
import UIKit
import CryptoKit
@testable import VoiceToRead

@MainActor
final class StoryTests: XCTestCase {
    func testExampleCoversAreBundledAndFollowStableIdentityWithoutEditingStories() throws {
        var hashes = Set<Data>()
        for entry in StoryExampleCatalog.entries {
            let story = try entry.document()
            let name = try XCTUnwrap(StoryExampleCatalog.coverName(for: story))
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "StoryCovers"))
            let data = try Data(contentsOf: url)
            let image = try XCTUnwrap(UIImage(data: data))
            XCTAssertEqual(image.size.width / image.size.height, 16.0 / 9.0, accuracy: 0.025)
            XCTAssertTrue(hashes.insert(Data(SHA256.hash(data: data))).inserted)
            var renamed = story; renamed.title = "My edited title"
            XCTAssertEqual(StoryExampleCatalog.coverName(for: renamed), name)
            var legacy = story; legacy.id = UUID(); legacy.title = entry.aliases.first ?? entry.title
            XCTAssertEqual(StoryExampleCatalog.coverName(for: legacy), name)
        }
        XCTAssertEqual(hashes.count, 20)
        let custom = try StoryDocument.edited(title: "A different story", text: "My own text.", source: .english, target: .spanish)
        XCTAssertNil(StoryExampleCatalog.coverName(for: custom))
    }

    func testStoriesUseIndependentStorageAndSeedOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StoryStore(directory: directory)
        XCTAssertEqual(store.stories.count, 20)
        XCTAssertEqual(store.stories.first?.title, "Caperucita Roja")
        XCTAssertFalse(try XCTUnwrap(store.stories.first).translatedReady)
        let sibling = directory.appendingPathComponent("trainings.json")
        try Data("existing training".utf8).write(to: sibling)
        let story = try StoryDocument.edited(title: "My story", text: "Hola\nGracias", source: .spanish, target: .english)
        try store.save(story)
        XCTAssertEqual(try StoryStore(directory: directory).stories, store.stories)
        try store.delete(story)
        XCTAssertEqual(try Data(contentsOf: sibling), Data("existing training".utf8))
        XCTAssertEqual(try StoryStore(directory: directory).stories.count, 20)
    }

    func testCatalogIsValidAndDeletedExamplesStayDeleted() throws {
        XCTAssertEqual(StoryExampleCatalog.entries.count, 20)
        XCTAssertEqual(Set(StoryExampleCatalog.entries.map(\.id)).count, 20)
        for entry in StoryExampleCatalog.entries {
            let story = try entry.document()
            XCTAssertTrue(story.valid)
            XCTAssertEqual(story.id, entry.id)
            XCTAssertGreaterThan(story.paragraphs.count, 10)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StoryStore(directory: directory)
        let deleted = try XCTUnwrap(store.stories.first)
        try store.delete(deleted)
        let reopened = try StoryStore(directory: directory)
        XCTAssertEqual(reopened.stories.count, 19)
        XCTAssertNil(reopened.story(deleted.id))
    }

    func testElevenStoryArchiveAddsNewExamplesOnceWithoutRestoringDeletedExamples() throws {
        struct PriorArchive: Codable { var version = 1; var stories: [StoryDocument]; var installedExamples: [UUID] }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let previous = Array(StoryExampleCatalog.entries.prefix(11))
        var retained = try previous.dropFirst().map { try $0.document() }
        retained[0].title = "My edited Rapunzel"
        let file = directory.appendingPathComponent("stories.json")
        try JSONEncoder().encode(PriorArchive(stories: retained, installedExamples: previous.map(\.id))).write(to: file)
        let store = try StoryStore(directory: directory)
        XCTAssertEqual(store.stories.count, 19)
        XCTAssertNil(store.story(previous[0].id), "An intentionally deleted story must stay deleted")
        for story in retained { XCTAssertEqual(store.story(story.id), story) }
        XCTAssertEqual(try StoryStore(directory: directory).stories, store.stories)
    }

    func testOldLibraryKeepsCorrectedStoriesAndAddsCatalogOnlyOnce() throws {
        struct OldArchive: Codable { var version = 1; var stories: [StoryDocument] }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var pigs = try StoryDocument.edited(title: "Los tres cerditos", text: "Mi versión corregida.", source: .spanish, target: .english)
        let translated = pigs.paragraphs.map { ReviewParagraph(id: $0.id, text: "My corrected version.") }
        var snapshot = TranslationSnapshot(source: pigs.paragraphs, generated: translated)
        snapshot.sourceLocale = CaptureLanguage.spanish.rawValue
        snapshot.targetLocale = CaptureLanguage.english.rawValue
        pigs.translation = snapshot; pigs.translationReviewed = true
        let custom = try StoryDocument.edited(title: "Mi cuento", text: "Un texto propio.", source: .spanish, target: .french)
        let file = directory.appendingPathComponent("stories.json")
        try JSONEncoder().encode(OldArchive(stories: [pigs, custom])).write(to: file)
        let store = try StoryStore(directory: directory)
        XCTAssertEqual(store.stories.count, 21)
        XCTAssertEqual(store.story(pigs.id), pigs)
        XCTAssertEqual(store.story(custom.id), custom)
        XCTAssertTrue(try XCTUnwrap(store.story(pigs.id)).translatedReady)
        XCTAssertEqual(store.stories.filter { $0.title == pigs.title }.count, 1)
        XCTAssertEqual(try StoryStore(directory: directory).stories, store.stories)
    }

    func testTranslationNeedsReviewAndSourceChangesInvalidateOnlyThisStory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StoryStore(directory: directory)
        let story = try StoryDocument.edited(title: "My story", text: "Hola\nGracias", source: .spanish, target: .english)
        try store.save(story)
        let replies = zip(story.paragraphs, ["Hello", "Thank you"]).map { ReviewParagraph(id: $0.0.id, text: $0.1) }
        XCTAssertThrowsError(try store.acceptTranslation(story, responses: Array(replies.reversed())))
        try store.acceptTranslation(story, responses: replies)
        let generated = try XCTUnwrap(store.story(story.id))
        XCTAssertFalse(generated.translatedReady)
        let corrected = Dictionary(uniqueKeysWithValues: zip(story.paragraphs, ["Hello!", "Thanks!"]).map { ($0.0.id, $0.1) })
        try store.review(generated, corrections: corrected)
        let reviewed = try XCTUnwrap(store.story(story.id))
        XCTAssertTrue(reviewed.translatedReady)
        XCTAssertEqual(reviewed.translatedText, "Hello!\n\nThanks!")
        let renamed = try StoryDocument.edited(title: "Renamed", text: reviewed.sourceText, source: .spanish, target: .english, previous: reviewed)
        XCTAssertEqual(renamed.translation, reviewed.translation)
        XCTAssertTrue(renamed.translatedReady)
        let edited = try StoryDocument.edited(title: "Renamed", text: "Nuevo cuento", source: .spanish, target: .english, previous: reviewed)
        XCTAssertEqual(edited.id, reviewed.id)
        XCTAssertNil(edited.translation)
        XCTAssertFalse(edited.translatedReady)
        try store.save(edited, replacing: reviewed)
        XCTAssertThrowsError(try store.acceptTranslation(reviewed, responses: replies))
        XCTAssertEqual(store.story(story.id), edited)
    }

    func testTargetReplacementIsAtomicAndNeedsNewApproval() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StoryStore(directory: directory)
        let original = try StoryDocument.edited(title: "Target change", text: "Hola", source: .spanish, target: .english)
        try store.save(original)
        let english = original.paragraphs.map { ReviewParagraph(id: $0.id, text: "Hello") }
        try store.acceptTranslation(original, responses: english)
        let generated = try XCTUnwrap(store.story(original.id))
        try store.review(generated, corrections: [original.paragraphs[0].id: "Hello!"])
        let approved = try XCTUnwrap(store.story(original.id))
        XCTAssertThrowsError(try store.acceptTranslation(approved, responses: [], target: .french))
        XCTAssertEqual(store.story(original.id), approved)
        XCTAssertThrowsError(try store.acceptTranslation(approved, responses: english, target: .spanish))
        XCTAssertEqual(try StoryStore(directory: directory).story(original.id), approved)
        let french = original.paragraphs.map { ReviewParagraph(id: $0.id, text: "Bonjour") }
        try store.acceptTranslation(approved, responses: french, target: .french)
        let replacement = try XCTUnwrap(store.story(original.id))
        XCTAssertEqual(replacement.sourceText, original.sourceText)
        XCTAssertEqual(replacement.targetLanguage, .french)
        XCTAssertEqual(replacement.translation?.target, .french)
        XCTAssertFalse(replacement.translatedReady)
        XCTAssertEqual(replacement.translatedText, "Bonjour")
        XCTAssertEqual(try StoryStore(directory: directory).story(original.id), replacement)
    }

    func testTranslationsSurviveSwitchingReopeningAndSingleLanguageReplacement() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StoryStore(directory: directory)
        let original = try StoryDocument.edited(title: "Multilingual", text: "Hola", source: .spanish, target: .english)
        try store.save(original)
        let id = original.id, paragraphID = original.paragraphs[0].id
        try store.acceptTranslation(original, responses: [ReviewParagraph(id: paragraphID, text: "Hello")])
        try store.review(XCTUnwrap(store.story(id)), corrections: [paragraphID: "Hello, friend!"])
        let english = try XCTUnwrap(store.story(id))
        // Legacy archives contain only the active translation, without a cache field.
        let encoded = try JSONEncoder().encode(english)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "savedTranslations")
        let legacy = try JSONDecoder().decode(StoryDocument.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.translation, english.translation)
        try store.save(legacy, replacing: english)
        try store.selectTarget(legacy, target: .french)
        let pendingFrench = try XCTUnwrap(store.story(id))
        XCTAssertNil(pendingFrench.translation)
        XCTAssertFalse(pendingFrench.translatedReady)
        try store.acceptTranslation(pendingFrench, responses: [ReviewParagraph(id: paragraphID, text: "Bonjour")])
        let french = try XCTUnwrap(store.story(id))
        XCTAssertFalse(french.translatedReady)
        try store.selectTarget(french, target: .english)
        let restored = try XCTUnwrap(store.story(id))
        XCTAssertTrue(restored.translatedReady)
        XCTAssertEqual(restored.translation, english.translation)
        XCTAssertEqual(restored.translatedText, "Hello, friend!")
        let reopened = try StoryStore(directory: directory)
        try reopened.selectTarget(XCTUnwrap(reopened.story(id)), target: .french)
        XCTAssertEqual(reopened.story(id)?.translation, french.translation)
        XCTAssertFalse(try XCTUnwrap(reopened.story(id)).translatedReady)
        try reopened.acceptTranslation(XCTUnwrap(reopened.story(id)), responses: [ReviewParagraph(id: paragraphID, text: "Salut")])
        try reopened.selectTarget(XCTUnwrap(reopened.story(id)), target: .english)
        let kept = try XCTUnwrap(reopened.story(id))
        XCTAssertEqual(kept.translation, english.translation)
        XCTAssertTrue(kept.translatedReady)
        let renamed = try StoryDocument.edited(title: "Renamed", text: kept.sourceText, source: .spanish, target: .french, previous: kept)
        XCTAssertEqual(renamed.translatedText, "Salut")
        XCTAssertTrue(renamed.hasTranslations)
        let edited = try StoryDocument.edited(title: kept.title, text: "Otro texto", source: .spanish, target: .english, previous: kept)
        XCTAssertFalse(edited.hasTranslations)
        XCTAssertNil(edited.savedTranslations)
    }

    func testCorruptStoryArchiveIsPreservedAndInvalidInputCannotBeSaved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("stories.json"), data = Data("broken archive".utf8)
        try data.write(to: file)
        XCTAssertThrowsError(try StoryStore(directory: directory))
        XCTAssertEqual(try Data(contentsOf: file), data)
        XCTAssertThrowsError(try StoryDocument.edited(title: "", text: "Hello", source: .english, target: .spanish))
        XCTAssertThrowsError(try StoryDocument.edited(title: "Story", text: "Hello", source: .english, target: .english))
        XCTAssertThrowsError(try StoryDocument.edited(title: "Story", text: String(repeating: "a", count: 1_001), source: .english, target: .spanish))
    }

    func testNarrationPauseStopAndLateWordsNeverAffectTheNextStory() throws {
        let output = StoryTestOutput()
        var releases = 0
        let narrator = StoryNarrator(output: output, activate: {}, deactivate: { releases += 1 })
        narrator.start(text: "Hola 👋 mundo", language: .spanish, slow: true)
        let first = try XCTUnwrap(output.token)
        XCTAssertEqual(output.language, .spanish)
        XCTAssertTrue(output.slow)
        output.onWord?(NSRange(location: 0, length: 4), first)
        XCTAssertEqual(narrator.progress.range?.length, 4)
        narrator.togglePause()
        XCTAssertEqual(narrator.state, .paused)
        output.onWord?(NSRange(location: 5, length: 2), first)
        XCTAssertEqual(narrator.progress.range?.location, 0)
        narrator.togglePause()
        XCTAssertEqual(narrator.state, .playing)
        narrator.stop()
        XCTAssertNil(narrator.progress.range)
        XCTAssertEqual(releases, 1)
        narrator.start(text: "The next story", language: .english, slow: false)
        let next = try XCTUnwrap(output.token)
        output.onWord?(NSRange(location: 0, length: 4), first)
        output.onFinish?(first)
        XCTAssertEqual(narrator.state, .playing)
        XCTAssertNil(narrator.progress.range)
        output.onWord?(NSRange(location: 4, length: 4), next)
        XCTAssertEqual(narrator.progress.range?.location, 4)
        output.onFinish?(next)
        XCTAssertEqual(narrator.state, .idle)
        XCTAssertNil(narrator.progress.range)
        XCTAssertEqual(releases, 2)
    }
}

@MainActor
private final class StoryTestOutput: StorySpeechOutput {
    var onWord: ((NSRange, UUID) -> Void)?
    var onFinish: ((UUID) -> Void)?
    var token: UUID?
    var language: CaptureLanguage?
    var slow = false
    func speak(_ text: String, language: CaptureLanguage, slow: Bool, token: UUID) throws {
        self.token = token; self.language = language; self.slow = slow
    }
    func pause() -> Bool { true }
    func resume() -> Bool { true }
    func stop() { }
}
