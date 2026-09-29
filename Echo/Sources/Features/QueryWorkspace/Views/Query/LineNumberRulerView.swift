#if os(macOS)
import AppKit
import SwiftUI
import Combine

final class LineNumberRulerView: NSRulerView {
    weak var sqlTextView: SQLTextView?
    /// Lines holding the selection or the cursor; their numbers take the gutter accent.
    var highlightedLines: IndexSet = [] {
        didSet { if oldValue != highlightedLines { needsDisplay = true } }
    }
    /// Lines with a validation error; each gets a red dot beside its number.
    var errorLines: IndexSet = [] {
        didSet { if oldValue != errorLines { needsDisplay = true } }
    }
    /// Subtle (numbers only), a tinted column with an edge, or a tinted inset lane, from Settings.
    var gutterStyle: EditorGutterStyle = .subtle {
        didSet { if oldValue != gutterStyle { needsDisplay = true } }
    }
    var theme: SQLEditorTheme {
        didSet { needsDisplay = true }
    }
    /// Digits the gutter is currently sized for; it widens as the script grows.
    private var sizedDigitCount = 0

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
        self.ruleThickness = Self.thickness(forDigits: LayoutTokens.EditorGutter.minimumDigits)
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
        updateThickness()
        needsDisplay = true
    }

    /// Widens or narrows the gutter to fit the last line's number.
    func updateThickness() {
        let lineCount = (sqlTextView?.string as NSString?)?.lineNumber(at: Int.max) ?? 1
        let digits = max(String(lineCount).count, LayoutTokens.EditorGutter.minimumDigits)
        guard digits != sizedDigitCount else { return }
        sizedDigitCount = digits
        ruleThickness = Self.thickness(forDigits: digits)
    }

    private static let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private static let currentNumberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)

    /// Room for the error dot, the digits, and the gap before the text.
    static func thickness(forDigits digits: Int) -> CGFloat {
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: numberFont]).width
        return ceil(
            LayoutTokens.EditorGutter.markerLeading + LayoutTokens.EditorGutter.markerSize
                + LayoutTokens.EditorGutter.markerSpacing + digitWidth * CGFloat(digits)
                + LayoutTokens.EditorGutter.numberTrailing
        )
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
        drawBackground(width: gutterWidth)

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // The fixed baseline from SQLLayoutManager, the same for every line.
        let fixedBaseline = (layoutManager as? SQLLayoutManager)?.fixedBaselineOffset
        let context = LabelContext(
            containerOriginY: textView.textContainerOrigin.y,
            scrollOffsetY: textView.visibleRect.origin.y,
            baselineOffset: fixedBaseline ?? (textView.font ?? NSFont.systemFont(ofSize: 13)).ascender,
            gutterWidth: gutterWidth
        )

        let nsString = textView.string as NSString
        let glyphCount = layoutManager.numberOfGlyphs
        if glyphCount == 0 || nsString.length == 0 {
            drawLabel(1, atFragmentMinY: 0, context: context)
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        var visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        if visibleGlyphRange.location == NSNotFound {
            visibleGlyphRange = NSRange(location: 0, length: glyphCount)
        }
        let firstGlyph = min(visibleGlyphRange.location, max(glyphCount - 1, 0))
        let endGlyph = min(NSMaxRange(visibleGlyphRange), glyphCount)
        guard endGlyph > firstGlyph else {
            drawLabel(1, atFragmentMinY: 0, context: context)
            return
        }

        // Count lines once for the first visible fragment, then step: counting from the top of
        // the script for every fragment made long scripts slow to scroll.
        var lineNumber = nsString.lineNumber(at: layoutManager.characterIndexForGlyph(at: firstGlyph))
        var glyphIndex = firstGlyph
        var isFirstFragment = true
        while glyphIndex < endGlyph {
            var fragmentGlyphs = NSRange(location: 0, length: 0)
            let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &fragmentGlyphs, withoutAdditionalLayout: true)
            let characterIndex = layoutManager.characterIndexForGlyph(at: fragmentGlyphs.location)
            let startsLine = Self.startsLogicalLine(characterIndex, in: nsString)
            if startsLine && !isFirstFragment {
                lineNumber += 1
            }
            // One number per logical line: wrapped continuations stay blank.
            if startsLine {
                drawLabel(lineNumber, atFragmentMinY: fragmentRect.minY, context: context)
            }
            isFirstFragment = false
            let next = NSMaxRange(fragmentGlyphs)
            if next <= glyphIndex { break }
            glyphIndex = next
        }

        // The empty line after a final newline.
        if layoutManager.extraLineFragmentTextContainer != nil {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                drawLabel(nsString.lineNumber(at: nsString.length), atFragmentMinY: extraRect.minY, context: context)
            }
        }
    }

    /// Whether the character at `index` begins a line (rather than continuing a wrapped one).
    static func startsLogicalLine(_ index: Int, in string: NSString) -> Bool {
        guard index > 0, index <= string.length else { return true }
        let previous = string.character(at: index - 1)
        return previous == 10 || previous == 13
    }

    private struct LabelContext {
        let containerOriginY: CGFloat
        let scrollOffsetY: CGFloat
        let baselineOffset: CGFloat
        let gutterWidth: CGFloat
    }

    /// Column: a faint full-height column in the theme's gutter colour with an edge towards the
    /// text; the card's rounded corners cut it. Lane: the same colour as a rounded, inset lane.
    private func drawBackground(width: CGFloat) {
        switch gutterStyle {
        case .subtle:
            return
        case .tinted:
            theme.surfaces.gutterBackground.nsColor.setFill()
            NSRect(x: 0, y: bounds.minY, width: width, height: bounds.height).fill()
            NSColor.separatorColor.setFill()
            NSRect(x: width - LayoutTokens.EditorGutter.edgeWidth, y: bounds.minY, width: LayoutTokens.EditorGutter.edgeWidth, height: bounds.height).fill()
        case .lane:
            let inset = LayoutTokens.EditorGutter.laneInset
            let lane = NSRect(x: inset, y: bounds.minY + inset, width: max(width - inset * 2, 0), height: max(bounds.height - inset * 2, 0))
            let radius = LayoutTokens.EditorGutter.laneCornerRadius
            theme.surfaces.gutterBackground.nsColor.setFill()
            NSBezierPath(roundedRect: lane, xRadius: radius, yRadius: radius).fill()
        }
    }

    private func drawLabel(_ lineNumber: Int, atFragmentMinY fragmentMinY: CGFloat, context: LabelContext) {
        let isCurrent = highlightedLines.contains(lineNumber)
        let font = isCurrent ? Self.currentNumberFont : Self.numberFont
        let color = isCurrent ? theme.surfaces.gutterAccent.nsColor : theme.surfaces.gutterText.nsColor
        let labelHeight = ceil(font.ascender - font.descender + font.leading)
        let baselineY = fragmentMinY + context.baselineOffset + context.containerOriginY - context.scrollOffsetY
        let labelY = baselineY - font.ascender
        let labelRect = NSRect(x: 0, y: labelY, width: context.gutterWidth - LayoutTokens.EditorGutter.numberTrailing, height: labelHeight)
        ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])

        if errorLines.contains(lineNumber) {
            let size = LayoutTokens.EditorGutter.markerSize
            let dot = NSRect(x: LayoutTokens.EditorGutter.markerLeading, y: labelY + (labelHeight - size) / 2, width: size, height: size)
            NSColor(ColorTokens.Status.error).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard point.x <= ruleThickness else { return nil }
        return super.hitTest(point)
    }

    private var anchorLine: Int?

    override func mouseDown(with event: NSEvent) {
        guard let line = lineAtEvent(event) else { return }
        anchorLine = line
        sqlTextView?.selectLineRange(line...line)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor = anchorLine, let line = lineAtEvent(event) else { return }
        let range = min(anchor, line)...max(anchor, line)
        sqlTextView?.selectLineRange(range)
    }

    override func mouseUp(with event: NSEvent) {
        anchorLine = nil
    }

    private func lineAtEvent(_ event: NSEvent) -> Int? {
        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        let glyphCount = layoutManager.numberOfGlyphs
        guard glyphCount > 0 else { return nil }

        let location = convert(event.locationInWindow, from: nil)
        let pointInTextView = convert(location, to: textView)
        var fraction: CGFloat = 0
        var glyphIndex = layoutManager.glyphIndex(for: pointInTextView, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        glyphIndex = min(max(glyphIndex, 0), glyphCount - 1)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        return (textView.string as NSString).lineNumber(at: charIndex)
    }
}

#endif
