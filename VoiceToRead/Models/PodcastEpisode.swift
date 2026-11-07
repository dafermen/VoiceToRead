import Foundation

/// Bundled English listening content; separate from stories, practices and sessions.
struct PodcastEpisode: Codable, Identifiable, Equatable {
    struct Segment: Codable, Identifiable, Equatable {
        let number: Int
        let en: String
        let es: String
        let duration: Double
        var id: Int { number }
    }
    let schemaVersion: Int
    let id: String
    let titleEn: String
    let titleEs: String
    let summaryEn: String
    let summaryEs: String
    let level: String
    let language: String
    let baseSpeed: Double
    let segments: [Segment]
    var duration: Double { segments.reduce(0) { $0 + $1.duration } }
    var normalDuration: Double { duration * baseSpeed }
    enum Failure: Error { case invalidContent }

    func validate() throws {
        guard schemaVersion == 1, id.range(of: #"^POD-[A-Z0-9]+-[0-9]{3}$"#, options: .regularExpression) != nil,
              !titleEn.isEmpty, !titleEs.isEmpty, !summaryEn.isEmpty, !summaryEs.isEmpty,
              language == "en-US", baseSpeed.isFinite, (0.5...1).contains(baseSpeed),
              !segments.isEmpty, segments.count <= 200,
              segments.map(\.number) == Array(1...segments.count),
              segments.allSatisfy({ !$0.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  !$0.es.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.duration.isFinite && $0.duration > 0 }) else { throw Failure.invalidContent }
    }
    func resourceURL(number: Int, fileExtension suffix: String, bundle: Bundle = .main) throws -> URL {
        try validate()
        guard segments.contains(where: { $0.number == number }), ["mp3", "json"].contains(suffix),
              let url = bundle.url(forResource: String(format: "%02d", number), withExtension: suffix,
                                   subdirectory: "Podcasts/\(id)-audio") else { throw Failure.invalidContent }
        return url
    }
    static func load(bundle: Bundle = .main) throws -> [Self] {
        guard let catalog = bundle.url(forResource: "catalog", withExtension: "json", subdirectory: "Podcasts") else { throw Failure.invalidContent }
        let ids = try JSONDecoder().decode([String].self, from: Data(contentsOf: catalog))
        guard !ids.isEmpty, Set(ids).count == ids.count else { throw Failure.invalidContent }
        return try ids.map { id in
            guard id.range(of: #"^POD-[A-Z0-9]+-[0-9]{3}$"#, options: .regularExpression) != nil,
                  let url = bundle.url(forResource: id, withExtension: "json", subdirectory: "Podcasts") else { throw Failure.invalidContent }
            let episode = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
            guard episode.id == id else { throw Failure.invalidContent }
            try episode.validate()
            return episode
        }
    }
}


/// Presentation ranges reference the original UTF-16 text used by the audio cues.
enum PodcastReadingParagraphs {
    static func ranges(in text: String) -> [NSRange] {
        var result: [NSRange] = []
        let whole = text.startIndex..<text.endIndex
        text.enumerateSubstrings(in: whole, options: .byParagraphs) { _, paragraph, _, _ in
            text.enumerateSubstrings(in: paragraph, options: .bySentences) { _, sentence, _, _ in
                let trimmed = String(text[sentence]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, let range = text.range(of: trimmed, range: sentence) {
                    result.append(NSRange(range, in: text))
                }
            }
        }
        if result.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = [NSRange(whole, in: text)]
        }
        return result
    }
}
