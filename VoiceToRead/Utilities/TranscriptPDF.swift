import Foundation
import CoreGraphics
import CoreText

enum TranscriptPDF {
    enum Failure: LocalizedError {
        case creation, layout
        var errorDescription: String? { "The PDF could not be prepared. Try exporting a text file." }
    }

    /// Core Text paginates by UTF-16 ranges, retaining Unicode and long paragraphs.
    /// It runs off the main thread and does not create temporary files.
    static func render(text: String, emphasizeTitle: Bool) throws -> Data {
        let storage = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: storage as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &page, nil) else { throw Failure.creation }
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        let colorKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
        var spacing: CGFloat = 5
        let style = withUnsafePointer(to: &spacing) { pointer in
            var setting = CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: pointer)
            return CTParagraphStyleCreate(&setting, 1)
        }
        let body = NSMutableAttributedString(string: text, attributes: [
            fontKey: CTFontCreateWithName("Helvetica" as CFString, 14, nil),
            colorKey: CGColor(gray: 0.08, alpha: 1),
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): style
        ])
        if emphasizeTitle, let end = text.firstIndex(of: "\n") {
            body.addAttribute(fontKey, value: CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil),
                              range: NSRange(text.startIndex..<end, in: text))
        }
        let framesetter = CTFramesetterCreateWithAttributedString(body)
        let path = CGPath(rect: CGRect(x: 44, y: 54, width: 507, height: 744), transform: nil)
        var location = 0
        var pageNumber = 1
        repeat {
            if Task<Never, Never>.isCancelled { throw CancellationError() }
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 || body.length == 0 else { throw Failure.layout }
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            CTFrameDraw(frame, context)
            let footer = NSAttributedString(string: "\(pageNumber)", attributes: [
                fontKey: CTFontCreateWithName("Helvetica" as CFString, 9, nil), colorKey: CGColor(gray: 0.4, alpha: 1)
            ])
            let line = CTLineCreateWithAttributedString(footer)
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            context.textPosition = CGPoint(x: (595 - width) / 2, y: 26)
            CTLineDraw(line, context)
            context.endPDFPage()
            location += visible.length
            pageNumber += 1
        } while location < body.length
        context.closePDF()
        return storage as Data
    }
}
