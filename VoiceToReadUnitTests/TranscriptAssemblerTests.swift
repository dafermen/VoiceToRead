import XCTest
@testable import VoiceToRead

final class TranscriptAssemblerTests: XCTestCase {
    func testRevisedFinalFromEarlierRunRetainsRunOrderAndIdentifier() {
        let first = UUID()
        let second = UUID()
        var assembler = TranscriptAssembler()
        let original = assembler.apply(.init(runID: first, start: 0, end: 1, text: "One", isFinal: true))
        _ = assembler.apply(.init(runID: second, start: 0, end: 1, text: "Two", isFinal: true))
        let revision = assembler.apply(.init(runID: first, start: 0, end: 1, text: "One revised.", isFinal: true))

        XCTAssertEqual(assembler.text, "One revised.\nTwo")
        XCTAssertEqual(revision.upserted.first?.id, original.upserted.first?.id)
        XCTAssertTrue(revision.removedIDs.isEmpty)
    }

    func testLateFinalFromEarlierRunRetainsRunOrder() {
        let first = UUID()
        let second = UUID()
        var assembler = TranscriptAssembler()
        _ = assembler.apply(.init(runID: first, start: 0, end: 1, text: "One", isFinal: true))
        _ = assembler.apply(.init(runID: second, start: 0, end: 1, text: "Three", isFinal: true))
        _ = assembler.apply(.init(runID: first, start: 1, end: 2, text: "Two", isFinal: true))
        XCTAssertEqual(assembler.text, "One\nTwo\nThree")
    }

    func testMergedFinalRangeRemovesObsoleteStoredIdentifiers() {
        let run = UUID()
        var assembler = TranscriptAssembler()
        let first = assembler.apply(.init(runID: run, start: 0, end: 1, text: "One", isFinal: true))
        let second = assembler.apply(.init(runID: run, start: 1, end: 2, text: "Two", isFinal: true))
        let merged = assembler.apply(.init(runID: run, start: 0, end: 2, text: "One two.", isFinal: true))
        XCTAssertEqual(assembler.finalized.count, 1)
        XCTAssertEqual(merged.upserted.first?.id, first.upserted.first?.id)
        XCTAssertEqual(merged.removedIDs, second.upserted.map(\.id))
    }
    func testLongTranscriptRetainsEveryFinalSegment() {
        let run = UUID()
        var assembler = TranscriptAssembler()
        for index in 0..<10000 {
            _ = assembler.apply(.init(runID: run, start: Double(index), end: Double(index + 1),
                                     text: "Sentence", isFinal: true))
        }
        XCTAssertEqual(assembler.finalized.count, 10000)
        XCTAssertEqual(assembler.finalized.last?.start, 9999)
    }
    func testPartialRevisionAndFinalizationDoNotDuplicate() {
        let run = UUID()
        var assembler = TranscriptAssembler()
        _ = assembler.apply(.init(runID: run, start: 0, end: 1, text: "Hello", isFinal: false))
        _ = assembler.apply(.init(runID: run, start: 0, end: 2, text: "Hello world", isFinal: false))
        XCTAssertEqual(assembler.partial.count, 1)
        _ = assembler.apply(.init(runID: run, start: 0, end: 2, text: "Hello world.", isFinal: true))
        _ = assembler.apply(.init(runID: run, start: 0, end: 2, text: "Hello world.", isFinal: true))
        XCTAssertTrue(assembler.partial.isEmpty)
        XCTAssertEqual(assembler.finalized.count, 1)
        XCTAssertEqual(assembler.text, "Hello world.")
    }

    func testPartialIdentitySurvivesRevisionAndFinalization() {
        let run = UUID()
        var assembler = TranscriptAssembler()
        _ = assembler.apply(.init(runID: run, start: 0, end: 1, text: "Hello", isFinal: false))
        let identifier = assembler.partial.first?.id
        _ = assembler.apply(.init(runID: run, start: 0, end: 2, text: "Hello world", isFinal: false))
        XCTAssertEqual(assembler.partial.first?.id, identifier)
        _ = assembler.apply(.init(runID: run, start: 0, end: 2, text: "Hello world.", isFinal: true))
        XCTAssertEqual(assembler.finalized.first?.id, identifier)
        XCTAssertTrue(assembler.partial.isEmpty)
    }

    func testRepeatedWordsInDistinctRangesAreRetained() {
        let run = UUID()
        var assembler = TranscriptAssembler()
        _ = assembler.apply(.init(runID: run, start: 0, end: 1, text: "Yes.", isFinal: true))
        _ = assembler.apply(.init(runID: run, start: 1, end: 2, text: "Yes.", isFinal: true))
        XCTAssertEqual(assembler.finalized.count, 2)
    }

    func testResumeRunWithResetTimestampDoesNotEraseEarlierSpeech() {
        var assembler = TranscriptAssembler()
        _ = assembler.apply(.init(runID: UUID(), start: 0, end: 1, text: "Before", isFinal: true))
        _ = assembler.apply(.init(runID: UUID(), start: 0, end: 1, text: "After", isFinal: true))
        XCTAssertEqual(assembler.text, "Before\nAfter")
    }

    func testInvalidRangesAndLatePartialCannotOverwriteFinal() {
        let run = UUID()
        var assembler = TranscriptAssembler()
        _ = assembler.apply(.init(runID: run, start: 0, end: 1, text: "Final", isFinal: true))
        _ = assembler.apply(.init(runID: run, start: 0, end: 1, text: "Old", isFinal: false))
        _ = assembler.apply(.init(runID: run, start: .nan, end: 2, text: "Invalid", isFinal: true))
        XCTAssertEqual(assembler.text, "Final")
        XCTAssertTrue(assembler.partial.isEmpty)
    }
}
