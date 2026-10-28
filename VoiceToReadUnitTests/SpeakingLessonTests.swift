import XCTest
import AVFoundation
import UIKit
import CryptoKit
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
    func testOfflineAudioAndWordRangesMatchEveryParagraph() throws {
        let (lesson, _) = try fixture()
        for paragraph in lesson.paragraphs {
            let name = String(format: "%02d", paragraph.number)
            let directory = "SpeakingLessons/\(lesson.id)-audio"
            let audioURL = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: directory))
            XCTAssertGreaterThan(try Data(contentsOf: audioURL).count, 1_000)
            let timingURL = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json", subdirectory: directory))
            let timing = try JSONDecoder().decode(GuidedWordTiming.self, from: Data(contentsOf: timingURL))
            XCTAssertNoThrow(try timing.validate(expected: paragraph.en))
            let decodedAudio = try AVAudioPlayer(contentsOf: audioURL)
            XCTAssertGreaterThan(decodedAudio.duration, 0)
            XCTAssertLessThanOrEqual(timing.words.map(\.end).max() ?? 0, decodedAudio.duration + 0.25)
            let word = try XCTUnwrap(timing.words.first { $0.end > $0.start })
            XCTAssertNotNil(timing.range(at: (word.start + word.end) / 2))
            XCTAssertNil(timing.range(at: -1))
            XCTAssertThrowsError(try timing.validate(expected: "Changed paragraph"))
        }
    }
    func testSupportPacksContainEveryTranslatedParagraphAndExplanation() throws {
        let (lesson, _) = try fixture()
        for language in [CaptureLanguage.french, .korean, .japanese, .chinese] {
            let pack = try XCTUnwrap(GuidedLessonSupport.load(lesson: lesson, language: language))
            XCTAssertEqual(pack.locale, language.code)
            for i in 0..<20 { XCTAssertFalse(pack.text("paragraphs.\(i).es", fallback: "").isEmpty) }
            for i in 0..<8 {
                XCTAssertFalse(pack.text("grammar.\(i).explanation_es", fallback: "").isEmpty)
                XCTAssertFalse(pack.text("essential_expressions.\(i).meaning_es", fallback: "").isEmpty)
            }
            for i in 0..<3 { XCTAssertFalse(pack.text("reading_practice.rounds.\(i).instructions_es", fallback: "").isEmpty) }
        }
    }

    func testAllFourLevelsHaveTenDistinctCompleteLessons() throws {
        let lessons = try SpeakingLessonCatalog.load()
        XCTAssertEqual(lessons.count, 40)
        XCTAssertEqual(Set(lessons.map(\.id)).count, 40)
        for level in ["B1", "B2", "C1", "C2"] {
            let group = lessons.filter { $0.level == level }
            XCTAssertEqual(group.map(\.number).sorted(), Array(1...10))
            for lesson in group {
                XCTAssertNoThrow(try lesson.validate())
                for paragraph in lesson.paragraphs {
                    let name = String(format: "%02d", paragraph.number)
                    let directory = "SpeakingLessons/\(lesson.id)-audio"
                    XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: directory))
                    let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json", subdirectory: directory))
                    let timing = try JSONDecoder().decode(GuidedWordTiming.self, from: Data(contentsOf: url))
                    XCTAssertNoThrow(try timing.validate(expected: paragraph.en))
                }
                for language in [CaptureLanguage.french, .korean, .japanese, .chinese] {
                    let pack = try XCTUnwrap(GuidedLessonSupport.load(lesson: lesson, language: language))
                    for i in 0..<20 { XCTAssertFalse(pack.text("paragraphs.\(i).es", fallback: "").isEmpty) }
                }
            }
        }
        XCTAssertEqual(Set(lessons.map { $0.paragraphs.map(\.en).joined(separator: "\n") }).count, 40)
        for number in 1...2 {
            let c1 = try XCTUnwrap(lessons.first { $0.level == "C1" && $0.number == number })
            let c2 = try XCTUnwrap(lessons.first { $0.level == "C2" && $0.number == number })
            XCTAssertEqual(c1.title.en, c2.title.en)
            XCTAssertNotEqual(c1.paragraphs.map(\.en), c2.paragraphs.map(\.en))
        }
        for number in 1...10 {
            let b1 = try XCTUnwrap(lessons.first { $0.level == "B1" && $0.number == number })
            let b2 = try XCTUnwrap(lessons.first { $0.level == "B2" && $0.number == number })
            XCTAssertEqual(b1.title.en, b2.title.en)
            XCTAssertNotEqual(b1.paragraphs.map(\.en), b2.paragraphs.map(\.en))
        }
    }

    func testEveryLessonHasAUniqueDecodableLandscapeCover() throws {
        let lessons = try SpeakingLessonCatalog.load()
        var fingerprints = Set<Data>()
        for lesson in lessons {
            let url = try XCTUnwrap(Bundle.main.url(forResource: lesson.id + "-cover", withExtension: "png", subdirectory: "SpeakingLessons"))
            let data = try Data(contentsOf: url)
            let cover = try XCTUnwrap(UIImage(data: data))
            XCTAssertGreaterThan(cover.size.height, 0)
            XCTAssertEqual(cover.size.width / cover.size.height, 16.0 / 9.0, accuracy: 0.025)
            XCTAssertTrue(fingerprints.insert(Data(SHA256.hash(data: data))).inserted)
        }
        XCTAssertEqual(fingerprints.count, 40)
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
