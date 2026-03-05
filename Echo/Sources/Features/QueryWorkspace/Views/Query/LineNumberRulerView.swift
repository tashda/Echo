#if os(macOS)
import AppKit
import SwiftUI
import Combine

final class LineNumberRulerView: NSRulerView {
    weak var sqlTextView: SQLTextView?
    var highlightedLines: IndexSet = []
    var theme: SQLEditorTheme {
        didSet { needsDisplay = true }
    }

    private let paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }()

    init(textView: SQLTextView, theme: SQLEditorTheme) {
        self.theme = theme
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.sqlTextView = textView
        self.clientView = textView
        self.ruleThickness = 40
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.height]
        setFrameSize(NSSize(width: ruleThickness, height: frame.size.height))
        setBoundsSize(NSSize(width: ruleThickness, height: bounds.size.height))

        // Observe text changes to update line numbers live
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    // Keep the ruler from stretching over the text view when AppKit resizes it.
    override func setFrameSize(_ newSize: NSSize) {
        let width = ruleThickness > 0 ? ruleThickness : newSize.width
        super.setFrameSize(NSSize(width: width, height: newSize.height))
    }

    override func setBoundsSize(_ newSize: NSSize) {
        let width = ruleThickness > 0 ? ruleThickness : newSize.width
        super.setBoundsSize(NSSize(width: width, height: newSize.height))
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        let gutterWidth = max(0, ruleThickness)
        let gutterRect = NSRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)

        // No background fill - transparent line numbers

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.surfaces.gutterText.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let glyphCount = layoutManager.numberOfGlyphs
        let nsString = textView.string as NSString

        if glyphCount == 0 || nsString.length == 0 {
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

        layoutManager.ensureLayout(for: textContainer)

        var visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        if visibleGlyphRange.location == NSNotFound {
            visibleGlyphRange = NSRange(location: 0, length: glyphCount)
        }

        let initialGlyph = min(visibleGlyphRange.location, max(glyphCount - 1, 0))
        let maxGlyphIndex = min(NSMaxRange(visibleGlyphRange), glyphCount)
        if maxGlyphIndex <= initialGlyph {
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let yPosition = lineRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y

            let lineNumber = nsString.lineNumber(at: lineRange.location)
            let labelRect = NSRect(x: 0, y: yPosition + 2, width: gutterRect.width - 8, height: lineRect.height)
            ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)

            glyphIndex = min(NSMaxRange(lineRange), maxGlyphIndex)
        }

        if layoutManager.extraLineFragmentTextContainer != nil {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                let yPosition = extraRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y
                let labelRect = NSRect(x: 0, y: yPosition + 2, width: gutterRect.width - 8, height: extraRect.height)
                let lastLineNumber = nsString.lineNumber(at: nsString.length)
                ("\(lastLineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)
            }
        }

        // No divider – match Tahoe preview
    }

    private func drawFallbackLine(with attributes: [NSAttributedString.Key: Any], in rect: NSRect) {
        guard let textView = sqlTextView else {
            let labelRect = NSRect(x: 0, y: rect.minY + 4, width: rect.width - 8, height: rect.height)
            ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
            return
        }

        let font = textView.theme.nsFont
        let lineHeight = max(CGFloat(16), font.ascender - font.descender + font.leading)
        let insetOrigin = textView.textContainerOrigin
        let visibleOffset = textView.visibleRect.origin.y
        let baseY = insetOrigin.y - visibleOffset
        let yPosition = max(rect.minY, baseY + 2)

        let labelRect = NSRect(
            x: 0,
            y: yPosition,
            width: rect.width - 8,
            height: lineHeight
        )
        ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard point.x <= ruleThickness else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) { selectLine(event) }
    override func mouseDragged(with event: NSEvent) { selectLine(event) }

    private func selectLine(_ event: NSEvent) {
        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else { return }

        let location = convert(event.locationInWindow, from: nil)
        let pointInTextView = convert(location, to: textView)
        var fraction: CGFloat = 0
        var glyphIndex = layoutManager.glyphIndex(for: pointInTextView, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        glyphIndex = min(max(glyphIndex, 0), glyphCount - 1)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let line = (textView.string as NSString).lineNumber(at: charIndex)
        textView.selectLineRange(line...line)
    }
}

#endif
