import Foundation

/// Bundled editorial content, independent of user-created training archives.
struct SpeakingLesson: Decodable, Identifiable {
    struct Bilingual: Decodable { let en: String; let es: String }
    struct Cover: Decodable { let altEs: String; let prompt: String; let assetUrl: String?; let aspectRatio: String }
    struct Paragraph: Decodable, Identifiable {
        let number: Int; let function: String; let en: String; let es: String
        var id: Int { number }
    }
    struct Grammar: Decodable { let name: String; let exampleEn: String; let explanationEs: String; let sourceParagraph: Int }
    struct Expression: Decodable { let expressionEn: String; let meaningEs: String; let sourceParagraph: Int }
    struct Chunk: Decodable { let sourceParagraph: Int; let segments: [String] }
    struct Round: Decodable, Identifiable {
        let number: Int; let titleEs: String; let instructionsEs: String; let chunks: [Chunk]?
        var id: Int { number }
    }
    struct ReadingPractice: Decodable { let rounds: [Round] }
    struct Card: Decodable {
        let id: String; let number: String; let titleEn: String; let titleEs: String
        let level: String; let language: String; let categoryEs: String; let mainTopicEs: String
        let paragraphCount: Int; let grammarTopics: [String]; let essentialExpressionsCount: Int
        let activitiesEs: [String]; let estimatedMinutes: Int
    }
    let schemaVersion: String; let id: String; let number: Int; let status: String; let level: String
    let language: String; let title: Bilingual; let category: Bilingual; let mainTopic: Bilingual
    let estimatedMinutes: Int; let image: Cover; let learningObjectives: [String]
    let paragraphs: [Paragraph]; let grammar: [Grammar]; let essentialExpressions: [Expression]
    let readingPractice: ReadingPractice; let lessonCard: Card

    enum Failure: Error { case invalidContent, missingResource }
    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        let lesson = try decoder.decode(Self.self, from: data)
        try lesson.validate()
        return lesson
    }
    func validate() throws {
        func nonempty(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func reference(_ value: Int) -> Bool { (1...20).contains(value) }
        guard schemaVersion == "1.0.0", nonempty(id), !id.contains("/"), !id.contains("\\"),
              number > 0, status == "ready", ["A1", "A2", "B1", "B2", "C1", "C2"].contains(level),
              language == "en-US", estimatedMinutes > 0,
              [title.en, title.es, category.en, category.es, mainTopic.en, mainTopic.es, image.altEs].allSatisfy(nonempty),
              image.aspectRatio == "16:9", !learningObjectives.isEmpty, learningObjectives.allSatisfy(nonempty),
              paragraphs.count == 20, paragraphs.map(\.number) == Array(1...20),
              paragraphs.allSatisfy({ nonempty($0.en) && nonempty($0.es) && nonempty($0.function) }),
              !grammar.isEmpty, grammar.allSatisfy({ reference($0.sourceParagraph) && [ $0.name, $0.exampleEn, $0.explanationEs ].allSatisfy(nonempty) }),
              essentialExpressions.count == 8,
              essentialExpressions.allSatisfy({ reference($0.sourceParagraph) && nonempty($0.expressionEn) && nonempty($0.meaningEs) }),
              readingPractice.rounds.map(\.number) == [1, 2, 3],
              readingPractice.rounds.allSatisfy({ round in
                  nonempty(round.titleEs) && nonempty(round.instructionsEs) && (round.chunks ?? []).allSatisfy {
                      reference($0.sourceParagraph) && !$0.segments.isEmpty && $0.segments.allSatisfy(nonempty)
                  }
              }), !(readingPractice.rounds[1].chunks ?? []).isEmpty,
              lessonCard.id == id, Int(lessonCard.number) == number, lessonCard.level == level,
              lessonCard.titleEn == title.en, lessonCard.titleEs == title.es,
              lessonCard.paragraphCount == paragraphs.count, lessonCard.essentialExpressionsCount == essentialExpressions.count,
              lessonCard.estimatedMinutes == estimatedMinutes, lessonCard.grammarTopics == grammar.map(\.name),
              lessonCard.activitiesEs == readingPractice.rounds.map(\.titleEs),
              [lessonCard.language, lessonCard.categoryEs, lessonCard.mainTopicEs].allSatisfy(nonempty)
        else { throw Failure.invalidContent }
        if let asset = image.assetUrl {
            guard let url = URL(string: asset), url.scheme == "https", url.host != nil else { throw Failure.invalidContent }
        }
    }
}

enum SpeakingLessonCatalog {
    static func load(bundle: Bundle = .main) throws -> [SpeakingLesson] {
        guard let index = bundle.url(forResource: "catalog", withExtension: "json", subdirectory: "SpeakingLessons") else {
            throw SpeakingLesson.Failure.missingResource
        }
        let ids = try JSONDecoder().decode([String].self, from: Data(contentsOf: index))
        guard !ids.isEmpty, Set(ids).count == ids.count else { throw SpeakingLesson.Failure.invalidContent }
        return try ids.map { id in
            guard !id.contains("/"), !id.contains("\\"),
                  let url = bundle.url(forResource: id, withExtension: "json", subdirectory: "SpeakingLessons") else {
                throw SpeakingLesson.Failure.missingResource
            }
            let lesson = try SpeakingLesson.decode(Data(contentsOf: url))
            guard lesson.id == id else { throw SpeakingLesson.Failure.invalidContent }
            return lesson
        }
    }
}
