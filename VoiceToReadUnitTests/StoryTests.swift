import XCTest
@testable import VoiceToRead

@MainActor
final class StoryTests: XCTestCase {
    func testStoriesUseIndependentStorageAndSeedOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try StoryStore(directory: directory)
        XCTAssertEqual(store.stories.count, 1)
        XCTAssertEqual(store.stories.first?.title, "Los tres cerditos")
        XCTAssertFalse(try XCTUnwrap(store.stories.first).translatedReady)
        let sibling = directory.appendingPathComponent("trainings.json")
        try Data("existing training".utf8).write(to: sibling)
        let story = try StoryDocument.edited(title: "My story", text: "Hola\nGracias", source: .spanish, target: .english)
        try store.save(story)
        XCTAssertEqual(try StoryStore(directory: directory).stories, store.stories)
        try store.delete(story)
        XCTAssertEqual(try Data(contentsOf: sibling), Data("existing training".utf8))
        XCTAssertEqual(try StoryStore(directory: directory).stories.count, 1)
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
