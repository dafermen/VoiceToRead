import Foundation
import Observation

struct StoryDocument: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var sourceLanguage: CaptureLanguage
    var targetLanguage: CaptureLanguage
    var paragraphs: [ReviewParagraph]
    var translation: TranslationSnapshot?
    var translationReviewed = false
    var updatedAt = Date()
    var sourceText: String { paragraphs.map(\.text).joined(separator: "\n\n") }
    var translatedText: String { translation?.translated.map(\.text).joined(separator: "\n\n") ?? "" }
    var translatedReady: Bool { translationReviewed && translation?.isCurrent(paragraphs) == true }
    var valid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 100,
              sourceLanguage != targetLanguage, !paragraphs.isEmpty, paragraphs.count <= 200,
              sourceText.count <= 20_000, Set(paragraphs.map(\.id)).count == paragraphs.count,
              paragraphs.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 1_000 }) else { return false }
        if let translation {
            guard translation.language == sourceLanguage, translation.target == targetLanguage,
                  translation.isCurrent(paragraphs),
                  translation.translated.allSatisfy({ $0.text.count <= 2_000 }) else { return false }
            do { try translation.validate() } catch { return false }
        } else if translationReviewed { return false }
        return true
    }
    static func edited(title: String, text: String, source: CaptureLanguage, target: CaptureLanguage,
                       previous: Self? = nil) throws -> Self {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var result = previous ?? Self(title: title, sourceLanguage: source, targetLanguage: target, paragraphs: [])
        let changed = previous.map { $0.paragraphs.map(\.text) != lines || $0.sourceLanguage != source || $0.targetLanguage != target } ?? true
        if changed {
            result.paragraphs = lines.map { ReviewParagraph(id: UUID(), text: $0) }
            result.translation = nil; result.translationReviewed = false
        }
        result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result.sourceLanguage = source; result.targetLanguage = target; result.updatedAt = Date()
        guard result.valid else { throw StoryFailure.invalid }
        return result
    }
}

enum StoryFailure: LocalizedError {
    case invalid, changed, unreadable
    var errorDescription: String? {
        switch self {
        case .invalid: "Use a title of up to 100 characters and a story of up to 20,000 characters, with different source and translation languages. Each paragraph can have up to 1,000 characters."
        case .changed: "This story changed. Reopen it and try again. Your saved story is unchanged."
        case .unreadable: "The story library could not be opened. Its files have not been replaced or deleted."
        }
    }
}

/// Independent files: no session database or training archive is read, migrated or modified.
@MainActor @Observable
final class StoryStore {
    private struct Archive: Codable { var version = 1; var stories: [StoryDocument] }
    private(set) var stories: [StoryDocument]
    private let file: URL
    init(directory: URL? = nil) throws {
        var folder = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("VoiceToRead/Stories", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try folder.setResourceValues(values)
        file = folder.appendingPathComponent("stories.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
                guard archive.version == 1, archive.stories.allSatisfy(\.valid),
                      Set(archive.stories.map(\.id)).count == archive.stories.count else { throw StoryFailure.unreadable }
                stories = archive.stories
            } catch { throw StoryFailure.unreadable }
        } else {
            stories = [try StoryDocument.edited(title: "Los tres cerditos", text: EnglishTraining.firstText, source: .spanish, target: .english)]
            try persist(stories)
        }
    }
    func story(_ id: UUID) -> StoryDocument? { stories.first { $0.id == id } }
    private func persist(_ values: [StoryDocument]) throws {
        let data = try JSONEncoder().encode(Archive(stories: values))
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func save(_ story: StoryDocument, replacing previous: StoryDocument? = nil) throws {
        guard story.valid else { throw StoryFailure.invalid }
        if let previous { guard self.story(previous.id) == previous else { throw StoryFailure.changed } }
        var values = stories
        if let i = values.firstIndex(where: { $0.id == story.id }) { values[i] = story }
        else { values.append(story) }
        try persist(values); stories = values
    }
    func acceptTranslation(_ previous: StoryDocument, responses: [ReviewParagraph]) throws {
        guard story(previous.id) == previous else { throw StoryFailure.changed }
        var result = previous
        var snapshot = TranslationSnapshot(source: previous.paragraphs, generated: responses)
        snapshot.sourceLocale = previous.sourceLanguage.rawValue; snapshot.targetLocale = previous.targetLanguage.rawValue
        try snapshot.validate()
        result.translation = snapshot; result.translationReviewed = false; result.updatedAt = Date()
        try save(result, replacing: previous)
    }
    func review(_ previous: StoryDocument, corrections: [UUID: String]) throws {
        guard var snapshot = previous.translation, corrections.count == previous.paragraphs.count,
              previous.paragraphs.allSatisfy({ !(corrections[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw StoryFailure.invalid }
        snapshot.edits = Dictionary(uniqueKeysWithValues: corrections.map { ($0.key.uuidString, $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) })
        var result = previous
        result.translation = snapshot; result.translationReviewed = true; result.updatedAt = Date()
        try save(result, replacing: previous)
    }
    func delete(_ previous: StoryDocument) throws {
        guard story(previous.id) == previous else { throw StoryFailure.changed }
        let values = stories.filter { $0.id != previous.id }
        try persist(values); stories = values
    }
}
