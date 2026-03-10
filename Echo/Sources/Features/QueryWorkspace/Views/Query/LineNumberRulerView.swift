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

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Get the fixed baseline offset from SQLLayoutManager (bulletproof, same for every line).
        let sqlLayout = layoutManager as? SQLLayoutManager
        let fixedBaseline = sqlLayout?.fixedBaselineOffset

        let rulerFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let rulerLabelHeight = ceil(rulerFont.ascender - rulerFont.descender + rulerFont.leading)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: rulerFont,
            .foregroundColor: theme.surfaces.gutterText.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let glyphCount = layoutManager.numberOfGlyphs
        let nsString = textView.string as NSString
        let containerOriginY = textView.textContainerOrigin.y
        let scrollOffsetY = textView.visibleRect.origin.y

        if glyphCount == 0 || nsString.length == 0 {
            drawLineLabel(1, at: 0, containerOriginY: containerOriginY, scrollOffsetY: scrollOffsetY,
                          fixedBaseline: fixedBaseline, textView: textView, rulerFont: rulerFont,
                          rulerLabelHeight: rulerLabelHeight, gutterWidth: gutterWidth, attributes: attributes)
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
            drawLineLabel(1, at: 0, containerOriginY: containerOriginY, scrollOffsetY: scrollOffsetY,
                          fixedBaseline: fixedBaseline, textView: textView, rulerFont: rulerFont,
                          rulerLabelHeight: rulerLabelHeight, gutterWidth: gutterWidth, attributes: attributes)
            return
        }

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)

            let lineNumber = nsString.lineNumber(at: layoutManager.characterIndexForGlyph(at: glyphIndex))

            drawLineLabel(lineNumber, at: lineFragmentRect.minY, containerOriginY: containerOriginY,
                          scrollOffsetY: scrollOffsetY, fixedBaseline: fixedBaseline, textView: textView,
                          rulerFont: rulerFont, rulerLabelHeight: rulerLabelHeight,
                          gutterWidth: gutterWidth, attributes: attributes)

            let next = NSMaxRange(lineRange)
            if next <= glyphIndex { break }
            glyphIndex = next
        }

        // Draw the extra line fragment (trailing empty line after final newline).
        if layoutManager.extraLineFragmentTextContainer != nil {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                let lastLineNumber = nsString.lineNumber(at: nsString.length)
                drawLineLabel(lastLineNumber, at: extraRect.minY, containerOriginY: containerOriginY,
                              scrollOffsetY: scrollOffsetY, fixedBaseline: fixedBaseline, textView: textView,
                              rulerFont: rulerFont, rulerLabelHeight: rulerLabelHeight,
                              gutterWidth: gutterWidth, attributes: attributes)
            }
        }
    }

    /// Draws a single line number label using the fixed baseline offset from SQLLayoutManager.
    /// `lineFragmentMinY` is the top of the line fragment in text container coordinates.
    private func drawLineLabel(
        _ lineNumber: Int,
        at lineFragmentMinY: CGFloat,
        containerOriginY: CGFloat,
        scrollOffsetY: CGFloat,
        fixedBaseline: CGFloat?,
        textView: NSTextView,
        rulerFont: NSFont,
        rulerLabelHeight: CGFloat,
        gutterWidth: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let baselineOffset: CGFloat
        if let fixedBaseline {
            baselineOffset = fixedBaseline
        } else {
            // Fallback: use the text font's ascender.
            let textFont = textView.font ?? NSFont.systemFont(ofSize: 13)
            baselineOffset = textFont.ascender
        }

        let baselineY = lineFragmentMinY + baselineOffset + containerOriginY - scrollOffsetY
        let labelY = baselineY - rulerFont.ascender
        let labelRect = NSRect(x: 0, y: labelY, width: gutterWidth - 8, height: rulerLabelHeight)
        ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: attributes)
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
