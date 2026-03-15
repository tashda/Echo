#if os(macOS)
import AppKit
import Combine
import EchoSense

final class SQLTextView: NSTextView, NSTextViewDelegate {
    weak var sqlDelegate: SQLTextViewDelegate?
    weak var clipboardHistory: ClipboardHistoryStore?
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty
    var theme: SQLEditorTheme { didSet { applyTheme() } }
    var displayOptions: SQLEditorDisplayOptions { didSet { applyDisplayOptions() } }
    var backgroundOverride: NSColor? { didSet { applyTheme() } }
    var completionContext: SQLEditorCompletionContext? {
        didSet { completionEngine.updateContext(completionContext); refreshCompletions(immediate: true) }
    }

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

        var asRuleSuppression: SQLAutocompleteRuleModels.Suppression {
            SQLAutocompleteRuleModels.Suppression(tokenRange: tokenRange,
                                                  canonicalText: canonicalText,
                                                  hasFollowUps: hasFollowUps)
        }
    }

    var activeSnippetPlaceholders: [SnippetPlaceholderPosition] = []
    var currentSnippetPlaceholderIndex: Int = -1
    var isAdjustingSnippetSelection = false
    var isRuleTracingEnabled: Bool = false
    var onRuleTrace: ((SQLAutocompleteTrace) -> Void)?

    private final class FallbackResponder: NSResponder {
        private let manager = UndoManager()
        override var undoManager: UndoManager? { manager }
        var undoManagerInstance: UndoManager { manager }
    }

    private let fallbackResponder = FallbackResponder()

    var isCompletionVisible: Bool { completionController?.isPresenting == true }
    var ruleEnvironment: SQLAutocompleteRuleModels.Environment {
        SQLAutocompleteRuleModels.Environment(completionContext: completionContext)
    }

    var suppressedCompletions: [SuppressedCompletion] = []
    var completionIndicatorView: CompletionAccessoryView?
    var inlineSuggestionView: InlineSuggestionLabel?
    var inlineKeywordSuggestions: [SQLAutoCompletionSuggestion] = []
    var inlineSuggestionQuery: SQLAutoCompletionQuery?
    var inlineSuggestionNextIndex: Int = 0
    var inlineInsertedRange: NSRange?
    var inlineInsertedIndex: Int?
    var isInlineSuggestionActive: Bool { !inlineKeywordSuggestions.isEmpty || inlineInsertedRange != nil }
    var inlineAcceptanceInProgress = false
    var suppressNextCompletionPopover = false

    init(theme: SQLEditorTheme, displayOptions: SQLEditorDisplayOptions, backgroundOverride: NSColor?, completionContext: SQLEditorCompletionContext? = nil, ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil) {
        self.theme = theme; self.displayOptions = displayOptions; self.backgroundOverride = backgroundOverride; self.completionContext = completionContext
        let textStorage = NSTextStorage(); let layoutManager = SQLLayoutManager(); let textContainer = NSTextContainer(size: NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.textFont = theme.nsFont
        layoutManager.lineHeightMultiple = theme.lineHeightMultiplier
        layoutManager.extraLineSpacing = theme.lineSpacing
        textStorage.addLayoutManager(layoutManager); layoutManager.addTextContainer(textContainer)
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 360), textContainer: textContainer)
        completionEngine.updateContext(completionContext); completionController = SQLAutoCompletionController(textView: self)
        self.nextResponder = fallbackResponder
        isEditable = true; isSelectable = true; isRichText = false; isAutomaticQuoteSubstitutionEnabled = false; isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false; isAutomaticSpellingCorrectionEnabled = false; isGrammarCheckingEnabled = false
        usesAdaptiveColorMappingForDarkAppearance = false; textContainerInset = NSSize(width: 10, height: 4); allowsUndo = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude); minSize = NSSize(width: 0, height: 320)
        isHorizontallyResizable = false; isVerticallyResizable = true; autoresizingMask = [.width]; wantsLayer = true; layer?.isOpaque = true
        if super.undoManager == nil { self.setValue(fallbackResponder.undoManagerInstance, forKey: "undoManager") }
        textContainer.widthTracksTextView = false; textContainer.lineFragmentPadding = 10
        configureDelegates(); applyTheme(); applyDisplayOptions(); scheduleHighlighting(after: 0)
        if let ruleTraceConfig { isRuleTracingEnabled = ruleTraceConfig.isEnabled; onRuleTrace = ruleTraceConfig.onTrace }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(ruler: LineNumberRulerView) { lineNumberRuler = ruler }
    private func configureDelegates() { delegate = self }

    func applyTheme() {
        font = theme.nsFont; textColor = theme.tokenColors.plain.nsColor; insertionPointColor = theme.tokenColors.operatorSymbol.nsColor
        drawsBackground = true; backgroundColor = backgroundOverride ?? theme.surfaces.background.nsColor; typingAttributes[.ligature] = theme.ligaturesEnabled ? 1 : 0
        updateParagraphStyle(); lineNumberRuler?.theme = theme
        let range = selectedLineRange()
        if range.location != NSNotFound { lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length)) }
        else { lineNumberRuler?.highlightedLines = IndexSet() }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero); scheduleHighlighting(after: 0)
        if displayOptions.highlightSelectedSymbol { scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true) }
        applyInlineSuggestionAppearance(); updateInlineSuggestionPosition()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let ruler = enclosingScrollView?.verticalRulerView as? LineNumberRulerView { configure(ruler: ruler); ruler.sqlTextView = self }
        Task { @MainActor [weak self] in guard let self else { return }; self.window?.makeFirstResponder(self); self.primeInlineSuggestionsIfNeeded() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 && !event.modifierFlags.contains(.shift) && expandSelectStarShorthandIfNeeded() { return }
        if handleInlineSuggestionKey(event) || handleSnippetNavigation(event) || completionController?.handleKeyDown(event) == true || handleCommandShortcut(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool { if handleCommandShortcut(event) { return true }; return super.performKeyEquivalent(with: event) }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        suppressNextCompletionPopover = false; let trigger = determineCompletionTrigger(for: string); super.insertText(string, replacementRange: replacementRange)
        handleCompletionTrigger(trigger, insertedText: (string as? String) ?? (string as? NSAttributedString)?.string ?? "")
    }

    override func resignFirstResponder() -> Bool { hideCompletions(); return super.resignFirstResponder() }
    override func mouseDown(with event: NSEvent) { suppressNextCompletionPopover = true; window?.makeFirstResponder(self); super.mouseDown(with: event); notifySelectionPreview() }
    override func becomeFirstResponder() -> Bool { suppressNextCompletionPopover = true; let became = super.becomeFirstResponder(); if became { primeInlineSuggestionsIfNeeded() }; return became }

    func reapplyHighlighting() { scheduleHighlighting(after: 0) }

    override func didChangeText() {
        super.didChangeText(); sqlDelegate?.sqlTextView(self, didUpdateText: string); lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        notifySelectionChanged(); scheduleHighlighting()
        if !isApplyingCompletion { if suppressNextCompletionRefresh { suppressNextCompletionRefresh = false } else if isCompletionVisible { refreshCompletions() } else { hideCompletions() } }
        updateCompletionIndicator()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        notifySelectionChanged(); let range = selectedLineRange()
        if range.location != NSNotFound { lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length)) }
        else { lineNumberRuler?.highlightedLines = IndexSet() }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        guard !isAdjustingSnippetSelection, !activeSnippetPlaceholders.isEmpty else { return }
        let selection = selectedRange()
        if selection.location == NSNotFound { clearSnippetPlaceholders(); return }
        if let index = snippetPlaceholderIndex(containing: selection) { currentSnippetPlaceholderIndex = index } else { clearSnippetPlaceholders() }
    }

    override func mouseDragged(with event: NSEvent) { super.mouseDragged(with: event); notifySelectionPreview() }

    override func copy(_ sender: Any?) {
        let selection = selectedRange(); super.copy(sender)
        guard selection.length > 0, let clipboardHistory, let copied = PlatformClipboard.paste() else { return }
        clipboardHistory.record(.queryEditor, content: copied, metadata: clipboardMetadata)
    }
}
#endif
