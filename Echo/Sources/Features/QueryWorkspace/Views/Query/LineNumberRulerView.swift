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
    /// The first line of the statement at the caret, which gets a Run arrow (QE1).
    var runArrowLine: Int? {
        didSet { if oldValue != runArrowLine { needsDisplay = true } }
    }
    /// Runs the statement at the caret when its arrow is clicked.
    var onRunStatement: (() -> Void)?
    /// Where the Run arrow was last drawn, for clicks.
    var runArrowRect: NSRect?
    /// Round 28.4: the lines of the statement at the caret, marked with a bracket.
    var statementLines: ClosedRange<Int>? {
        didSet { if oldValue != statementLines { needsDisplay = true } }
    }
    /// Round 21 SK2, round 28.4 SR1: the selected script result's statement, a solid bracket.
    var resultStatementLines: ClosedRange<Int>? {
        didSet { if oldValue != resultStatementLines { needsDisplay = true } }
    }
    /// Round 28.7: the lines running now (RR1) and the lines that just ran (H9), with their layers.
    var runningLines: ClosedRange<Int>?
    var ranLines: ClosedRange<Int>?
    var runningLayer: CALayer?
    var ranLayer: CALayer?
    /// Round 28.4 A1: the arrow is grey until the pointer is on it.
    private var isHoveringRunArrow = false {
        didSet { if oldValue != isHoveringRunArrow { needsDisplay = true } }
    }
    /// Subtle (numbers only), a tinted column with an edge, or a tinted inset lane, from Settings.
    var gutterStyle: EditorGutterStyle = .subtle {
        didSet { if oldValue != gutterStyle { needsDisplay = true } }
    }
    var theme: SQLEditorTheme {
        didSet {
            guard oldValue.fontSize != theme.fontSize else { needsDisplay = true; return }
            sizedDigitCount = 0
            updateThickness()
            needsDisplay = true
        }
    }
    /// Digits the gutter is currently sized for; it widens as the script grows.
    private var sizedDigitCount = 0

    private let paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }()
    private let centredStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }()

    init(textView: SQLTextView, theme: SQLEditorTheme) {
        self.theme = theme
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.sqlTextView = textView
        self.clientView = textView
        self.ruleThickness = Self.thickness(forDigits: LayoutTokens.EditorGutter.minimumDigits, codeSize: theme.fontSize)
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
        ruleThickness = Self.thickness(forDigits: digits, codeSize: theme.fontSize)
    }

    /// Round 28.2 N1: SF digits 2pt under the code, so the numbers follow the font size.
    static func numberFont(forCodeSize size: CGFloat) -> NSFont {
        .monospacedDigitSystemFont(ofSize: max(size - 2, 8), weight: .regular)
    }

    private var numberFont: NSFont { Self.numberFont(forCodeSize: theme.fontSize) }

    /// Room for the error dot, the digits, and the gap before the text.
    static func thickness(forDigits digits: Int, codeSize: CGFloat = SQLEditorTheme.defaultFontSize) -> CGFloat {
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: numberFont(forCodeSize: codeSize)]).width
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
        runArrowRect = nil
        drawHashMarksAndLabels(in: dirtyRect)
    }

    /// QE1: a small triangle at the leading edge of the statement's first line; round 28.4 A1:
    /// grey, in the accent while the pointer is on it.
    private func drawRunArrow(labelY: CGFloat, labelHeight: CGFloat) {
        let size = LayoutTokens.EditorGutter.runArrowSize
        let rect = NSRect(x: LayoutTokens.EditorGutter.markerLeading, y: labelY + (labelHeight - size) / 2, width: size * 0.85, height: size)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.close()
        (isHoveringRunArrow ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor).setFill()
        path.fill()
        runArrowRect = rect
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        let gutterWidth = max(0, ruleThickness)

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

        var brackets = StatementBrackets(focused: statementLines, result: resultStatementLines, running: runningLines, ran: ranLines)
        defer {
            let numbersRight = gutterWidth - LayoutTokens.EditorGutter.numberTrailing
            brackets.draw(numbersRight: numbersRight, context: context)
            placeRunMarks(brackets, numbersRight: numbersRight, context: context)
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
            brackets.include(line: lineNumber, fragment: fragmentRect)
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
                brackets.include(line: nsString.lineNumber(at: nsString.length), fragment: extraRect)
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

    struct LabelContext {
        let containerOriginY: CGFloat
        let scrollOffsetY: CGFloat
        let baselineOffset: CGFloat
        let gutterWidth: CGFloat
    }


    private func drawLabel(_ lineNumber: Int, atFragmentMinY fragmentMinY: CGFloat, context: LabelContext) {
        // Round 28.2: the caret's number in the text colour (K1), the others tertiary (C1), one weight.
        let isCurrent = highlightedLines.contains(lineNumber)
        let font = numberFont
        let color: NSColor = isCurrent ? .labelColor : .tertiaryLabelColor
        let labelHeight = ceil(font.ascender - font.descender + font.leading)
        let baselineY = fragmentMinY + context.baselineOffset + context.containerOriginY - context.scrollOffsetY
        let labelY = baselineY - font.ascender
        // Round 28.14 (LA1): on the lane, the numbers sit in its middle; otherwise right-aligned.
        let inset = LayoutTokens.EditorGutter.laneInset
        let labelRect = gutterStyle == .lane
            ? NSRect(x: inset, y: labelY, width: max(context.gutterWidth - inset * 2, 0), height: labelHeight)
            : NSRect(x: 0, y: labelY, width: context.gutterWidth - LayoutTokens.EditorGutter.numberTrailing, height: labelHeight)
        ("\(lineNumber)" as NSString).draw(in: labelRect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: gutterStyle == .lane ? centredStyle : paragraphStyle
        ])

        if lineNumber == runArrowLine, !errorLines.contains(lineNumber) {
            drawRunArrow(labelY: labelY, labelHeight: labelHeight)
        }
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isHoveringRunArrow = runArrowRect?.insetBy(dx: -LayoutTokens.EditorGutter.markerSpacing, dy: -LayoutTokens.EditorGutter.markerSpacing).contains(point) ?? false
    }

    override func mouseExited(with event: NSEvent) {
        isHoveringRunArrow = false
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let runArrowRect, runArrowRect.insetBy(dx: -LayoutTokens.EditorGutter.markerSpacing, dy: -LayoutTokens.EditorGutter.markerSpacing).contains(point) {
            onRunStatement?()
            return
        }
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
