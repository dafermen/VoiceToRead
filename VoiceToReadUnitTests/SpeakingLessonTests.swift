import XCTest
@testable import VoiceToRead

final class SpeakingLessonTests: XCTestCase {
    private func fixture() throws -> (SpeakingLesson, [String: Any]) {
        let lesson = try XCTUnwrap(SpeakingLessonCatalog.load().first)
        let url = try XCTUnwrap(Bundle.main.url(forResource: lesson.id, withExtension: "json", subdirectory: "SpeakingLessons"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return (lesson, json)
    }
    func testBundledLessonPreservesOrderedBilingualContent() throws {
        let (lesson, json) = try fixture()
        XCTAssertEqual(lesson.id, "SPK-B1-001")
        XCTAssertEqual(lesson.level, "B1")
        XCTAssertEqual(lesson.paragraphs.count, 20)
        XCTAssertEqual(lesson.essentialExpressions.count, 8)
        XCTAssertEqual(lesson.readingPractice.rounds.count, 3)
        let paragraphs = try XCTUnwrap(json["paragraphs"] as? [[String: Any]])
        for (i, paragraph) in lesson.paragraphs.enumerated() {
            XCTAssertEqual(paragraph.number, i + 1)
            XCTAssertEqual(paragraph.en, paragraphs[i]["en"] as? String)
            XCTAssertEqual(paragraph.es, paragraphs[i]["es"] as? String)
        }
        XCTAssertEqual(lesson.grammar[3].name, "Used to")
        XCTAssertNil(lesson.image.assetUrl)
        XCTAssertNotNil(Bundle.main.url(forResource: lesson.id + "-cover", withExtension: "png", subdirectory: "SpeakingLessons"))
    }
    func testInvalidLessonsAreRejectedBeforeRendering() throws {
        let (_, original) = try fixture()
        func rejected(_ mutate: (inout [String: Any]) -> Void) throws {
            var json = original; mutate(&json)
            XCTAssertThrowsError(try SpeakingLesson.decode(JSONSerialization.data(withJSONObject: json)))
        }
        try rejected { $0["level"] = "B1.1" }
        try rejected { $0["schema_version"] = "9.0" }
        try rejected { json in
            var p = json["paragraphs"] as! [[String: Any]]; p.removeLast(); json["paragraphs"] = p
        }
        try rejected { json in
            var p = json["paragraphs"] as! [[String: Any]]; p[1]["number"] = 1; json["paragraphs"] = p
        }
        try rejected { json in
            var p = json["paragraphs"] as! [[String: Any]]; p[0]["es"] = " "; json["paragraphs"] = p
        }
        try rejected { json in
            var g = json["grammar"] as! [[String: Any]]; g[0]["source_paragraph"] = 21; json["grammar"] = g
        }
        try rejected { json in
            var reading = json["reading_practice"] as! [String: Any]
            var rounds = reading["rounds"] as! [[String: Any]]
            var chunks = rounds[1]["chunks"] as! [[String: Any]]
            chunks[0]["segments"] = [""]; rounds[1]["chunks"] = chunks
            reading["rounds"] = rounds; json["reading_practice"] = reading
        }
    }
}
