#if os(macOS)
import AppKit
import Combine
import EchoSense

@MainActor
final class SQLTextView: NSTextView, NSTextViewDelegate {
    private final class FallbackResponder: NSResponder {
        private let manager = UndoManager()
        override var undoManager: UndoManager? { manager }
        var undoManagerInstance: UndoManager { manager }
    }

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

    let sqruffProvider = SqruffCompletionProvider.shared
    weak var lineNumberRuler: LineNumberRulerView?
    var paragraphStyle = NSMutableParagraphStyle()
    var highlightWorkItem: DispatchWorkItem?
    var symbolHighlightWorkItem: DispatchWorkItem?
    var selectionMatchRanges: [NSRange] = []
    var caretMatchRanges: [NSRange] = []
    var completionWorkItem: DispatchWorkItem?
    var completionTask: Task<Void, Never>?
    var completionGeneration = 0
    let completionEngine = SQLAutoCompletionEngine()
    let ruleEngine = SQLAutocompleteRuleEngine()
    var completionController: SQLAutoCompletionController?
    var isApplyingCompletion = false
    var suppressNextCompletionRefresh = false
    var manualCompletionSuppression = false
    
    struct SnippetPlaceholderPosition {
        var range: NSRange
    }
    var activeSnippetPlaceholders: [SnippetPlaceholderPosition] = []
    var currentSnippetPlaceholderIndex: Int = -1
    var isAdjustingSnippetSelection = false
    var isRuleTracingEnabled: Bool = false
    var onRuleTrace: ((SQLAutocompleteTrace) -> Void)?
    private let fallbackResponder = FallbackResponder()

    struct SuppressedCompletion: Equatable {
        var tokenRange: NSRange
        let canonicalText: String
        let hasFollowUps: Bool
        var allowTrailingWhitespace: Bool = false

        init(tokenRange: NSRange,
             canonicalText: String,
             hasFollowUps: Bool,
             allowTrailingWhitespace: Bool = false) {
            self.tokenRange = tokenRange
            self.canonicalText = canonicalText
            self.hasFollowUps = hasFollowUps
            self.allowTrailingWhitespace = allowTrailingWhitespace
        }

        var isValid: Bool {
            tokenRange.location != NSNotFound && tokenRange.length > 0
        }

        var asRuleSuppression: SQLAutocompleteRuleEngine.Suppression {
            SQLAutocompleteRuleEngine.Suppression(tokenRange: tokenRange,
                                                  canonicalText: canonicalText,
                                                  hasFollowUps: hasFollowUps)
        }
    }

    struct StructureObjectMatch {
        let database: String?
        let schema: SchemaInfo
        let object: SchemaObjectInfo
    }

    var suppressedCompletions: [SuppressedCompletion] = []
    var completionIndicatorView: CompletionAccessoryView?
    var inlineSuggestionView: InlineSuggestionLabel?
    var inlineKeywordSuggestions: [SQLAutoCompletionSuggestion] = []
    var inlineSuggestionQuery: SQLAutoCompletionQuery?
    var inlineSuggestionNextIndex: Int = 0
    var inlineInsertedRange: NSRange?
    var inlineInsertedIndex: Int?
    var isInlineSuggestionActive: Bool {
        !inlineKeywordSuggestions.isEmpty || inlineInsertedRange != nil
    }
    var inlineAcceptanceInProgress = false
    var suppressNextCompletionPopover = false

    var ruleEnvironment: SQLAutocompleteRuleEngine.Environment {
        SQLAutocompleteRuleEngine.Environment(completionContext: completionContext)
    }

    enum CompletionTriggerKind {
        case none
        case standard
        case immediate
        case evaluateSpace
    }

    var isCompletionVisible: Bool {
        completionController?.isPresenting ?? false
    }

    static let keywords: [String] = [
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

    static let singleLineCommentRegex = try! NSRegularExpression(pattern: #"--[^\n]*"#, options: [])
    static let blockCommentRegex = try! NSRegularExpression(pattern: #"\/\*[\s\S]*?\*\/"#, options: [.dotMatchesLineSeparators])
    static let singleQuotedStringRegex = try! NSRegularExpression(pattern: #"'([^']|'')*'"#, options: [])
    static let numberRegex = try! NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#, options: [])
    static let aliasTerminatingKeywords: Set<String> = ["WHERE", "INNER", "LEFT", "RIGHT", "ON", "JOIN", "SET", "ORDER", "GROUP", "HAVING", "LIMIT"]
    static let operatorRegex = try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9_])(?:<>|!=|>=|<=|::|\*\*|[-+*/=%<>!]+)"#, options: [])
    static let functionRegex = try! NSRegularExpression(pattern: #"\b([A-Z_][A-Z0-9_]*)\s*(?=\()"#, options: [.caseInsensitive])
    static let keywordRegex: NSRegularExpression = {
        let pattern = #"\b(?:"# + keywords.joined(separator: "|") + #")\b"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
    static let identifierRegex = try! NSRegularExpression(pattern: #"\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\b"#, options: [])
    static let allKeywords: Set<String> = Set(keywords.map { $0.lowercased() })
    static let wordCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_$")
        return set
    }()
    static let identifierDelimiterCharacterSet: CharacterSet = CharacterSet(charactersIn: #""`[]"#)
    static let completionTokenCharacterSet: CharacterSet = {
        var set = wordCharacterSet
        set.insert(charactersIn: #".\"`[]"#)
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
        self.nextResponder = fallbackResponder

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

        if super.undoManager == nil {
            self.setValue(fallbackResponder.undoManagerInstance, forKey: "undoManager")
        }

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

    func applyTheme() {
        font = theme.nsFont
        textColor = theme.tokenColors.plain.nsColor
        insertionPointColor = theme.tokenColors.operatorSymbol.nsColor
        drawsBackground = true
        backgroundColor = backgroundOverride ?? theme.surfaces.background.nsColor
        typingAttributes[.ligature] = theme.ligaturesEnabled ? 1 : 0
        updateParagraphStyle()
        lineNumberRuler?.theme = theme
        let range = selectedLineRange()
        if range.location != NSNotFound {
            lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length))
        } else {
            lineNumberRuler?.highlightedLines = IndexSet()
        }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        scheduleHighlighting(after: 0)
        if displayOptions.highlightSelectedSymbol {
            scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true)
        }
        applyInlineSuggestionAppearance()
        updateInlineSuggestionPosition()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let ruler = enclosingScrollView?.verticalRulerView as? LineNumberRulerView {
            configure(ruler: ruler)
            ruler.sqlTextView = self
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
            self.primeInlineSuggestionsIfNeeded()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48, !event.modifierFlags.contains(.shift) {
            if expandSelectStarShorthandIfNeeded() {
                return
            }
        }
        if handleInlineSuggestionKey(event) {
            return
        }
        if handleSnippetNavigation(event) {
            return
        }
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
        suppressNextCompletionPopover = false
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
        suppressNextCompletionPopover = true
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
        notifySelectionPreview()
    }

    override func becomeFirstResponder() -> Bool {
        suppressNextCompletionPopover = true
        let became = super.becomeFirstResponder()
        if became {
            primeInlineSuggestionsIfNeeded()
        }
        return became
    }

    func determineCompletionTrigger(for string: Any) -> CompletionTriggerKind {
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

    func handleCompletionTrigger(_ trigger: CompletionTriggerKind, insertedText: String) {
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

    func triggerCompletion(immediate: Bool) {
        guard displayOptions.autoCompletionEnabled else { return }
        guard !manualCompletionSuppression else { return }
        if isAliasTypingContext() { return }
        suppressNextCompletionRefresh = true
        refreshCompletions(immediate: immediate)
    }

    func primeInlineSuggestionsIfNeeded() {
        guard window != nil else { return }
        guard displayOptions.autoCompletionEnabled else { return }
        guard displayOptions.inlineKeywordSuggestionsEnabled else { return }
        guard completionContext != nil else { return }
        guard !manualCompletionSuppression else { return }
        guard inlineInsertedRange == nil else { return }
        guard inlineSuggestionView == nil else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return }
        suppressNextCompletionPopover = true
        refreshCompletions(immediate: true)
    }

    func shouldTriggerAfterKeywordSpace() -> Bool {
        let linePrefix = currentLinePrefix()
        guard !linePrefix.isEmpty else { return false }
        let pattern = #"(?i)(from|join|update|call|exec|execute|into)\s*$"#
        return linePrefix.range(of: pattern, options: .regularExpression) != nil
    }

    func currentLinePrefix() -> String {
        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound else { return "" }
        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: caretLocation, length: 0))
        let prefixLength = max(0, caretLocation - lineRange.location)
        guard prefixLength > 0 else { return "" }
        return nsString.substring(with: NSRange(location: lineRange.location, length: prefixLength))
    }

    func isAliasTypingContext() -> Bool {
        let prefix = currentLinePrefix()
        guard !prefix.isEmpty else { return false }
        let pattern = #"(?i)\b(from|join|update|into)\s+([A-Za-z0-9_\.\"`\[\]]+)\s+[A-Za-z_][A-Za-z0-9_]*$"#
        return prefix.range(of: pattern, options: .regularExpression) != nil
    }

    func isIdentifierContinuation(_ value: String) -> Bool {
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
        let range = selectedLineRange()
        if range.location != NSNotFound {
            lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length))
        } else {
            lineNumberRuler?.highlightedLines = IndexSet()
        }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        guard !isAdjustingSnippetSelection else { return }
        guard !activeSnippetPlaceholders.isEmpty else { return }
        let selection = selectedRange()
        if selection.location == NSNotFound {
            clearSnippetPlaceholders()
            return
        }
        if let index = snippetPlaceholderIndex(containing: selection) {
            currentSnippetPlaceholderIndex = index
        } else {
            clearSnippetPlaceholders()
        }
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

    func snippetPlaceholderIndex(containing selection: NSRange) -> Int? {
        guard selection.location != NSNotFound else { return nil }
        for (index, placeholder) in activeSnippetPlaceholders.enumerated() {
            let placeholderRange = placeholder.range
            if selection.length == 0 {
                if NSLocationInRange(selection.location, placeholderRange) ||
                    selection.location == NSMaxRange(placeholderRange) {
                    return index
                }
            } else {
                let start = selection.location
                let end = NSMaxRange(selection)
                if start >= placeholderRange.location &&
                    end <= NSMaxRange(placeholderRange) {
                    return index
                }
            }
        }
        return nil
    }

    func adjustedInsertion(for suggestion: SQLAutoCompletionSuggestion,
                                   originalText: String,
                                   proposedInsertion: String) -> String {
        switch suggestion.kind {
        case .column, .table, .view, .materializedView:
            break
        default:
            return proposedInsertion
        }

        let prefixCount = proposedInsertion.prefix { $0.isWhitespace }.count
        let suffixCount = proposedInsertion.reversed().prefix { $0.isWhitespace }.count
        let prefixString = String(proposedInsertion.prefix(prefixCount))
        let suffixString = String(proposedInsertion.suffix(suffixCount))

        let coreStartIndex = proposedInsertion.index(proposedInsertion.startIndex, offsetBy: prefixCount)
        let coreEndIndex = proposedInsertion.index(proposedInsertion.endIndex, offsetBy: -suffixCount)
        guard coreStartIndex <= coreEndIndex else { return proposedInsertion }
        let core = String(proposedInsertion[coreStartIndex..<coreEndIndex])
        guard !core.isEmpty else { return proposedInsertion }

        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty else { return proposedInsertion }

        let originalComponents = trimmedOriginal.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let proposedComponents = core.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard !originalComponents.isEmpty else { return proposedInsertion }

        let wrappedComponents: [String]
        if originalComponents.count == proposedComponents.count {
            wrappedComponents = zip(originalComponents, proposedComponents).map { wrapComponent($1, using: $0) }
        } else if originalComponents.count == 1 {
            if proposedComponents.count > 1 {
                let lastComponent = String(proposedComponents.last!)
                wrappedComponents = [wrapComponent(lastComponent, using: originalComponents[0])]
            } else {
                wrappedComponents = [wrapComponent(core, using: originalComponents[0])]
            }
        } else {
            return proposedInsertion
        }

        let wrappedCore = wrappedComponents.joined(separator: ".")
        return prefixString + wrappedCore + suffixString
    }

    private func wrapComponent(_ component: String, using originalComponent: String) -> String {
        let trimmedOriginal = originalComponent.trimmingCharacters(in: .whitespaces)
        guard let first = trimmedOriginal.first else { return component }

        let delimiterPairs: [Character: Character] = ["\"": "\"", "`": "`", "[": "]"]
        guard let closing = delimiterPairs[first], trimmedOriginal.last == closing else {
            return component
        }

        let trimmedComponent = component.trimmingCharacters(in: .whitespaces)
        if trimmedComponent.first == first && trimmedComponent.last == closing {
            return component
        }

        let inner = trimmedComponent.trimmingCharacters(in: CharacterSet(charactersIn: "\"`[]"))
        return "\(first)\(inner)\(closing)"
    }

    static func isValidIdentifier(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        let identifierBody = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy { identifierBody.contains($0) }
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

final class InlineSuggestionLabel: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        isEditable = false
        isSelectable = false
        drawsBackground = false
        lineBreakMode = .byClipping
        alignment = .left
        stringValue = ""
        usesSingleLineMode = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
