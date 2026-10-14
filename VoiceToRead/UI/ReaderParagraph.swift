import SwiftUI
import UIKit

/// A paragraph owns its rules so scrolling, pause banners and rotation cannot shift
/// the paper independently of its words. Text is user content, never localized.
struct ReaderParagraph: View {
    let text: String
    let points: CGFloat
    let spacing: Double
    let bold: Bool
    let ruled: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Group {
            if ruled {
                NotebookText(text: text, points: points, spacing: spacing, bold: bold, dark: scheme == .dark)
            } else {
                Text(text).font(.system(size: points, weight: bold ? .semibold : .regular))
                    .lineSpacing(spacing).textSelection(.enabled)
            }
        }
    }
}

struct NotebookText: UIViewRepresentable {
    let text: String
    let points: CGFloat
    let spacing: Double
    let bold: Bool
    let dark: Bool
    func makeUIView(context: Context) -> NotebookTextView { NotebookTextView() }
    func updateUIView(_ view: NotebookTextView, context: Context) {
        view.configure(text: text, points: points, spacing: spacing, bold: bold, dark: dark)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NotebookTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return uiView.measuredSize(width: width)
    }
}

/// TextKit 1 intentionally supplies one layout for measurement, selection, glyphs and rules.
final class NotebookTextView: UITextView {
    init() {
        let storage = NSTextStorage()
        let manager = NotebookLayoutManager()
        let container = NSTextContainer(size: .zero)
        storage.addLayoutManager(manager); manager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        isEditable = false; isSelectable = true; isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)
        container.lineFragmentPadding = 0
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        accessibilityTraits = .staticText
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(text: String, points: CGFloat, spacing: Double, bold: Bool, dark: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(4, spacing)
        let font = UIFont.systemFont(ofSize: points, weight: bold ? .semibold : .regular)
        let ink = dark ? UIColor.white : UIColor.black
        let value = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink, .paragraphStyle: paragraph])
        if !attributedText.isEqual(to: value) { attributedText = value; invalidateIntrinsicContentSize() }
        (layoutManager as? NotebookLayoutManager)?.ruleColor = ink.withAlphaComponent(0.20)
        accessibilityLabel = text
        setNeedsDisplay()
    }
    func measuredSize(width: CGFloat) -> CGSize {
        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        return CGSize(width: width, height: ceil(layoutManager.usedRect(for: textContainer).maxY) + 4)
    }
}

final class NotebookLayoutManager: NSLayoutManager {
    var ruleColor = UIColor.black.withAlphaComponent(0.20)
    /// Line fragments include interline spacing. Place each rule below the font
    /// descender relative to the actual baseline, inside that spacing.
    func rules(for range: NSRange) -> [CGRect] {
        var rules: [CGRect] = []
        enumerateLineFragments(forGlyphRange: range) { fragment, _, container, glyphs, _ in
            guard glyphs.length > 0 else { return }
            let character = self.characterIndexForGlyph(at: glyphs.location)
            guard let font = self.textStorage?.attribute(.font, at: character, effectiveRange: nil) as? UIFont else { return }
            let baseline = fragment.minY + self.location(forGlyphAt: glyphs.location).y
            let y = baseline - font.descender + 1
            rules.append(CGRect(x: 0, y: y, width: container.size.width, height: 0.5))
        }
        return rules
    }
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(ruleColor.cgColor)
        for rule in rules(for: glyphsToShow) {
            context.fill(rule.offsetBy(dx: origin.x, dy: origin.y))
        }
    }
}
