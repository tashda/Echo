import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum SQLEditorRegex {
    static let doubleQuotedStringPattern = #""(?:""|[^"])*""#
    static let doubleQuotedStringRegex = try! NSRegularExpression(
        pattern: doubleQuotedStringPattern,
        options: []
    )
}

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
    var backgroundColor: Color?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata

    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    init(
        text: Binding<String>,
        theme: SQLEditorTheme,
        display: SQLEditorDisplayOptions,
        backgroundColor: Color? = nil,
        onTextChange: @escaping (String) -> Void,
        onSelectionChange: @escaping (SQLEditorSelection) -> Void,
        onSelectionPreviewChange: @escaping (SQLEditorSelection) -> Void,
        clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    ) {
        _text = text
        self.theme = theme
        self.display = display
        self.backgroundColor = backgroundColor
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onSelectionPreviewChange = onSelectionPreviewChange
        self.clipboardMetadata = clipboardMetadata
    }

    var body: some View {
#if os(macOS)
        MacSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            backgroundColor: backgroundColor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange,
            clipboardHistory: clipboardHistory,
            clipboardMetadata: clipboardMetadata
        )
#else
        IOSSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            backgroundColor: backgroundColor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange,
            clipboardHistory: clipboardHistory,
            clipboardMetadata: clipboardMetadata
        )
#endif
    }
}

#if os(macOS)
private struct MacSQLEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardHistory: ClipboardHistoryStore
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> SQLScrollView {
        let scrollView = SQLScrollView(
            theme: theme,
            display: display,
            backgroundOverride: backgroundColor.map(NSColor.init)
        )
        let textView = scrollView.sqlTextView
        textView.sqlDelegate = context.coordinator
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata
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
        nsView.updateBackgroundOverride(backgroundColor.map(NSColor.init))
        let textView = nsView.sqlTextView
        context.coordinator.theme = theme
        context.coordinator.parent = self
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata

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
            parent.onTextChange(text)
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
    private var backgroundOverride: NSColor?

    var currentDisplayOptions: SQLEditorDisplayOptions { displayOptions }

    init(theme: SQLEditorTheme, display: SQLEditorDisplayOptions, backgroundOverride: NSColor?) {
        self.displayOptions = display
        self.backgroundOverride = backgroundOverride
        self.sqlTextView = SQLTextView(theme: theme, displayOptions: display, backgroundOverride: backgroundOverride)
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
        sqlTextView.setAccessibilityIdentifier("QueryEditorTextView")

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
        guard self.theme != theme else { return }
        self.theme = theme
        applyTheme()
    }

    func updateBackgroundOverride(_ color: NSColor?) {
        guard backgroundOverride != color else { return }
        backgroundOverride = color
        contentView.backgroundColor = color ?? .clear
        sqlTextView.backgroundOverride = color
    }

    func updateDisplay(_ options: SQLEditorDisplayOptions) {
        guard displayOptions != options else { return }
        displayOptions = options
        sqlTextView.displayOptions = options
        applyDisplay()
    }

    private func applyTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = backgroundOverride ?? .clear
        sqlTextView.theme = theme
        sqlTextView.backgroundOverride = backgroundOverride
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
            lineNumberRuler.ruleThickness = 40
            lineNumberRuler.setFrameSize(NSSize(width: 40, height: lineNumberRuler.frame.size.height))
            lineNumberRuler.setBoundsSize(NSSize(width: 40, height: lineNumberRuler.bounds.size.height))
            lineNumberRuler.clientView = sqlTextView
            lineNumberRuler.theme = theme
            lineNumberRuler.sqlTextView = sqlTextView
            lineNumberRuler.needsDisplay = true
        } else {
            hasVerticalRuler = false
            rulersVisible = false
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
    weak var clipboardHistory: ClipboardHistoryStore?
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    var theme: SQLEditorTheme { didSet { applyTheme() } }
    var displayOptions: SQLEditorDisplayOptions { didSet { applyDisplayOptions() } }
    var backgroundOverride: NSColor? { didSet { applyTheme() } }

    private weak var lineNumberRuler: LineNumberRulerView?
    private var paragraphStyle = NSMutableParagraphStyle()
    private var highlightWorkItem: DispatchWorkItem?

    private static let primaryKeywords: [String] = [
        "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP",
        "TRUNCATE", "REPLACE", "MERGE", "GRANT", "REVOKE", "ANALYZE",
        "EXPLAIN", "VACUUM"
    ]

    private static let secondaryKeywords: [String] = [
        "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER",
        "CROSS", "ON", "GROUP", "BY", "HAVING", "ORDER", "LIMIT", "OFFSET",
        "FETCH", "UNION", "ALL", "DISTINCT", "INTO", "VALUES", "SET",
        "RETURNING", "WITH", "AS", "AND", "OR", "NOT", "NULL", "IS", "IN",
        "BETWEEN", "EXISTS", "LIKE", "ILIKE", "SIMILAR", "CASE", "WHEN",
        "THEN", "ELSE", "END", "USING", "OVER", "PARTITION", "FILTER",
        "WINDOW", "DESC", "ASC", "TOP", "PRIMARY", "FOREIGN", "KEY",
        "CONSTRAINT", "DEFAULT", "CHECK"
    ]

    private static let singleLineCommentRegex = try! NSRegularExpression(
        pattern: "--[^\\n]*",
        options: []
    )

    private static let blockCommentRegex = try! NSRegularExpression(
        pattern: "/\\*[\\s\\S]*?\\*/",
        options: [.dotMatchesLineSeparators]
    )

    private static let singleQuotedStringRegex = try! NSRegularExpression(
        pattern: "'([^']|'')*'",
        options: []
    )
    private static let numberRegex = try! NSRegularExpression(
        pattern: "\\b\\d+(?:\\.\\d+)?\\b",
        options: []
    )

    private static let operatorRegex = try! NSRegularExpression(
        pattern: "(?<![A-Za-z0-9_])(?:<>|!=|>=|<=|::|\\*\\*|[-+*/=%<>!]+)",
        options: []
    )

    private static let functionRegex = try! NSRegularExpression(
        pattern: "\\b([A-Z_][A-Z0-9_]*)\\s*(?=\\()",
        options: [.caseInsensitive]
    )

    private static let primaryKeywordRegex: NSRegularExpression = {
        let pattern = "\\b(?:" + primaryKeywords.joined(separator: "|") + ")\\b"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let secondaryKeywordRegex: NSRegularExpression = {
        let pattern = "\\b(?:" + secondaryKeywords.joined(separator: "|") + ")\\b"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let allKeywords: Set<String> = {
        Set(primaryKeywords.map { $0.lowercased() } + secondaryKeywords.map { $0.lowercased() })
    }()

    init(theme: SQLEditorTheme, displayOptions: SQLEditorDisplayOptions, backgroundOverride: NSColor?) {
        self.theme = theme
        self.displayOptions = displayOptions
        self.backgroundOverride = backgroundOverride

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
        scheduleHighlighting(after: 0)
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
        backgroundColor = backgroundOverride ?? theme.palette.background.nsColor
        updateParagraphStyle()
        lineNumberRuler?.theme = theme
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        scheduleHighlighting(after: 0)
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

    func reapplyHighlighting() {
        scheduleHighlighting(after: 0)
    }

    override func didChangeText() {
        super.didChangeText()
        sqlDelegate?.sqlTextView(self, didUpdateText: string)
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        notifySelectionChanged()
        scheduleHighlighting()
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

    override func copy(_ sender: Any?) {
        let selection = selectedRange()
        super.copy(sender)

        guard selection.length > 0,
              let clipboardHistory,
              let copied = PlatformClipboard.paste()
        else { return }

        clipboardHistory.record(.queryEditor, content: copied, metadata: clipboardMetadata)
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

    private func scheduleHighlighting(after delay: TimeInterval = 0.05) {
        highlightWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.highlightSyntax()
        }
        highlightWorkItem = workItem
        let deadline: DispatchTime = delay <= 0 ? .now() : .now() + delay
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func highlightSyntax() {
        guard let textStorage = textStorage else { return }
        let nsString = string as NSString
        let length = nsString.length
        guard length > 0 else { return }
        let fullRange = NSRange(location: 0, length: length)

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.nsFont,
            .foregroundColor: theme.tokenColors.plain.nsColor,
            .paragraphStyle: paragraphStyle
        ]

        textStorage.beginEditing()
        textStorage.setAttributes(baseAttributes, range: fullRange)

        var excludedRanges: [NSRange] = []

        excludedRanges += applyRegex(SQLTextView.singleQuotedStringRegex, in: nsString, color: theme.tokenColors.string.nsColor)
        excludedRanges += applyRegex(SQLEditorRegex.doubleQuotedStringRegex, in: nsString, color: theme.tokenColors.identifier.nsColor)
        excludedRanges += applyRegex(SQLTextView.blockCommentRegex, in: nsString, color: theme.tokenColors.comment.nsColor)
        excludedRanges += applyRegex(SQLTextView.singleLineCommentRegex, in: nsString, color: theme.tokenColors.comment.nsColor)

        _ = applyRegex(SQLTextView.numberRegex, in: nsString, color: theme.tokenColors.number.nsColor, skip: excludedRanges)
        _ = applyRegex(SQLTextView.operatorRegex, in: nsString, color: theme.tokenColors.operatorSymbol.nsColor, skip: excludedRanges)
        _ = applyRegex(SQLTextView.primaryKeywordRegex, in: nsString, color: theme.tokenColors.primaryKeyword.nsColor, skip: excludedRanges)
        _ = applyRegex(SQLTextView.secondaryKeywordRegex, in: nsString, color: theme.tokenColors.secondaryKeyword.nsColor, skip: excludedRanges)

        applyFunctionHighlights(in: nsString, skip: excludedRanges)

        textStorage.endEditing()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    private func applyRegex(_ regex: NSRegularExpression,
                            in string: NSString,
                            color: NSColor,
                            skip: [NSRange] = []) -> [NSRange] {
        guard let textStorage = textStorage else { return [] }
        let fullRange = NSRange(location: 0, length: string.length)
        var applied: [NSRange] = []
        regex.enumerateMatches(in: string as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let targetRange = match.range
            guard targetRange.length > 0 else { return }
            guard !intersectsExcluded(targetRange, excluded: skip) else { return }
            textStorage.addAttributes([.foregroundColor: color], range: targetRange)
            applied.append(targetRange)
        }
        return applied
    }

    private func applyFunctionHighlights(in string: NSString, skip: [NSRange]) {
        guard let textStorage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: string.length)
        SQLTextView.functionRegex.enumerateMatches(in: string as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let nameRange = match.range(at: 1)
            guard nameRange.length > 0 else { return }
            guard !intersectsExcluded(nameRange, excluded: skip) else { return }
            let name = string.substring(with: nameRange).lowercased()
            guard !SQLTextView.allKeywords.contains(name) else { return }
            textStorage.addAttributes([
                .foregroundColor: self.theme.tokenColors.function.nsColor
            ], range: nameRange)
        }
    }

    private func intersectsExcluded(_ range: NSRange, excluded: [NSRange]) -> Bool {
        for ex in excluded {
            if NSIntersectionRange(ex, range).length > 0 {
                return true
            }
        }
        return false
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
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.height]
        setFrameSize(NSSize(width: ruleThickness, height: frame.size.height))
        setBoundsSize(NSSize(width: ruleThickness, height: bounds.size.height))
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        theme.palette.gutterBackground.nsColor.setFill()
        gutterRect.fill()

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
            drawFallbackLine(with: attributes, in: gutterRect)
            return
        }

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

        let initialCharIndex = layoutManager.characterIndexForGlyph(at: initialGlyph)
        var currentLine = nsString.lineNumber(at: min(initialCharIndex, max(nsString.length - 1, 0)))

        var glyphIndex = initialGlyph
        while glyphIndex < maxGlyphIndex {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let yPosition = lineRect.minY + textView.textContainerInset.height - textView.visibleRect.origin.y

            let labelRect = NSRect(x: 0, y: yPosition + 2, width: gutterRect.width - 8, height: lineRect.height)
            ("\(currentLine)" as NSString).draw(in: labelRect, withAttributes: attributes)

            glyphIndex = min(NSMaxRange(lineRange), maxGlyphIndex)
            currentLine += 1
        }

        // No divider – match Tahoe preview
    }

    private func drawFallbackLine(with attributes: [NSAttributedString.Key: Any], in rect: NSRect) {
        let labelRect = NSRect(x: 0, y: rect.minY + 4, width: rect.width - 8, height: rect.height)
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
    var backgroundColor: Color?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardHistory: ClipboardHistoryStore
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = theme.uiFont
        textView.textColor = theme.tokenColors.plain.uiColor
        textView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.palette.background.uiColor
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
        uiView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.palette.background.uiColor
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
            parent.onTextChange(textView.text)
            textViewDidChangeSelection(textView)
        }
    }
}
#endif
