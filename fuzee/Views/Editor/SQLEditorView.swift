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
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void

    init(
        text: Binding<String>,
        theme: SQLEditorTheme,
        onSelectionChange: @escaping (SQLEditorSelection) -> Void,
        onSelectionPreviewChange: @escaping (SQLEditorSelection) -> Void
    ) {
        _text = text
        self.theme = theme
        self.onSelectionChange = onSelectionChange
        self.onSelectionPreviewChange = onSelectionPreviewChange
    }

    var body: some View {
    #if os(macOS)
        MacSQLEditorRepresentable(
            text: $text,
            theme: theme,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange
        )
#else
        IOSSQLEditorRepresentable(
            text: $text,
            theme: theme,
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
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> SQLScrollView {
        let scrollView = SQLScrollView(theme: theme)
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
        let textView = nsView.sqlTextView
        textView.theme = theme
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
                if textContainer.size.width != availableWidth {
                    textContainer.size = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
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

    init(theme: SQLEditorTheme) {
        self.sqlTextView = SQLTextView(theme: theme)
        super.init(frame: .zero)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        autoresizesSubviews = true
        backgroundColor = .clear
        documentView = sqlTextView

        sqlTextView.minSize = NSSize(width: 0, height: 320)
        sqlTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        sqlTextView.isVerticallyResizable = true
        sqlTextView.isHorizontallyResizable = false
        sqlTextView.autoresizingMask = [.width]

        hasVerticalRuler = true
        rulersVisible = true
        let ruler = LineNumberRulerView(textView: sqlTextView)
        verticalRulerView = ruler

        if let textContainer = sqlTextView.textContainer {
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
        }

        sqlTextView.setFrameSize(NSSize(width: 800, height: 360))
        ruler.needsDisplay = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SQLTextView: NSTextView, NSTextViewDelegate {
    weak var sqlDelegate: SQLTextViewDelegate?
    var theme: SQLEditorTheme { didSet { applyTheme() } }

    private let highlighter: SQLSyntaxHighlighter
    private weak var lineNumberRuler: LineNumberRulerView?

    init(theme: SQLEditorTheme) {
        self.theme = theme
        self.highlighter = SQLSyntaxHighlighter(theme: theme)

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
        textContainerInset = NSSize(width: 18, height: 20)
        allowsUndo = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 320)
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]

        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 18

        delegatesSetup()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(ruler: LineNumberRulerView) { lineNumberRuler = ruler }

    private func delegatesSetup() {
        delegate = self
        textStorage?.delegate = highlighter
        highlighter.textView = self
    }

    private func applyTheme() {
        let background = NSColor.textBackgroundColor
        font = theme.nsFont
        textColor = theme.tokenColors.plain.nsColor
        insertionPointColor = theme.tokenColors.plain.nsColor
        drawsBackground = true
        backgroundColor = background
        typingAttributes = [
            .font: theme.nsFont,
            .foregroundColor: theme.tokenColors.plain.nsColor
        ]
        highlighter.theme = theme
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let ruler = enclosingScrollView?.verticalRulerView as? LineNumberRulerView {
            configure(ruler: ruler)
            ruler.sqlTextView = self
        }
        // Make first responder once on attach
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        notifySelectionPreview()
    }

    func reapplyHighlighting() {
        highlighter.applyHighlighting(to: textStorage)
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    override func didChangeText() {
        super.didChangeText()
        // Do not call highlighting here; textStorage delegate will handle it
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
        guard let lines = selectedLines(for: selectedRange()) else { return [] }
        return IndexSet(integersIn: lines)
    }
}

private final class LineNumberRulerView: NSRulerView {
    weak var sqlTextView: SQLTextView?
    var highlightedLines: IndexSet = []

    private let paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        return style
    }()

    init(textView: SQLTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.sqlTextView = textView
        self.clientView = textView
        self.ruleThickness = 52
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let nsString = textView.string as NSString
        var currentLine = nsString.lineNumber(at: layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location))

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        var glyphIndex = visibleGlyphRange.location
        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let yPosition = lineRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y

            if highlightedLines.contains(currentLine) {
                NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                NSRect(x: 0, y: yPosition, width: bounds.width, height: lineRect.height).fill()
            }

            let labelRect = NSRect(x: 0, y: yPosition, width: bounds.width - 6, height: lineRect.height)
            ("\(currentLine)" as NSString).draw(in: labelRect, withAttributes: attributes)

            glyphIndex = NSMaxRange(lineRange)
            currentLine += 1
        }
    }

    override func mouseDown(with event: NSEvent) { selectLine(event) }
    override func mouseDragged(with event: NSEvent) { selectLine(event) }

    private func selectLine(_ event: NSEvent) {
        guard let textView = sqlTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let location = convert(event.locationInWindow, from: nil)
        let pointInTextView = convert(location, to: textView)
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: pointInTextView, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
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

private final class SQLSyntaxHighlighter: NSObject, NSTextStorageDelegate {
    var theme: SQLEditorTheme
    private var isHighlighting = false
    weak var textView: NSTextView?

    init(theme: SQLEditorTheme) {
        self.theme = theme
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard !isHighlighting else { return }
        guard editedMask.contains(.editedCharacters) else { return }
        applyHighlighting(to: textStorage)
    }

    func applyHighlighting(to textStorage: NSTextStorage?) {
        guard let textStorage else { return }
        isHighlighting = true

        // Preserve selection and typing attributes
        let currentSelection = textView?.selectedRange() ?? NSRange(location: NSNotFound, length: 0)
        let currentTypingAttributes = textView?.typingAttributes

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: theme.nsFont,
            .foregroundColor: theme.tokenColors.plain.nsColor
        ], range: fullRange)

        highlight(pattern: #"--.*"#, in: textStorage, color: theme.tokenColors.comment.nsColor)
        highlight(pattern: #"/\*[^*]*\*+(?:[^/*][^*]*\*+)*/"#, in: textStorage, color: theme.tokenColors.comment.nsColor)
        highlight(pattern: #"'[^']*'"#, in: textStorage, color: theme.tokenColors.string.nsColor)
        highlight(pattern: #"\"[^\"]*\""#, in: textStorage, color: theme.tokenColors.string.nsColor)
        highlight(pattern: #"\b[0-9]+(?:\.[0-9]+)?\b"#, in: textStorage, color: theme.tokenColors.number.nsColor)
        highlightKeywords(in: textStorage)

        textStorage.endEditing()

        // Restore typing attributes and selection
        if let attrs = currentTypingAttributes {
            textView?.typingAttributes = attrs
        }
        if currentSelection.location != NSNotFound {
            textView?.setSelectedRange(currentSelection)
        }

        isHighlighting = false
    }

    private func highlight(pattern: String, in textStorage: NSTextStorage, color: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let string = textStorage.string
        let range = NSRange(location: 0, length: (string as NSString).length)
        regex.enumerateMatches(in: string, options: [], range: range) { result, _, _ in
            guard let result else { return }
            textStorage.addAttributes([
                .foregroundColor: color
            ], range: result.range)
        }
    }

    private func highlightKeywords(in textStorage: NSTextStorage) {
        let keywords = "SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|GROUP|BY|ORDER|LIMIT|OFFSET|JOIN|INNER|LEFT|RIGHT|FULL|ON|AS|DISTINCT|AND|OR|NOT|BETWEEN|IN|IS|NULL|LIKE|HAVING|CREATE|ALTER|DROP|TABLE|VIEW|INDEX|TRIGGER|FUNCTION|RETURNING|WITH|EXISTS|UNION"
        guard let regex = try? NSRegularExpression(pattern: #"\b(?:\#(keywords))\b"#, options: [.caseInsensitive]) else { return }
        let string = textStorage.string
        let range = NSRange(location: 0, length: (string as NSString).length)
        regex.enumerateMatches(in: string, options: [], range: range) { result, _, _ in
            guard let result else { return }
            textStorage.addAttributes([
                .foregroundColor: theme.tokenColors.keyword.nsColor,
                .font: theme.nsFont
            ], range: result.range)
        }
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
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = theme.uiFont
        textView.textColor = theme.tokenColors.plain.uiColor
        textView.backgroundColor = .systemBackground
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.delegate = context.coordinator
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = theme.uiFont
        uiView.textColor = theme.tokenColors.plain.uiColor
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
