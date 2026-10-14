import XCTest
import PDFKit
@testable import VoiceToRead

final class TranscriptExportTests: XCTestCase {
    func testExportContainsMetadataAndUnicode() {
        let text = TranscriptExport.render(title: "Training", date: Date(timeIntervalSince1970: 0),
            duration: 3661, language: "en-US", transcript: "Résumé — hello", unfinished: true)
        XCTAssertTrue(text.contains("Training"))
        XCTAssertTrue(text.contains("01:01:01"))
        XCTAssertTrue(text.contains("en-US"))
        XCTAssertTrue(text.contains("Unfinished"))
        XCTAssertTrue(text.contains("Résumé — hello"))
    }

    func testFilenameCannotContainPathSeparators() {
        let name = TranscriptExport.filename(title: "a/b\\c:meeting")
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains("\\"))
        XCTAssertEqual(TranscriptExport.filename(title: "   "), "VoiceToRead-transcript")
    }
    func testFindReplaceUsesWholeUnicodeWordsAndLiteralReplacement() {
        let paragraph = ReviewParagraph(id: UUID(), text: "📝 Acmee acmee Acmees café. Acmee!")
        var search = TranscriptSearch(query: "Acmee", replacement: "$1\\fixed")
        XCTAssertEqual(search.matches(in: [paragraph]).count, 3)
        XCTAssertEqual(search.replacingAll(in: [paragraph]).first?.text, "📝 $1\\fixed $1\\fixed Acmees café. $1\\fixed!")
        search.caseSensitive = true
        XCTAssertEqual(search.matches(in: [paragraph]).count, 2)
        search.wholeWords = false
        XCTAssertEqual(search.matches(in: [paragraph]).count, 3)
        let accented = ReviewParagraph(id: UUID(), text: "cafe\u{301} cafe")
        let plainWord = TranscriptSearch(query: "cafe", replacement: "coffee")
        XCTAssertEqual(plainWord.replacingAll(in: [accented]).first?.text, "cafe\u{301} coffee")
        search.query = ""
        XCTAssertTrue(search.matches(in: [paragraph]).isEmpty)
    }

    func testSingleReplacementAndUndoRedoPreserveParagraphs() throws {
        let first = ReviewParagraph(id: UUID(), text: "cat cat")
        let second = ReviewParagraph(id: UUID(), text: "cathedral")
        var history = EditHistory([first, second])
        let search = TranscriptSearch(query: "cat", replacement: "dog")
        history.set(search.replacing(try XCTUnwrap(search.matches(in: history.value).first), in: history.value))
        XCTAssertEqual(history.value.map(\.text), ["dog cat", "cathedral"])
        history.undo()
        XCTAssertEqual(history.value, [first, second])
        history.redo()
        XCTAssertEqual(history.value[0].id, first.id)
        XCTAssertEqual(history.value[0].text, "dog cat")
        history.undo()
        history.set(search.replacingAll(in: history.value))
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.value.map(\.text), ["dog dog", "cathedral"])
    }

    func testEditedTextAndBookmarksUseTheSameCorrectionsWithoutMetadata() {
        let paragraph = ReviewParagraph(id: UUID(), text: "Original")
        let changes = [paragraph.id.uuidString: "Corrected\nwith another line"]
        let all = TranscriptReview.text(TranscriptReview.paragraphs(originals: [paragraph], corrections: changes))
        let bookmark = TranscriptReview.text(TranscriptReview.paragraphs(originals: [paragraph], corrections: changes))
        XCTAssertEqual(all, bookmark)
        let exported = TranscriptExport.render(title: "Private title", date: .now, duration: 42,
            language: "en-US", transcript: all, unfinished: false, includeDetails: false)
        XCTAssertEqual(exported, "Corrected\nwith another line")
        XCTAssertFalse(exported.contains("Private title"))
        XCTAssertEqual(paragraph.text, "Original")
    }

    @MainActor
    func testPDFPaginatesLongUnicodeTranscriptWithoutDroppingText() throws {
        let paragraphs = (1...120).map { "Section\($0): Résumé, café and clear captions. " + String(repeating: "Review every word carefully. ", count: 8) }
        let text = TranscriptExport.render(title: "Reviewed conversation", date: Date(timeIntervalSince1970: 0),
            duration: 3600, language: "en-US", transcript: paragraphs.joined(separator: "\n\n") + "\nEND_OF_TRANSCRIPT", unfinished: false)
        let data = try TranscriptPDF.render(text: text, emphasizeTitle: true)
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(pdf.pageCount, 1)
        let extracted = try XCTUnwrap(pdf.string)
        XCTAssertTrue(extracted.contains("Résumé"))
        XCTAssertTrue(extracted.contains("END_OF_TRANSCRIPT"))
        for index in 1...120 {
            XCTAssertTrue(extracted.contains("Section\(index):"), "Missing section \(index)")
        }
        let file = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        file.name = "Review-Export.pdf"
        file.lifetime = .keepAlways
        add(file)
        for index in 0..<pdf.pageCount {
            let page = try XCTUnwrap(pdf.page(at: index))
            let preview = XCTAttachment(image: page.thumbnail(of: CGSize(width: 595, height: 842), for: .mediaBox))
            preview.name = "Review-PDF-page-\(index + 1)"
            preview.lifetime = .keepAlways
            add(preview)
        }
    }

}
