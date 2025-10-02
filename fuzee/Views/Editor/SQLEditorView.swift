import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SQLEditorSelection: Equatable {
    let selectedText: String
    let range: NSRange
    let lineRange: ClosedRange<Int>?

    var hasSelection: Bool { !selectedText.isEmpty }
}

struct SQLEditorView: View {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void

    init(
        text: Binding<String>,
        theme: SQLEditorTheme,
        display: SQLEditorDisplayOptions,
        onSelectionChange: @escaping (SQLEditorSelection) -> Void,
        onSelectionPreviewChange: @escaping (SQLEditorSelection) -> Void
    ) {
        _text = text
        self.theme = theme
        self.display = display
        self.onSelectionChange = onSelectionChange
        self.onSelectionPreviewChange = onSelectionPreviewChange
    }

    var body: some View {
#if os(macOS)
        MacSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange
        )
#else
        IOSSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange
        )
#endif
    }
}

#if os(macOS)
private struct MacSQLEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> SQLScrollView {
        let scrollView = SQLScrollView(theme: theme, display: display)
        let textView = scrollView.sqlTextView
        textView.sqlDelegate = context.coordinator
        textView.string = text
        textView.reapplyHighlighting()
        context.coordinator.textView = textView

        // Make first responder once after attachment
        DispatchQueue.main.async { [weak textView, weak scrollView] in
            guard let tv = textView else { return }
            scrollView?.window?.makeFirstResponder(tv)
        }
        return scrollView
    }

    func updateNSView(_ nsView: SQLScrollView, context: Context) {
        nsView.updateTheme(theme)
        nsView.updateDisplay(display)
        let textView = nsView.sqlTextView
        context.coordinator.theme = theme

        // Update binding -> editor content without stealing focus or resetting selection unnecessarily
        if textView.string != text {
            context.coordinator.isUpdatingFromBinding = true
            let currentSelection = textView.selectedRange()
            textView.string = text
            textView.reapplyHighlighting()
            // Try to restore selection if still valid
            let maxLen = (text as NSString).length
            let restored = NSRange(
                location: min(currentSelection.location, max(0, maxLen)),
                length: min(currentSelection.length, max(0, maxLen - min(currentSelection.location, maxLen)))
            )
            textView.setSelectedRange(restored)
            context.coordinator.isUpdatingFromBinding = false
        }

        // Update text container width only if the available width changed
        DispatchQueue.main.async {
            let scrollViewWidth = nsView.bounds.width
            let rulerWidth = nsView.verticalRulerView?.ruleThickness ?? 0
            let availableWidth = max(scrollViewWidth - rulerWidth, 320)

            if let textContainer = textView.textContainer {
                if nsView.currentDisplayOptions.wrapLines {
                    if textContainer.size.width != availableWidth {
                        textContainer.size = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
                    }
                } else {
                    textContainer.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                }
            }
        }
    }

    final class Coordinator: NSObject, SQLTextViewDelegate {
        var parent: MacSQLEditorRepresentable
        weak var textView: SQLTextView?
        var theme: SQLEditorTheme
        var isUpdatingFromBinding = false

        init(parent: MacSQLEditorRepresentable) {
            self.parent = parent
            self.theme = parent.theme
        }

        func sqlTextView(_ view: SQLTextView, didUpdateText text: String) {
            guard !isUpdatingFromBinding else { return }
            parent.text = text
        }

        func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection) {
            parent.onSelectionChange(selection)
        }

        func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {
            parent.onSelectionPreviewChange(selection)
        }
    }
}

private protocol SQLTextViewDelegate: AnyObject {
    func sqlTextView(_ view: SQLTextView, didUpdateText text: String)
    func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection)
}

extension SQLTextViewDelegate {
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {}
}

private final class SQLScrollView: NSScrollView {
    let sqlTextView: SQLTextView
    private var theme: SQLEditorTheme
    private var displayOptions: SQLEditorDisplayOptions
    private let lineNumberRuler: LineNumberRulerView

    var currentDisplayOptions: SQLEditorDisplayOptions { displayOptions }

    init(theme: SQLEditorTheme, display: SQLEditorDisplayOptions) {
        self.displayOptions = display
        self.sqlTextView = SQLTextView(theme: theme, displayOptions: display)
        self.lineNumberRuler = LineNumberRulerView(textView: sqlTextView, theme: theme)
        self.theme = theme
        super.init(frame: .zero)
        drawsBackground = false
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.masksToBounds = false
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        autoresizesSubviews = true
        documentView = sqlTextView
        scrollerStyle = .overlay
        verticalScrollElasticity = .automatic

        sqlTextView.minSize = NSSize(width: 0, height: 320)
        sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        sqlTextView.isVerticallyResizable = true
        sqlTextView.isHorizontallyResizable = false
        sqlTextView.autoresizingMask = [.width]

        hasVerticalRuler = true
        rulersVisible = true
        verticalRulerView = lineNumberRuler

        if let textContainer = sqlTextView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 10
        }

        sqlTextView.setFrameSize(NSSize(width: 800, height: 360))
        lineNumberRuler.needsDisplay = true
        applyTheme()
        applyDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTheme(_ theme: SQLEditorTheme) {
        self.theme = theme
        applyTheme()
    }

    func updateDisplay(_ options: SQLEditorDisplayOptions) {
        displayOptions = options
        sqlTextView.displayOptions = options
        applyDisplay()
    }

    private func applyTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        sqlTextView.theme = theme
        lineNumberRuler.theme = theme
    }

    private func applyDisplay() {
        sqlTextView.displayOptions = displayOptions

        if displayOptions.wrapLines {
            hasHorizontalScroller = false
            autohidesScrollers = true
            sqlTextView.isHorizontallyResizable = false
            sqlTextView.textContainer?.widthTracksTextView = true
        } else {
            hasHorizontalScroller = true
            autohidesScrollers = false
            sqlTextView.isHorizontallyResizable = true
            sqlTextView.textContainer?.widthTracksTextView = false
            sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        if displayOptions.showLineNumbers {
            hasVerticalRuler = true
            rulersVisible = true
            verticalRulerView = lineNumberRuler
            lineNumberRuler.theme = theme
            lineNumberRuler.sqlTextView = sqlTextView
            lineNumberRuler.needsDisplay = true
        } else {
            hasVerticalRuler = false
            verticalRulerView = nil
        }
    }
}

private func sqlRangeIsValid(_ range: NSRange, upperBound: Int) -> Bool {
    guard range.location >= 0, range.length >= 0 else { return false }
    guard upperBound >= 0 else { return false }
    if range.length == 0 {
        return range.location <= upperBound
    }
    guard upperBound > 0 else { return false }
    guard range.location < upperBound else { return false }
    return NSMaxRange(range) <= upperBound
}

private final class SQLTextView: NSTextView, NSTextViewDelegate {
    weak var sqlDelegate: SQLTextViewDelegate?
    var theme: SQLEditorTheme { didSet { applyTheme() } }
    var displayOptions: SQLEditorDisplayOptions { didSet { applyDisplayOptions() } }

    private weak var lineNumberRuler: LineNumberRulerView?
    private var paragraphStyle = NSMutableParagraphStyle()

    init(theme: SQLEditorTheme, displayOptions: SQLEditorDisplayOptions) {
        self.theme = theme
        self.displayOptions = displayOptions

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude))

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 360), textContainer: textContainer)

        isEditable = true
        isSelectable = true
        isRichText = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isGrammarCheckingEnabled = false
        usesAdaptiveColorMappingForDarkAppearance = true
        textContainerInset = NSSize(width: 12, height: 24)
        allowsUndo = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 320)
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]

        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 14

        configureDelegates()
        applyTheme()
        applyDisplayOptions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(ruler: LineNumberRulerView) { lineNumberRuler = ruler }

    private func configureDelegates() {
        delegate = self
    }

    private func applyTheme() {
        font = theme.nsFont
        textColor = theme.tokenColors.plain.nsColor
        insertionPointColor = theme.tokenColors.operatorSymbol.nsColor
        drawsBackground = true
        backgroundColor = theme.palette.background.nsColor
        updateParagraphStyle()
        lineNumberRuler?.theme = theme
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let ruler = enclosingScrollView?.verticalRulerView as? LineNumberRulerView {
            configure(ruler: ruler)
            ruler.sqlTextView = self
        }
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        notifySelectionPreview()
    }

    func reapplyHighlighting() {}

    override func didChangeText() {
        super.didChangeText()
        sqlDelegate?.sqlTextView(self, didUpdateText: string)
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        notifySelectionChanged()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        notifySelectionChanged()
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        notifySelectionPreview()
    }

    private func notifySelectionChanged() {
        let range = selectedRange()
        let nsString = string as NSString
        let selected = (range.length > 0 && range.location != NSNotFound) ? nsString.substring(with: range) : ""
        let lines = selectedLines(for: range)
        let selection = SQLEditorSelection(selectedText: selected, range: range, lineRange: lines)
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        sqlDelegate?.sqlTextView(self, didChangeSelection: selection)
    }

    private func notifySelectionPreview() {
        let range = selectedRange()
        let nsString = string as NSString
        let selected = (range.length > 0 && range.location != NSNotFound) ? nsString.substring(with: range) : ""
        let lines = selectedLines(for: range)
        let selection = SQLEditorSelection(selectedText: selected, range: range, lineRange: lines)
        sqlDelegate?.sqlTextView(self, didPreviewSelection: selection)
    }

    private func selectedLines(for range: NSRange) -> ClosedRange<Int>? {
        guard range.length > 0 else { return nil }
        let nsString = string as NSString
        let startLine = nsString.lineNumber(at: range.location)
        let endLine = nsString.lineNumber(at: range.location + range.length)
        return startLine...max(startLine, endLine)
    }

    func selectedLineRange() -> IndexSet {
        let range = selectedRange()
        if range.length > 0, let lines = selectedLines(for: range) {
            return IndexSet(integersIn: lines)
        }
        guard range.location != NSNotFound else { return [] }
        let caretLine = (string as NSString).lineNumber(at: range.location)
        return IndexSet(integer: caretLine)
    }

    private func applyDisplayOptions() {
        updateParagraphStyle()
        textContainer?.widthTracksTextView = displayOptions.wrapLines
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    private func updateParagraphStyle() {
        let style = paragraphStyle(for: theme, display: displayOptions)
        paragraphStyle = style
        defaultParagraphStyle = style

        typingAttributes = [
            .font: theme.nsFont,
            .foregroundColor: theme.tokenColors.plain.nsColor,
            .paragraphStyle: style
        ]

        selectedTextAttributes = [
            .backgroundColor: theme.palette.selection.nsColor.withAlphaComponent(0.3),
            .foregroundColor: theme.tokenColors.plain.nsColor,
            .paragraphStyle: style
        ]

        if let textStorage = textStorage {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.paragraphStyle, value: style, range: fullRange)
        }

    }

    override func scrollRangeToVisible(_ charRange: NSRange) {
        let length = (string as NSString).length
        let clamped = makeSafeRange(charRange, documentLength: max(length, 0))
        guard sqlRangeIsValid(clamped, upperBound: max(length, 0)) || (length == 0 && clamped.location == 0) else { return }
        super.scrollRangeToVisible(clamped)
    }

    override func setSelectedRange(_ charRange: NSRange) {
        let length = (string as NSString).length
        let clamped = makeSafeRange(charRange, documentLength: length)
        if sqlRangeIsValid(clamped, upperBound: max(length, 0)) || (length == 0 && clamped.location == 0) {
            super.setSelectedRange(clamped)
        }
    }

    private func paragraphStyle(for theme: SQLEditorTheme, display: SQLEditorDisplayOptions) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let baseline: CGFloat
        if let layout = layoutManager {
            baseline = layout.defaultLineHeight(for: theme.nsFont)
        } else {
            baseline = theme.nsFont.ascender - theme.nsFont.descender + theme.nsFont.leading
        }
        let lineHeight = baseline * theme.lineHeightMultiplier
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.lineBreakMode = display.wrapLines ? .byWordWrapping : .byClipping
        style.tabStops = []
        style.defaultTabInterval = theme.nsFont.pointSize * 1.6
        style.paragraphSpacing = 4
        let indentSpaces = display.wrapLines ? display.indentWrappedLines : 0
        style.headIndent = indentWidth(for: indentSpaces)
        style.firstLineHeadIndent = 0
        return style
    }

    private func indentWidth(for spaces: Int) -> CGFloat {
        guard spaces > 0 else { return 0 }
        let sample = String(repeating: " ", count: max(1, spaces))
        let size = (sample as NSString).size(withAttributes: [.font: theme.nsFont])
        return size.width
    }

    private func makeSafeRange(_ range: NSRange, documentLength length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }

        if range.length == 0 {
            let location = min(max(range.location, 0), length)
            return NSRange(location: location, length: 0)
        }

        let location = min(max(range.location, 0), max(length - 1, 0))
        let available = max(0, length - location)
        let safeLength = min(max(range.length, 0), available)
        return NSRange(location: location, length: safeLength)
    }

    private func clampSelectionRange(_ range: NSRange) -> NSRange {
        let length = (string as NSString).length
        return makeSafeRange(range, documentLength: length)
    }

    private func clampRangeForScrolling(_ range: NSRange) -> NSRange {
        let length = (string as NSString).length
        if length == 0 { return NSRange(location: 0, length: 0) }
        return makeSafeRange(range, documentLength: length)
    }
}
private final class LineNumberRulerView: NSRulerView {
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
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        theme.palette.gutterBackground.nsColor.setFill()
        rect.fill()

        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: theme.palette.gutterText.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        let glyphCount = layoutManager.numberOfGlyphs
        let nsString = textView.string as NSString

        if glyphCount == 0 || nsString.length == 0 {
            drawFallbackLine(with: attributes, in: rect)
            return
        }

        var visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        if visibleGlyphRange.location == NSNotFound {
            visibleGlyphRange = NSRange(location: 0, length: glyphCount)
        }

        let initialGlyph = min(visibleGlyphRange.location, max(glyphCount - 1, 0))
        let maxGlyphIndex = min(NSMaxRange(visibleGlyphRange), glyphCount)
        if maxGlyphIndex <= initialGlyph {
            drawFallbackLine(with: attributes, in: rect)
            return
        }

        let initialCharIndex = layoutManager.characterIndexForGlyph(at: initialGlyph)
        var currentLine = nsString.lineNumber(at: min(initialCharIndex, max(nsString.length - 1, 0)))

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let yPosition = lineRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y

            let labelRect = NSRect(x: 0, y: yPosition + 2, width: bounds.width - 6, height: lineRect.height)
            ("\(currentLine)" as NSString).draw(in: labelRect, withAttributes: attributes)

            glyphIndex = min(NSMaxRange(lineRange), maxGlyphIndex)
            currentLine += 1
        }

        // No divider – match Tahoe preview
    }

    private func drawFallbackLine(with attributes: [NSAttributedString.Key: Any], in rect: NSRect) {
        let labelRect = NSRect(x: 0, y: rect.minY + 4, width: bounds.width - 6, height: rect.height)
        ("1" as NSString).draw(in: labelRect, withAttributes: attributes)
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

private extension SQLTextView {
    func selectLineRange(_ range: ClosedRange<Int>) {
        let nsString = string as NSString
        let startLocation = nsString.locationOfLine(range.lowerBound)
        let endLocation = nsString.endLocationOfLine(range.upperBound)
        let selectionRange = NSRange(location: startLocation, length: endLocation - startLocation)
        setSelectedRange(selectionRange)
        scrollRangeToVisible(selectionRange)
    }
}

private extension NSString {
    func lineNumber(at index: Int) -> Int {
        let clamped = max(0, min(index, length))
        var line = 1
        if clamped == 0 { return line }
        enumerateSubstrings(in: NSRange(location: 0, length: clamped), options: [.byLines, .substringNotRequired]) { _, range, _, stop in
            if NSMaxRange(range) >= clamped {
                stop.pointee = true
            } else {
                line += 1
            }
        }
        return line
    }

    func locationOfLine(_ number: Int) -> Int {
        guard number > 1 else { return 0 }
        var current = 1
        var location = 0
        enumerateSubstrings(in: NSRange(location: 0, length: length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if current == number {
                location = substringRange.location
                stop.pointee = true
            }
            current += 1
        }
        return location
    }

    func endLocationOfLine(_ number: Int) -> Int {
        guard number > 0 else { return 0 }
        var current = 1
        var location = length
        enumerateSubstrings(in: NSRange(location: 0, length: length), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if current == number {
                location = NSMaxRange(substringRange)
                stop.pointee = true
            }
            current += 1
        }
        return location
    }
}

#else
// Simplified iOS/iPadOS implementation using UITextView
private struct IOSSQLEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = theme.uiFont
        textView.textColor = theme.tokenColors.plain.uiColor
        textView.backgroundColor = theme.palette.background.uiColor
        textView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.delegate = context.coordinator
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.textContainer.widthTracksTextView = display.wrapLines
        textView.textContainer.lineFragmentPadding = 12
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = theme.uiFont
        uiView.textColor = theme.tokenColors.plain.uiColor
        uiView.backgroundColor = theme.palette.background.uiColor
        uiView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        uiView.textContainer.widthTracksTextView = display.wrapLines
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: IOSSQLEditorRepresentable

        init(parent: IOSSQLEditorRepresentable) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let selection = textView.selectedRange
            let selected = (selection.length > 0) ? (textView.text as NSString).substring(with: selection) : ""
            let lineRange: ClosedRange<Int>? = nil
            let selectionInfo = SQLEditorSelection(selectedText: selected, range: selection, lineRange: lineRange)
            parent.onSelectionPreviewChange(selectionInfo)
            parent.onSelectionChange(selectionInfo)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            textViewDidChangeSelection(textView)
        }
    }
}
#endif
