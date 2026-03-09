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

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let rulerFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: rulerFont,
            .foregroundColor: theme.surfaces.gutterText.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let glyphCount = layoutManager.numberOfGlyphs
        let nsString = textView.string as NSString

        if glyphCount == 0 || nsString.length == 0 {
            drawFallbackLine(with: attributes, rulerFont: rulerFont, in: gutterRect)
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
            drawFallbackLine(with: attributes, rulerFont: rulerFont, in: gutterRect)
            return
        }

        let containerOriginY = textView.textContainerOrigin.y
        let scrollOffsetY = textView.visibleRect.origin.y
        let rulerLabelHeight = ceil(rulerFont.ascender - rulerFont.descender + rulerFont.leading)

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)

            // Use the actual glyph baseline position from the layout manager.
            // location(forGlyphAt:).y gives the baseline offset within the line fragment.
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
            let baselineY = lineFragmentRect.minY + glyphLocation.y + containerOriginY - scrollOffsetY

            // Position the ruler label so its baseline aligns with the text baseline.
            // NSString.draw(in:) places the text baseline at rect.minY + font.ascender.
            let labelY = baselineY - rulerFont.ascender

            let lineNumber = nsString.lineNumber(at: lineRange.location)
            let labelRect = NSRect(x: 0, y: labelY, width: gutterWidth - 8, height: rulerLabelHeight)
            ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)

            let next = NSMaxRange(lineRange)
            if next <= glyphIndex { break }
            glyphIndex = next
        }

        if layoutManager.extraLineFragmentTextContainer != nil {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                // For the extra line fragment, use the text font ascender as the baseline offset
                let textFont = textView.font ?? NSFont.systemFont(ofSize: 13)
                let baselineY = extraRect.minY + textFont.ascender + containerOriginY - scrollOffsetY
                let labelY = baselineY - rulerFont.ascender
                let labelRect = NSRect(x: 0, y: labelY, width: gutterWidth - 8, height: rulerLabelHeight)
                let lastLineNumber = nsString.lineNumber(at: nsString.length)
                ("\(lastLineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)
            }
        }
    }

    private func drawFallbackLine(with attributes: [NSAttributedString.Key: Any], rulerFont: NSFont, in rect: NSRect) {
        guard let textView = sqlTextView else {
            let rulerLabelHeight = ceil(rulerFont.ascender - rulerFont.descender + rulerFont.leading)
            let labelRect = NSRect(x: 0, y: rect.minY + 4, width: rect.width - 8, height: rulerLabelHeight)
            ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
            return
        }

        // Even with empty text, position "1" at the correct baseline using the text container origin.
        let textFont = textView.font ?? textView.theme.nsFont
        let containerOriginY = textView.textContainerOrigin.y
        let scrollOffsetY = textView.visibleRect.origin.y
        // The first line baseline is at containerOrigin + textFont.ascender
        let baselineY = containerOriginY - scrollOffsetY + textFont.ascender
        let labelY = baselineY - rulerFont.ascender
        let rulerLabelHeight = ceil(rulerFont.ascender - rulerFont.descender + rulerFont.leading)

        let labelRect = NSRect(
            x: 0,
            y: labelY,
            width: rect.width - 8,
            height: rulerLabelHeight
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
