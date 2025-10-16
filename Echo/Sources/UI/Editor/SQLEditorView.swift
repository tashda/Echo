import SwiftUI
import Combine
import Foundation
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

struct SQLEditorView: View {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var completionContext: SQLEditorCompletionContext?
    var ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata
    var onAddBookmark: (String) -> Void

    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    init(
        text: Binding<String>,
        theme: SQLEditorTheme,
        display: SQLEditorDisplayOptions,
        backgroundColor: Color? = nil,
        completionContext: SQLEditorCompletionContext? = nil,
        ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil,
        onTextChange: @escaping (String) -> Void,
        onSelectionChange: @escaping (SQLEditorSelection) -> Void,
        onSelectionPreviewChange: @escaping (SQLEditorSelection) -> Void,
        clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty,
        onAddBookmark: @escaping (String) -> Void = { _ in }
    ) {
        _text = text
        self.theme = theme
        self.display = display
        self.backgroundColor = backgroundColor
        self.completionContext = completionContext
        self.ruleTraceConfig = ruleTraceConfig
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onSelectionPreviewChange = onSelectionPreviewChange
        self.clipboardMetadata = clipboardMetadata
        self.onAddBookmark = onAddBookmark
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
            clipboardMetadata: clipboardMetadata,
            onAddBookmark: onAddBookmark,
            completionContext: completionContext,
            ruleTraceConfig: ruleTraceConfig
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
            clipboardMetadata: clipboardMetadata,
            onAddBookmark: onAddBookmark,
            completionContext: completionContext
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
    var onAddBookmark: (String) -> Void
    var completionContext: SQLEditorCompletionContext?
    var ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> SQLScrollView {
        let scrollView = SQLScrollView(
            theme: theme,
            display: display,
            backgroundOverride: backgroundColor.map(NSColor.init),
            completionContext: completionContext,
            ruleTraceConfig: ruleTraceConfig
        )
        let textView = scrollView.sqlTextView
        textView.sqlDelegate = context.coordinator
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata
        textView.string = text
        textView.reapplyHighlighting()
        textView.completionContext = completionContext
        if let ruleTraceConfig {
            textView.isRuleTracingEnabled = ruleTraceConfig.isEnabled
            textView.onRuleTrace = ruleTraceConfig.onTrace
        } else {
            textView.isRuleTracingEnabled = false
            textView.onRuleTrace = nil
        }
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
        nsView.completionContext = completionContext
        let textView = nsView.sqlTextView
        context.coordinator.theme = theme
        context.coordinator.parent = self
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata
        if let ruleTraceConfig {
            textView.isRuleTracingEnabled = ruleTraceConfig.isEnabled
            textView.onRuleTrace = ruleTraceConfig.onTrace
        } else {
            textView.isRuleTracingEnabled = false
            textView.onRuleTrace = nil
        }

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

        func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {
            parent.onAddBookmark(content)
        }
    }
}

protocol SQLTextViewDelegate: AnyObject {
    func sqlTextView(_ view: SQLTextView, didUpdateText text: String)
    func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String)
}

extension SQLTextViewDelegate {
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {}
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {}
}

private final class SQLScrollView: NSScrollView {
    let sqlTextView: SQLTextView
    private var theme: SQLEditorTheme
    private var displayOptions: SQLEditorDisplayOptions
    private let lineNumberRuler: LineNumberRulerView
    private var backgroundOverride: NSColor?
    var completionContext: SQLEditorCompletionContext? {
        didSet { sqlTextView.completionContext = completionContext }
    }

    var currentDisplayOptions: SQLEditorDisplayOptions { displayOptions }

    init(theme: SQLEditorTheme,
         display: SQLEditorDisplayOptions,
         backgroundOverride: NSColor?,
         completionContext: SQLEditorCompletionContext? = nil,
         ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil) {
        self.displayOptions = display
        self.backgroundOverride = backgroundOverride
        self.completionContext = completionContext
        self.sqlTextView = SQLTextView(
            theme: theme,
            displayOptions: display,
            backgroundOverride: backgroundOverride,
            completionContext: completionContext,
            ruleTraceConfig: ruleTraceConfig
        )
        self.lineNumberRuler = LineNumberRulerView(textView: sqlTextView, theme: theme)
        self.theme = theme
        super.init(frame: .zero)
        drawsBackground = false
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.masksToBounds = false
        borderType = .noBorder
        drawsBackground = false
        backgroundColor = .clear
        contentView.drawsBackground = false
        contentView.backgroundColor = .clear
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

    deinit {
        sqlTextView.cancelPendingCompletions()
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
#if DEBUG
        if let color {
            debugLogBackgroundOverride(color: color, label: "updateBackgroundOverride")
        } else {
            print("[SQLScrollView] backgroundOverride cleared")
        }
#endif
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
#if DEBUG
        if let backgroundOverride {
            debugLogBackgroundOverride(color: backgroundOverride, label: "applyTheme override")
        } else {
            debugLogBackgroundOverride(color: theme.surfaces.background.nsColor, label: "applyTheme theme")
        }
#endif
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

#if DEBUG
    private func debugLogBackgroundOverride(color: NSColor, label: String) {
        let device = color.usingColorSpace(.deviceRGB) ?? color
        let red = String(format: "%.3f", device.redComponent)
        let green = String(format: "%.3f", device.greenComponent)
        let blue = String(format: "%.3f", device.blueComponent)
        let alpha = String(format: "%.3f", device.alphaComponent)
        print("[SQLScrollView] \(label) r=\(red) g=\(green) b=\(blue) a=\(alpha)")
    }
#endif
}

func sqlRangeIsValid(_ range: NSRange, upperBound: Int) -> Bool {
    guard range.location >= 0, range.length >= 0 else { return false }
    guard upperBound >= 0 else { return false }
    if range.length == 0 {
        return range.location <= upperBound
    }
    guard upperBound > 0 else { return false }
    guard range.location < upperBound else { return false }
    return NSMaxRange(range) <= upperBound
}

final class SQLTextView: NSTextView, NSTextViewDelegate {
    weak var sqlDelegate: SQLTextViewDelegate?
    weak var clipboardHistory: ClipboardHistoryStore?
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    var theme: SQLEditorTheme { didSet { applyTheme() } }
    var displayOptions: SQLEditorDisplayOptions { didSet { applyDisplayOptions() } }
    var backgroundOverride: NSColor? { didSet { applyTheme() } }
    var completionContext: SQLEditorCompletionContext? {
        didSet {
            completionEngine.updateContext(completionContext)
            refreshCompletions(immediate: true)
        }
    }

    private let sqruffProvider = SqruffCompletionProvider.shared
    private weak var lineNumberRuler: LineNumberRulerView?
    private var paragraphStyle = NSMutableParagraphStyle()
    private var highlightWorkItem: DispatchWorkItem?
    private var symbolHighlightWorkItem: DispatchWorkItem?
    private var selectionMatchRanges: [NSRange] = []
    private var caretMatchRanges: [NSRange] = []
    var completionWorkItem: DispatchWorkItem?
    var completionTask: Task<Void, Never>?
    var completionGeneration = 0
    let completionEngine = SQLAutoCompletionEngine()
    let ruleEngine = SQLAutocompleteRuleEngine()
    var completionController: SQLAutoCompletionController?
    private var isApplyingCompletion = false
    private var suppressNextCompletionRefresh = false
    var isRuleTracingEnabled: Bool = false
    var onRuleTrace: ((SQLAutocompleteTrace) -> Void)?

    struct SuppressedCompletion: Equatable {
        var tokenRange: NSRange
        let canonicalText: String
        let hasFollowUps: Bool

        var isValid: Bool {
            tokenRange.location != NSNotFound && tokenRange.length > 0
        }

        var asRuleSuppression: SQLAutocompleteRuleEngine.Suppression {
            SQLAutocompleteRuleEngine.Suppression(tokenRange: tokenRange,
                                                  canonicalText: canonicalText,
                                                  hasFollowUps: hasFollowUps)
        }
    }

    private struct StructureObjectMatch {
        let database: String?
        let schema: SchemaInfo
        let object: SchemaObjectInfo
    }

    var suppressedCompletions: [SuppressedCompletion] = []
    var completionIndicatorView: CompletionAccessoryView?

    var ruleEnvironment: SQLAutocompleteRuleEngine.Environment {
        SQLAutocompleteRuleEngine.Environment(completionContext: completionContext)
    }

    private enum CompletionTriggerKind {
        case none
        case standard
        case immediate
        case evaluateSpace
    }

    var isCompletionVisible: Bool {
        completionController?.isPresenting ?? false
    }

    private static let keywords: [String] = [
        "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP",
        "TRUNCATE", "REPLACE", "MERGE", "GRANT", "REVOKE", "ANALYZE",
        "EXPLAIN", "VACUUM", "FROM", "WHERE", "JOIN", "INNER", "LEFT",
        "RIGHT", "FULL", "OUTER", "CROSS", "ON", "GROUP", "BY", "HAVING",
        "ORDER", "LIMIT", "OFFSET", "FETCH", "UNION", "ALL", "DISTINCT",
        "INTO", "VALUES", "SET", "RETURNING", "WITH", "AS", "AND", "OR",
        "NOT", "NULL", "IS", "IN", "BETWEEN", "EXISTS", "LIKE", "ILIKE",
        "SIMILAR", "CASE", "WHEN", "THEN", "ELSE", "END", "USING", "OVER",
        "PARTITION", "FILTER", "WINDOW", "DESC", "ASC", "TOP", "PRIMARY",
        "FOREIGN", "KEY", "CONSTRAINT", "DEFAULT", "CHECK"
    ]

    static let objectContextKeywords = SQLAutocompleteHeuristics.objectContextKeywords
    static let columnContextKeywords = SQLAutocompleteHeuristics.columnContextKeywords

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

    private static let aliasTerminatingKeywords: Set<String> = [
        "WHERE", "INNER", "LEFT", "RIGHT", "ON", "JOIN", "SET", "ORDER", "GROUP", "HAVING", "LIMIT"
    ]

    private static let operatorRegex = try! NSRegularExpression(
        pattern: "(?<![A-Za-z0-9_])(?:<>|!=|>=|<=|::|\\*\\*|[-+*/=%<>!]+)",
        options: []
    )

    private static let functionRegex = try! NSRegularExpression(
        pattern: "\\b([A-Z_][A-Z0-9_]*)\\s*(?=\\()",
        options: [.caseInsensitive]
    )

    private static let keywordRegex: NSRegularExpression = {
        let pattern = "\\b(?:" + keywords.joined(separator: "|") + ")\\b"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let allKeywords: Set<String> = {
        Set(keywords.map { $0.lowercased() })
    }()

    private static let wordCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_$")
        return set
    }()

    private static let completionTokenCharacterSet: CharacterSet = {
        var set = wordCharacterSet
        set.insert(charactersIn: ".")
        return set
    }()

    init(theme: SQLEditorTheme,
         displayOptions: SQLEditorDisplayOptions,
         backgroundOverride: NSColor?,
         completionContext: SQLEditorCompletionContext? = nil,
         ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil) {
        self.theme = theme
        self.displayOptions = displayOptions
        self.backgroundOverride = backgroundOverride
        self.completionContext = completionContext

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude))

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 360), textContainer: textContainer)

        completionEngine.updateContext(completionContext)
        completionController = SQLAutoCompletionController(textView: self)

        isEditable = true
        isSelectable = true
        isRichText = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isGrammarCheckingEnabled = false
        usesAdaptiveColorMappingForDarkAppearance = false
        textContainerInset = NSSize(width: 10, height: 16)
        allowsUndo = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 320)
        isHorizontallyResizable = false
        isVerticallyResizable = true
        autoresizingMask = [.width]
        wantsLayer = true
        layer?.isOpaque = true

        textContainer.widthTracksTextView = false
        textContainer.lineFragmentPadding = 14

        configureDelegates()
        applyTheme()
        applyDisplayOptions()
        scheduleHighlighting(after: 0)
        if let ruleTraceConfig {
            isRuleTracingEnabled = ruleTraceConfig.isEnabled
            onRuleTrace = ruleTraceConfig.onTrace
        }
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
        backgroundColor = backgroundOverride ?? theme.surfaces.background.nsColor
        typingAttributes[.ligature] = theme.ligaturesEnabled ? 1 : 0
        updateParagraphStyle()
        lineNumberRuler?.theme = theme
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        scheduleHighlighting(after: 0)
        if displayOptions.highlightSelectedSymbol {
            scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true)
        }
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

    override func keyDown(with event: NSEvent) {
        if completionController?.handleKeyDown(event) == true {
            return
        }
        if handleCommandShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleCommandShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let trigger = determineCompletionTrigger(for: string)
        super.insertText(string, replacementRange: replacementRange)
        let inserted = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        handleCompletionTrigger(trigger, insertedText: inserted)
    }

    override func resignFirstResponder() -> Bool {
        hideCompletions()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        notifySelectionPreview()
    }

    private func determineCompletionTrigger(for string: Any) -> CompletionTriggerKind {
        guard let inserted = (string as? String) ?? (string as? NSAttributedString)?.string, inserted.count == 1 else {
            return .none
        }
        guard let scalar = inserted.unicodeScalars.first else { return .none }
        if CharacterSet.letters.contains(scalar) { return .standard }
        if inserted == "_" { return .standard }
        if inserted == "." { return .immediate }
        if inserted == " " { return .evaluateSpace }
        return .none
    }

    private func handleCompletionTrigger(_ trigger: CompletionTriggerKind, insertedText: String) {
        switch trigger {
        case .immediate:
            triggerCompletion(immediate: true)
        case .standard:
            triggerCompletion(immediate: false)
        case .evaluateSpace:
            if shouldTriggerAfterKeywordSpace() {
                triggerCompletion(immediate: true)
            }
        case .none:
            if insertedText == "\n" {
                hideCompletions()
            } else if isCompletionVisible && isIdentifierContinuation(insertedText) {
                triggerCompletion(immediate: false)
            }
        }
    }

    private func triggerCompletion(immediate: Bool) {
        guard displayOptions.autoCompletionEnabled else { return }
        suppressNextCompletionRefresh = true
        refreshCompletions(immediate: immediate)
    }

    private func shouldTriggerAfterKeywordSpace() -> Bool {
        let linePrefix = currentLinePrefix()
        guard !linePrefix.isEmpty else { return false }
        let pattern = #"(?i)(from|join|update|call|exec|execute|into)\s*$"#
        return linePrefix.range(of: pattern, options: .regularExpression) != nil
    }

    private func currentLinePrefix() -> String {
        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound else { return "" }
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: caretLocation, length: 0))
        let prefixLength = max(0, caretLocation - lineRange.location)
        guard prefixLength > 0 else { return "" }
        return nsString.substring(with: NSRange(location: lineRange.location, length: prefixLength))
    }

    private func isIdentifierContinuation(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "$_"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
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
        if !isApplyingCompletion {
            if suppressNextCompletionRefresh {
                suppressNextCompletionRefresh = false
            } else if isCompletionVisible {
                refreshCompletions()
            } else {
                hideCompletions()
            }
        }
        updateCompletionIndicator()
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

    override func menu(for event: NSEvent) -> NSMenu? {
        let baseMenu = super.menu(for: event) ?? NSMenu(title: "Context")
        let item = NSMenuItem(title: "Add to Bookmarks", action: #selector(addSelectionToBookmarks(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = hasBookmarkableSelection

        if let existingIndex = baseMenu.items.firstIndex(where: { $0.action == #selector(addSelectionToBookmarks(_:)) }) {
            baseMenu.removeItem(at: existingIndex)
        }

        if let firstItem = baseMenu.items.first, firstItem.isSeparatorItem == false {
            baseMenu.insertItem(NSMenuItem.separator(), at: 0)
        }
        baseMenu.insertItem(item, at: 0)
        return baseMenu
    }

    private var hasBookmarkableSelection: Bool {
        let range = selectedRange()
        guard range.length > 0 else { return false }
        let selection = (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        return !selection.isEmpty
    }

    @objc private func addSelectionToBookmarks(_ sender: Any?) {
        guard hasBookmarkableSelection else { return }
        let range = selectedRange()
        let content = (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        sqlDelegate?.sqlTextView(self, didRequestBookmarkWithContent: content)
    }

    private func notifySelectionChanged() {
        let selection = currentSelectionDescriptor()
        scheduleSymbolHighlights(for: selection)
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        sqlDelegate?.sqlTextView(self, didChangeSelection: selection)
        if !isApplyingCompletion && !suppressNextCompletionRefresh {
            refreshCompletions(immediate: true)
        }
    }

    private func notifySelectionPreview() {
        let selection = currentSelectionDescriptor()
        sqlDelegate?.sqlTextView(self, didPreviewSelection: selection)
    }

    private func currentSelectionDescriptor() -> SQLEditorSelection {
        let range = selectedRange()
        let nsString = string as NSString
        let selected = (range.length > 0 && range.location != NSNotFound) ? nsString.substring(with: range) : ""
        let lines = selectedLines(for: range)
        return SQLEditorSelection(selectedText: selected, range: range, lineRange: lines)
    }

    private func scheduleSymbolHighlights(for selection: SQLEditorSelection, immediate: Bool = false) {
        symbolHighlightWorkItem?.cancel()

        guard displayOptions.highlightSelectedSymbol else {
            clearSymbolHighlights()
            return
        }

        guard selection.range.location != NSNotFound else {
            clearSymbolHighlights()
            return
        }

        let delay = immediate ? 0 : max(displayOptions.highlightDelay, 0)
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySymbolHighlights(for: selection)
        }
        symbolHighlightWorkItem = workItem
        let deadline: DispatchTime = delay <= 0 ? .now() : .now() + delay
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func applySymbolHighlights(for selection: SQLEditorSelection) {
        guard displayOptions.highlightSelectedSymbol else {
            clearSymbolHighlights()
            return
        }
        guard let layoutManager = layoutManager else { return }

        clearSymbolHighlights()

        let nsString = string as NSString
        guard nsString.length > 0 else { return }

        if selection.range.length > 0, !selection.selectedText.isEmpty {
            selectionMatchRanges = highlightSelectionMatches(selection: selection,
                                                             in: nsString,
                                                             layoutManager: layoutManager)
        } else {
            caretMatchRanges = highlightCaretWordMatches(location: selection.range.location,
                                                         in: nsString,
                                                         layoutManager: layoutManager)
        }

        setNeedsDisplay(bounds)
        symbolHighlightWorkItem = nil
    }

    private func highlightSelectionMatches(selection: SQLEditorSelection,
                                           in string: NSString,
                                           layoutManager: NSLayoutManager) -> [NSRange] {
        var matches: [NSRange] = []
        let selectedRange = selection.range
        let target = selection.selectedText
        var searchLocation = 0
        let highlightColor = symbolHighlightColor(.bright)

        while searchLocation < string.length {
            let remainingLength = string.length - searchLocation
            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            let found = string.range(of: target, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }

            if !(found.location == selectedRange.location && found.length == selectedRange.length) {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: found)
                layoutManager.invalidateDisplay(forCharacterRange: found)
                matches.append(found)
            }

            searchLocation = found.location + 1
        }

        return matches
    }

    private func highlightCaretWordMatches(location: Int,
                                           in string: NSString,
                                           layoutManager: NSLayoutManager) -> [NSRange] {
        guard let wordRange = wordRange(at: location, in: string), wordRange.length > 0 else { return [] }
        let target = string.substring(with: wordRange)
        guard !target.isEmpty else { return [] }

        guard location >= wordRange.location && location < NSMaxRange(wordRange) else { return [] }

        var matches: [NSRange] = []
        let highlightColor = symbolHighlightColor(.strong)
        let caretLocation = location

        if !shouldSkipCaretHighlight(at: caretLocation) {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: wordRange)
            layoutManager.invalidateDisplay(forCharacterRange: wordRange)
            matches.append(wordRange)
        }

        var searchLocation = 0

        while searchLocation < string.length {
            let remainingLength = string.length - searchLocation
            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            let found = string.range(of: target, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }

            let containsCaret = caretLocation >= found.location && caretLocation <= NSMaxRange(found)
            if isWholeWord(range: found, in: string) && !containsCaret {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: found)
                layoutManager.invalidateDisplay(forCharacterRange: found)
                matches.append(found)
            }

            searchLocation = found.location + max(found.length, 1)
        }

        return matches
    }

    private func shouldSkipCaretHighlight(at caretLocation: Int) -> Bool {
        guard caretLocation != NSNotFound else { return false }
        let caretRange = NSRange(location: caretLocation, length: 0)
        guard let (_, suppression) = suppressedCompletionEntry(containing: caretRange, caretLocation: caretLocation) else {
            return false
        }
        return suppression.hasFollowUps
    }

    private func clearSymbolHighlights() {
        guard let layoutManager = layoutManager else {
            selectionMatchRanges.removeAll()
            caretMatchRanges.removeAll()
            return
        }

        (selectionMatchRanges + caretMatchRanges).forEach { range in
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
            layoutManager.invalidateDisplay(forCharacterRange: range)
        }
        selectionMatchRanges.removeAll()
        caretMatchRanges.removeAll()
        setNeedsDisplay(bounds)
    }

    // MARK: - Autocompletion

    private func refreshCompletions(immediate: Bool = false) {
        guard !isApplyingCompletion else { return }
        guard displayOptions.autoCompletionEnabled else {
            completionTask?.cancel()
            hideCompletions()
            return
        }

        guard completionContext != nil else {
            completionTask?.cancel()
            hideCompletions()
            return
        }

        completionWorkItem?.cancel()
        completionTask?.cancel()

        let generation: Int = {
            completionGeneration += 1
            return completionGeneration
        }()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            defer { self.completionWorkItem = nil }
            guard !self.isApplyingCompletion else { return }
            guard let controller = self.ensureCompletionController() else { return }
            guard let query = self.makeCompletionQuery() else {
                self.hideCompletions()
                return
            }

            let selectionRange = self.selectedRange()
            let caretLocation = selectionRange.location

            var baseSuggestions = self.filteredSuggestions(from: self.completionEngine.suggestions(for: query), for: query)
            baseSuggestions = self.filterSuggestionsForContext(baseSuggestions, query: query)
            baseSuggestions = self.limitSuggestions(baseSuggestions)

            if baseSuggestions.isEmpty,
               let (_, suppression) = self.suppressedCompletionEntry(containing: selectionRange, caretLocation: caretLocation),
               suppression.hasFollowUps,
               let fallback = self.ruleEngine.fallbackSuggestions(for: suppression.asRuleSuppression,
                                                                  environment: self.ruleEnvironment),
               !fallback.isEmpty {
                baseSuggestions = fallback
            }

            if self.shouldSuppressCompletions(query: query,
                                              selection: selectionRange,
                                              caretLocation: caretLocation,
                                              suggestions: baseSuggestions,
                                              bypassSuppression: false) {
                self.hideCompletions()
                return
            }

            if baseSuggestions.isEmpty {
                self.hideCompletions()
            } else {
                self.removeCompletionIndicator()
                controller.present(suggestions: baseSuggestions, query: query)
            }

            let currentContext = self.completionContext
            let fullText = self.string

            self.completionTask = Task { [weak self] in
                guard let self else { return }
                if Task.isCancelled { return }
                guard generation == self.completionGeneration else { return }
                defer {
                    if generation == self.completionGeneration {
                        self.completionTask = nil
                    }
                }
                guard let context = currentContext else { return }

                let updatedCaretLocation = self.currentSelectionDescriptor().range.location

                let external = await self.fetchSqruffSuggestions(for: query,
                                                                  text: fullText,
                                                                  caretLocation: updatedCaretLocation,
                                                                  context: context)
                guard !external.isEmpty, !Task.isCancelled else { return }

                var combined = self.mergeSuggestions(primary: baseSuggestions, secondary: external, query: query)
                combined = self.filterSuggestionsForContext(combined, query: query)
                combined = self.limitSuggestions(combined)

                guard !combined.isEmpty, !Task.isCancelled, generation == self.completionGeneration else { return }

                await MainActor.run {
                    guard !Task.isCancelled, generation == self.completionGeneration else { return }
                    if self.shouldSuppressCompletions(query: query,
                                                      selection: self.selectedRange(),
                                                      caretLocation: updatedCaretLocation,
                                                      suggestions: combined,
                                                      bypassSuppression: false) {
                        self.hideCompletions()
                        return
                    }
                    self.removeCompletionIndicator()
                    controller.present(suggestions: combined, query: query)
                }
            }
        }

        completionWorkItem = workItem
        let deadline: DispatchTime = immediate ? .now() : .now() + 0.015
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func hideCompletions() {
        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil
        completionController?.hide()
        updateCompletionIndicator()
    }

    func cancelPendingCompletions() {
        hideCompletions()
    }

    @discardableResult
    func ensureCompletionController() -> SQLAutoCompletionController? {
        if completionController == nil {
            completionController = SQLAutoCompletionController(textView: self)
        }
        return completionController
    }

    func currentCompletionQuery() -> SQLAutoCompletionQuery? {
        makeCompletionQuery()
    }

    func makeCompletionQuery() -> SQLAutoCompletionQuery? {
        guard textStorage != nil else { return nil }
        let selection = selectedRange()
        guard selection.location != NSNotFound, selection.length == 0 else { return nil }

        let nsString = string as NSString
        let tokenRange = tokenRange(at: selection.location, in: nsString)
        let token: String
        if tokenRange.length > 0 {
            token = nsString.substring(with: tokenRange)
        } else {
            token = ""
        }

        let rawComponents = token.split(separator: ".", omittingEmptySubsequences: false).map { String($0) }
        let prefix = rawComponents.last ?? ""
        let pathComponents = rawComponents.dropLast().filter { !$0.isEmpty }

        let replacementRange = replacementRange(for: prefix, tokenRange: tokenRange, caretLocation: selection.location)
        let precedingKeyword = previousKeyword(before: tokenRange.location, in: nsString)
        let precedingCharacter = previousNonWhitespaceCharacter(before: tokenRange.location, in: nsString)
        let focusTable = inferFocusTable(before: selection.location, in: nsString)
        var scopeTables = self.tablesInScope(before: selection.location, in: nsString)
        if let focus = focusTable, !scopeTables.contains(where: { $0.matches(schema: focus.schema, name: focus.name) }) {
            scopeTables.append(focus)
        }

        let trailingTables = self.tablesInScope(after: selection.location, in: nsString)
        for table in trailingTables where !scopeTables.contains(where: { $0.isEquivalent(to: table) }) {
            scopeTables.append(table)
        }

        return SQLAutoCompletionQuery(
            token: token,
            prefix: prefix,
            pathComponents: Array(pathComponents),
            replacementRange: replacementRange,
            precedingKeyword: precedingKeyword,
            precedingCharacter: precedingCharacter,
            focusTable: focusTable,
            tablesInScope: scopeTables
        )
    }

    private func replacementRange(for prefix: String, tokenRange: NSRange, caretLocation: Int) -> NSRange {
        let prefixLength = (prefix as NSString).length
        let start = max(tokenRange.location, tokenRange.location + tokenRange.length - prefixLength)
        let length = max(0, caretLocation - start)
        return NSRange(location: start, length: length)
    }

    func tokenRange(at caretLocation: Int, in string: NSString) -> NSRange {
        var start = caretLocation
        while start > 0 && isCompletionCharacter(string.character(at: start - 1)) {
            start -= 1
        }

        var end = caretLocation
        let length = string.length
        while end < length && isCompletionCharacter(string.character(at: end)) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    private func isCompletionCharacter(_ char: unichar) -> Bool {
        guard let scalar = UnicodeScalar(char) else { return false }
        return SQLTextView.completionTokenCharacterSet.contains(scalar)
    }

    private func previousKeyword(before location: Int, in string: NSString) -> String? {
        guard location > 0 else { return nil }
        let prefixRange = NSRange(location: 0, length: location)
        let substring = string.substring(with: prefixRange)
        let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let components = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
        guard let keyword = components.last(where: { !$0.isEmpty }) else { return nil }
        return keyword.lowercased()
    }

    private func previousNonWhitespaceCharacter(before location: Int, in string: NSString) -> Character? {
        var index = location - 1
        while index >= 0 {
            let scalarValue = string.character(at: index)
            guard let scalar = UnicodeScalar(scalarValue) else { break }
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            }
            index -= 1
        }
        return nil
    }

    private func inferFocusTable(before location: Int, in string: NSString) -> SQLAutoCompletionTableFocus? {
        guard location > 0 else { return nil }
        let prefixRange = NSRange(location: 0, length: location)
        let substring = string.substring(with: prefixRange)
        guard !substring.isEmpty else { return nil }

        return extractTables(from: substring).last
    }

    private func normalizeIdentifier(_ value: String) -> String {
        var identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaceIndex = identifier.firstIndex(where: { $0.isWhitespace }) {
            identifier = String(identifier[..<spaceIndex])
        }
        identifier = identifier.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
        let removable: Set<Character> = ["\"", "'", "[", "]", "`"]
        identifier.removeAll(where: { removable.contains($0) })
        return identifier
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        let identifierBody = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy { identifierBody.contains($0) }
    }

    private func knownSourceNames() -> [String] {
        guard let context = completionContext, let structure = context.structure else { return [] }
        let selectedDatabase = context.selectedDatabase?.lowercased()
        var names: Set<String> = []

        for database in structure.databases {
            if let selectedDatabase, database.name.lowercased() != selectedDatabase { continue }
            for schema in database.schemas {
                for object in schema.objects where object.type == .table || object.type == .view || object.type == .materializedView {
                    names.insert(object.name)
                }
            }
        }

        return Array(names)
    }

    private func cleanedKeyword(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return trimmed.uppercased()
    }

    private func lastWord(in token: String) -> String? {
        guard let range = token.range(of: #"([^.]+)$"#, options: .regularExpression) else { return nil }
        return String(token[range])
    }

    func filteredSuggestions(from sections: [SQLAutoCompletionSection], for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let flattened = sections.flatMap { $0.suggestions }
        return sanitizeSuggestions(flattened, for: query)
    }

    private func sanitizeSuggestions(_ suggestions: [SQLAutoCompletionSuggestion], for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let trimmedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenLower = trimmedToken.lowercased()
        let pathLower = query.pathComponents.map { $0.lowercased() }
        let caretLocation = selectedRange().location
        let usedColumnContext = buildUsedColumnContext(before: caretLocation, query: query)
        var seen = Set<String>()
        var result: [SQLAutoCompletionSuggestion] = []
        result.reserveCapacity(suggestions.count)

        for suggestion in suggestions {
            let key = suggestion.insertText.lowercased()
            if !tokenLower.isEmpty {
                let isExactInsertMatch = key == tokenLower
                let isExactPathMatch: Bool = {
                    guard !pathLower.isEmpty else { return false }
                    let candidate = (pathLower + [key]).joined(separator: ".")
                    return candidate == tokenLower
                }()

                if (isExactInsertMatch || isExactPathMatch),
                   (suggestion.kind == .keyword || suggestion.kind == .function) {
                    continue
                }
            }

            if suggestion.kind == .column,
               let context = usedColumnContext,
               let columnName = normalizedColumnName(for: suggestion) {
                let candidateKeys = candidateColumnKeys(for: suggestion, query: query)
                let isAlreadySelected = candidateKeys.contains { key in
                    guard let used = context.byKey[key] else { return false }
                    return used.contains(columnName)
                }
                if isAlreadySelected {
                    continue
                }
            }

            if seen.insert(key).inserted {
                result.append(suggestion)
            }
        }
        return result
    }

    private struct UsedColumnContext {
        var byKey: [String: Set<String>]
        var unqualified: Set<String>
    }

    private func buildUsedColumnContext(before caretLocation: Int, query: SQLAutoCompletionQuery) -> UsedColumnContext? {
        guard caretLocation != NSNotFound else { return nil }
        let nsString = string as NSString
        let clampedLocation = min(max(caretLocation, 0), nsString.length)
        guard clampedLocation > 0 else { return nil }

        let prefixRange = NSRange(location: 0, length: clampedLocation)
        let prefixText = nsString.substring(with: prefixRange)
        guard let selectRange = prefixText.range(of: "select", options: [.caseInsensitive, .backwards]) else {
            return nil
        }

        let segmentStart = selectRange.upperBound
        let segment = prefixText[segmentStart...]

        if segment.range(of: "from", options: [.caseInsensitive]) != nil {
            return nil
        }

        var context = UsedColumnContext(byKey: [:], unqualified: [])
        let scopeTables = query.tablesInScope

        for part in segment.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let identifier = leadingIdentifier(in: trimmed) else { continue }
            let loweredIdentifier = identifier.lowercased()
            let components = loweredIdentifier.split(separator: ".", omittingEmptySubsequences: true)
            guard let columnComponent = components.last else { continue }
            let columnName = String(columnComponent)

            if components.count > 1 {
                let qualifierComponent = components[components.count - 2]
                let qualifier = String(qualifierComponent)
                if let aliasKeyValue = aliasKey(qualifier) {
                    context.byKey[aliasKeyValue, default: []].insert(columnName)
                }
                if let focus = tableFocus(forQualifier: qualifier, in: scopeTables) {
                    let key = tableKey(for: focus)
                    context.byKey[key, default: []].insert(columnName)
                    if let alias = focus.alias, let focusAliasKey = aliasKey(alias) {
                        context.byKey[focusAliasKey, default: []].insert(columnName)
                    }
                }
            } else {
                context.unqualified.insert(columnName)
                if scopeTables.count == 1 {
                    let focus = scopeTables[0]
                    let key = tableKey(for: focus)
                    context.byKey[key, default: []].insert(columnName)
                    if let alias = focus.alias, let focusAliasKey = aliasKey(alias) {
                        context.byKey[focusAliasKey, default: []].insert(columnName)
                    }
                }
            }
        }

        return context.byKey.isEmpty && context.unqualified.isEmpty ? nil : context
    }

    private func leadingIdentifier(in expression: String) -> String? {
        var buffer = ""
        for character in expression {
            if character.isLetter || character.isNumber || character == "_" || character == "." || character == "\"" || character == "`" || character == "[" || character == "]" {
                buffer.append(character)
            } else {
                break
            }
        }
        guard !buffer.isEmpty else { return nil }
        let normalized = normalizeIdentifier(buffer)
        return normalized.isEmpty ? nil : normalized
    }

    private func tableFocus(forQualifier qualifier: String, in tables: [SQLAutoCompletionTableFocus]) -> SQLAutoCompletionTableFocus? {
        let normalizedQualifier = normalizeIdentifier(qualifier).lowercased()
        if let aliasMatch = tables.first(where: { $0.alias?.lowercased() == normalizedQualifier }) {
            return aliasMatch
        }
        if let nameMatch = tables.first(where: { $0.name.lowercased() == normalizedQualifier }) {
            return nameMatch
        }
        return nil
    }

    private func tableKey(for focus: SQLAutoCompletionTableFocus) -> String {
        tableKey(schema: focus.schema, name: focus.name)
    }

    private func tableKey(schema: String?, name: String) -> String {
        let schemaComponent = schema.map { normalizeIdentifier($0).lowercased() } ?? ""
        let nameComponent = normalizeIdentifier(name).lowercased()
        return "\(schemaComponent)|\(nameComponent)"
    }

    private func aliasKey(_ alias: String) -> String? {
        let normalized = normalizeIdentifier(alias).lowercased()
        return normalized.isEmpty ? nil : "alias:\(normalized)"
    }

    private func aliasKeys(for origin: SQLAutoCompletionSuggestion.Origin, tables: [SQLAutoCompletionTableFocus]) -> [String] {
        guard let object = origin.object else { return [] }
        let objectName = normalizeIdentifier(object).lowercased()
        let schemaName = origin.schema.map { normalizeIdentifier($0).lowercased() }
        return tables.compactMap { focus in
            guard normalizeIdentifier(focus.name).lowercased() == objectName else { return nil }
            if let schemaName,
               let focusSchema = focus.schema.map({ normalizeIdentifier($0).lowercased() }),
               focusSchema != schemaName {
                return nil
            }
            guard let alias = focus.alias, let key = aliasKey(alias) else { return nil }
            return key
        }
    }

    private func candidateColumnKeys(for suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) -> [String] {
        var keys: Set<String> = []

        if let origin = suggestion.origin,
           let object = origin.object, !object.isEmpty {
            keys.insert(tableKey(schema: origin.schema, name: object))
            aliasKeys(for: origin, tables: query.tablesInScope).forEach { keys.insert($0) }
        }

        let normalizedInsert = normalizeIdentifier(suggestion.insertText).lowercased()
        let components = normalizedInsert.split(separator: ".", omittingEmptySubsequences: true)
        if components.count > 1 {
            let qualifier = String(components[components.count - 2])
            if let qualifierKey = aliasKey(qualifier) {
                keys.insert(qualifierKey)
            }
            if let focus = tableFocus(forQualifier: qualifier, in: query.tablesInScope) {
                keys.insert(tableKey(for: focus))
                if let alias = focus.alias, let focusAliasKey = aliasKey(alias) {
                    keys.insert(focusAliasKey)
                }
            }
        }

        return Array(keys)
    }

    private func normalizedColumnName(for suggestion: SQLAutoCompletionSuggestion) -> String? {
        if let column = suggestion.origin?.column, !column.isEmpty {
            return normalizeIdentifier(column).lowercased()
        }
        let normalized = normalizeIdentifier(suggestion.insertText)
        let components = normalized.split(separator: ".", omittingEmptySubsequences: true)
        guard let last = components.last else { return nil }
        return String(last).lowercased()
    }

    private func mergeSuggestions(primary: [SQLAutoCompletionSuggestion],
                                  secondary: [SQLAutoCompletionSuggestion],
                                  query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let tokenLower = query.token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seen = Set(primary.map { $0.insertText.lowercased() })
        var combined = primary
        combined.reserveCapacity(primary.count + secondary.count)

        for suggestion in secondary {
            let key = suggestion.insertText.lowercased()
            if !tokenLower.isEmpty && key == tokenLower { continue }
            if seen.insert(key).inserted {
                combined.append(suggestion)
            }
        }
        return combined
    }

    func filterSuggestionsForContext(_ suggestions: [SQLAutoCompletionSuggestion],
                                             query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        suggestions.filter { $0.kind != .function }
    }

    func limitSuggestions(_ suggestions: [SQLAutoCompletionSuggestion]) -> [SQLAutoCompletionSuggestion] {
        let maximum = 60
        return suggestions.count > maximum ? Array(suggestions.prefix(maximum)) : suggestions
    }

    private func fetchSqruffSuggestions(for query: SQLAutoCompletionQuery,
                                        text: String,
                                        caretLocation: Int,
                                        context: SQLEditorCompletionContext) async -> [SQLAutoCompletionSuggestion] {
        guard caretLocation != NSNotFound else { return [] }
        let nsString = text as NSString
        let boundedLocation = max(0, min(caretLocation, nsString.length))
        let position = cursorPosition(for: boundedLocation, in: nsString)

        do {
            var suggestions = try await sqruffProvider.completions(
                forText: text,
                line: position.line,
                character: position.character,
                dialect: context.databaseType
            )
            suggestions = sanitizeSuggestions(suggestions, for: query)
            return suggestions
        } catch {
            return []
        }
    }

    private func cursorPosition(for location: Int, in string: NSString) -> (line: Int, character: Int) {
        var line = 0
        var column = 0
        var index = 0
        let length = string.length
        while index < location && index < length {
            let char = string.character(at: index)
            if char == 10 { // \n
                line += 1
                column = 0
            } else if char == 13 { // \r
                if index + 1 < location && index + 1 < length && string.character(at: index + 1) == 10 {
                    index += 1
                }
                line += 1
                column = 0
            } else {
                column += 1
            }
            index += 1
        }
        return (line, column)
    }

    private func tablesInScope(before location: Int, in string: NSString) -> [SQLAutoCompletionTableFocus] {
        guard string.length > 0 else { return [] }
        let clampedLocation = min(max(location, 0), string.length)
        guard clampedLocation > 0 else { return [] }
        let prefixRange = NSRange(location: 0, length: clampedLocation)
        let substring = string.substring(with: prefixRange)
        return extractTables(from: substring)
    }

    private func tablesInScope(after location: Int, in string: NSString) -> [SQLAutoCompletionTableFocus] {
        guard string.length > 0 else { return [] }
        let clampedLocation = min(max(location, 0), string.length)
        guard clampedLocation < string.length else { return [] }
        let suffixRange = NSRange(location: clampedLocation, length: string.length - clampedLocation)
        let substring = string.substring(with: suffixRange)
        guard !substring.isEmpty else { return [] }
        return extractTables(from: substring)
    }

    private func extractTables(from text: String) -> [SQLAutoCompletionTableFocus] {
        guard !text.isEmpty else { return [] }

        let sourceNames = knownSourceNames()
        if sourceNames.isEmpty {
            return extractTablesFallback(from: text)
        }

        let knownNames = Set(sourceNames.map { $0.uppercased() })
        let tokens = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        var unique: Set<String> = []
        var results: [SQLAutoCompletionTableFocus] = []

        for index in tokens.indices {
            guard let rawWord = lastWord(in: tokens[index]) else { continue }
            let normalizedWord = normalizeIdentifier(rawWord)
            guard !normalizedWord.isEmpty else { continue }
            let upperWord = normalizedWord.uppercased()
            guard knownNames.contains(upperWord) else { continue }

            guard index > 0 else { continue }
            let precedingKeyword = cleanedKeyword(tokens[index - 1])
            guard SQLTextView.objectContextKeywords.contains(precedingKeyword.lowercased()) else { continue }

            var alias: String?
            if index + 1 < tokens.count {
                var potentialAliasToken = tokens[index + 1]
                if potentialAliasToken.caseInsensitiveCompare("AS") == .orderedSame, index + 2 < tokens.count {
                    potentialAliasToken = tokens[index + 2]
                }
                let normalizedAlias = normalizeIdentifier(potentialAliasToken)
                let aliasUpper = normalizedAlias.uppercased()
                if !normalizedAlias.isEmpty,
                   !SQLTextView.aliasTerminatingKeywords.contains(aliasUpper),
                   SQLTextView.isValidIdentifier(normalizedAlias) {
                    alias = normalizedAlias
                }
            }

            let normalizedFullToken = normalizeIdentifier(tokens[index])
            let components = normalizedFullToken.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            let name = components.last ?? normalizedWord
            let schema = components.dropLast().last
            let key = "\(schema?.lowercased() ?? "")|\(name.lowercased())|\(alias?.lowercased() ?? "")"
            guard unique.insert(key).inserted else { continue }
            results.append(SQLAutoCompletionTableFocus(schema: schema, name: name, alias: alias))
        }

        if results.isEmpty {
            return extractTablesFallback(from: text)
        }

        return results
    }

    private func extractTablesFallback(from text: String) -> [SQLAutoCompletionTableFocus] {
        let pattern = #"(?i)\b(from|join|update|into)\s+([A-Za-z0-9_\.\"`\[\]]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        var unique: Set<String> = []
        var results: [SQLAutoCompletionTableFocus] = []

        regex.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let range = match.range(at: 2)
            guard let swiftRange = Range(range, in: text) else { return }
            let rawIdentifier = String(text[swiftRange])
            let normalized = normalizeIdentifier(rawIdentifier)
            guard !normalized.isEmpty else { return }
            let components = normalized.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            guard let name = components.last else { return }
            let schema = components.dropLast().last
            let key = "\(schema?.lowercased() ?? "")|\(name.lowercased())"
            guard unique.insert(key).inserted else { return }
            results.append(SQLAutoCompletionTableFocus(schema: schema, name: name, alias: nil))
        }

        return results
    }

    func applyCompletion(_ suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) {
        let insertion = suggestion.insertText
        var range = query.replacementRange
        guard let textStorage else { return }
        let nsString = string as NSString

        if suggestion.kind != .column {
            var lowerBound = range.location
            let preserveQualifier = !query.pathComponents.isEmpty
            let period: unichar = 46 // "."
            while lowerBound > 0 {
                let character = nsString.character(at: lowerBound - 1)
                if preserveQualifier && character == period { break }
                if !isCompletionCharacter(character) { break }
                lowerBound -= 1
            }
            let upperBound = NSMaxRange(range)
            range = NSRange(location: lowerBound, length: upperBound - lowerBound)
        }

        let maxRange = nsString.length
        var upperBound = NSMaxRange(range)
        while upperBound < maxRange {
            let character = nsString.character(at: upperBound)
            if !isCompletionCharacter(character) { break }
            upperBound += 1
        }
        range.length = upperBound - range.location

        guard shouldChangeText(in: range, replacementString: insertion) else { return }

        isApplyingCompletion = true
        defer {
            isApplyingCompletion = false
            suppressNextCompletionRefresh = false
        }

        textStorage.replaceCharacters(in: range, with: insertion)
        let insertionNSString = insertion as NSString
        let insertionLength = insertionNSString.length
        let appliedRange = NSRange(location: range.location, length: insertionLength)
        finalizeAppliedCompletion(for: suggestion, appliedRange: appliedRange, insertion: insertionNSString)
        let newLocation = NSMaxRange(appliedRange)
        suppressNextCompletionRefresh = true
        setSelectedRange(NSRange(location: newLocation, length: 0))
        hideCompletions()
        didChangeText()
    }

    private enum SymbolHighlightStrength {
        case bright
        case strong
    }

    private func symbolHighlightColor(_ strength: SymbolHighlightStrength) -> NSColor {
        let selectionColor = theme.surfaces.selection.nsColor
        let background = backgroundOverride ?? theme.surfaces.background.nsColor
        let fallback = selectionColor

        let blended: NSColor
        switch strength {
        case .bright:
            if let explicit = theme.surfaces.symbolHighlightBright?.nsColor {
                return explicit
            }
            blended = selectionColor.blended(withFraction: 0.35, of: background) ?? fallback
            return blended.withAlphaComponent(max(blended.alphaComponent, theme.tone == .dark ? 0.55 : 0.65))
        case .strong:
            if let explicit = theme.surfaces.symbolHighlightStrong?.nsColor {
                return explicit
            }
            blended = selectionColor.blended(withFraction: 0.15, of: background) ?? fallback
            return blended.withAlphaComponent(max(blended.alphaComponent, theme.tone == .dark ? 0.8 : 0.75))
        }
    }

    private func wordRange(at location: Int, in string: NSString) -> NSRange? {
        let length = string.length
        guard length > 0 else { return nil }

        var index = max(0, min(location, length))
        if index == length {
            index = max(0, index - 1)
        }

        if !isWordCharacter(string.character(at: index)) {
            if index > 0 && location > 0 && isWordCharacter(string.character(at: index - 1)) {
                index -= 1
            } else {
                return nil
            }
        }

        var start = index
        while start > 0 && isWordCharacter(string.character(at: start - 1)) {
            start -= 1
        }

        var end = index
        while end < length && isWordCharacter(string.character(at: end)) {
            end += 1
        }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func isWholeWord(range: NSRange, in string: NSString) -> Bool {
        guard range.length > 0 else { return false }
        let startBoundary = isBoundary(in: string, index: range.location - 1)
        let endBoundary = isBoundary(in: string, index: NSMaxRange(range))
        return startBoundary && endBoundary
    }

    private func isBoundary(in string: NSString, index: Int) -> Bool {
        guard index >= 0 && index < string.length else { return true }
        return !isWordCharacter(string.character(at: index))
    }

    private func isWordCharacter(_ char: unichar) -> Bool {
        guard let scalar = UnicodeScalar(char) else { return false }
        return SQLTextView.wordCharacterSet.contains(scalar)
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
            .paragraphStyle: paragraphStyle,
            .ligature: theme.ligaturesEnabled ? 1 : 0
        ]

        textStorage.beginEditing()
        textStorage.setAttributes(baseAttributes, range: fullRange)

        var excludedRanges: [NSRange] = []

        excludedRanges += applyRegex(SQLTextView.singleQuotedStringRegex, in: nsString, style: theme.tokenColors.string)
        excludedRanges += applyRegex(SQLEditorRegex.doubleQuotedStringRegex, in: nsString, style: theme.tokenColors.identifier)
        excludedRanges += applyRegex(SQLTextView.blockCommentRegex, in: nsString, style: theme.tokenColors.comment)
        excludedRanges += applyRegex(SQLTextView.singleLineCommentRegex, in: nsString, style: theme.tokenColors.comment)

        _ = applyRegex(SQLTextView.numberRegex, in: nsString, style: theme.tokenColors.number, skip: excludedRanges)
        _ = applyRegex(SQLTextView.operatorRegex, in: nsString, style: theme.tokenColors.operatorSymbol, skip: excludedRanges)
        _ = applyRegex(SQLTextView.keywordRegex, in: nsString, style: theme.tokenColors.keyword, skip: excludedRanges)

        applyFunctionHighlights(in: nsString, skip: excludedRanges)

        textStorage.endEditing()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    private func applyRegex(_ regex: NSRegularExpression,
                            in string: NSString,
                            style: SQLEditorPalette.TokenStyle,
                            skip: [NSRange] = []) -> [NSRange] {
        guard let textStorage = textStorage else { return [] }
        let fullRange = NSRange(location: 0, length: string.length)
        var applied: [NSRange] = []
        let font = font(for: style)
        regex.enumerateMatches(in: string as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let targetRange = match.range
            guard targetRange.length > 0 else { return }
            guard !intersectsExcluded(targetRange, excluded: skip) else { return }
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: style.nsColor]
            if let font {
                attributes[.font] = font
            }
            textStorage.addAttributes(attributes, range: targetRange)
            applied.append(targetRange)
        }
        return applied
    }

    private func font(for style: SQLEditorPalette.TokenStyle) -> PlatformFont? {
        guard style.isBold || style.isItalic else { return nil }
#if os(macOS)
        return style.platformFont(from: theme.nsFont)
#else
        return style.platformFont(from: theme.uiFont)
#endif
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
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: self.theme.tokenColors.function.nsColor
            ]
            if let font = font(for: self.theme.tokenColors.function) {
                attributes[.font] = font
            }
            textStorage.addAttributes(attributes, range: nameRange)
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
        completionEngine.updateAliasPreference(useTableAliases: displayOptions.suggestTableAliasesInCompletion)
        updateParagraphStyle()
        textContainer?.widthTracksTextView = displayOptions.wrapLines
        lineNumberRuler?.highlightedLines = selectedLineRange()
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)

        if displayOptions.highlightSelectedSymbol {
            scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true)
        } else {
            clearSymbolHighlights()
        }

        if displayOptions.autoCompletionEnabled {
            refreshCompletions(immediate: true)
        } else {
            hideCompletions()
        }
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
            .backgroundColor: theme.surfaces.selection.nsColor.withAlphaComponent(0.3),
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

extension SQLTextView {
    func selectLineRange(_ range: ClosedRange<Int>) {
        let nsString = string as NSString
        let startLocation = nsString.locationOfLine(range.lowerBound)
        let endLocation = nsString.endLocationOfLine(range.upperBound)
        let selectionRange = NSRange(location: startLocation, length: endLocation - startLocation)
        setSelectedRange(selectionRange)
        scrollRangeToVisible(selectionRange)
    }
}

extension NSString {
    func lineNumber(at index: Int) -> Int {
        guard length > 0 else { return 1 }
        let clamped = max(0, min(index, length))
        var line = 1
        var position = 0

        while position < clamped {
            let currentChar = character(at: position)
            if currentChar == 10 { // \n
                line += 1
            } else if currentChar == 13 { // \r
                line += 1
                if position + 1 < clamped && character(at: position + 1) == 10 {
                    position += 1
                }
            }
            position += 1
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
    var onAddBookmark: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = theme.uiFont
        textView.textColor = theme.tokenColors.plain.uiColor
        textView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.surfaces.background.uiColor
        textView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.delegate = context.coordinator
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.textContainer.widthTracksTextView = display.wrapLines
        textView.textContainer.lineFragmentPadding = 12
        let ligatureValue = theme.ligaturesEnabled ? 1 : 0
        textView.typingAttributes[.ligature] = ligatureValue
        textView.textStorage.addAttribute(.ligature, value: ligatureValue, range: NSRange(location: 0, length: textView.textStorage.length))
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = theme.uiFont
        uiView.textColor = theme.tokenColors.plain.uiColor
        uiView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.surfaces.background.uiColor
        uiView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        uiView.textContainer.widthTracksTextView = display.wrapLines
        let ligatureValue = theme.ligaturesEnabled ? 1 : 0
        uiView.typingAttributes[.ligature] = ligatureValue
        uiView.textStorage.addAttribute(.ligature, value: ligatureValue, range: NSRange(location: 0, length: uiView.textStorage.length))
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
