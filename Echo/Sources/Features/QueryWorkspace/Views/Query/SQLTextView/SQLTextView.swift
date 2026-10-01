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
        didSet {
            // SwiftUI sets it on every update; rebuilding the catalog costs tens of milliseconds.
            guard completionContext != oldValue else { return }
            let dbCount = completionContext?.structure?.databases.count ?? 0
            let nonEmptyDBs = completionContext?.structure?.databases.filter({ !$0.schemas.isEmpty }).count ?? 0
            crossDBDebug("[CROSSDB-CONTEXT-SET] databases=\(dbCount), withSchemas=\(nonEmptyDBs), selectedDB=\(completionContext?.selectedDatabase ?? "nil")")
            completionEngine.updateContext(completionContext)
            retriggerCompletionsIfNeeded(oldContext: oldValue)
        }
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
    let validationScheduler = SQLValidationScheduler()
    var currentDiagnostics: [SQLDiagnostic] = []
    var validationOverlays: [NSView] = []
    /// QE1: the script's statements (kept between edits) and the one at the caret.
    var cachedStatements: [SQLStatementAtCaret.Match] = []
    var focusedStatementRange: NSRange?
    /// Round 21, SK2: the statement of the result selected in a script's statement list.
    var resultStatementRange: NSRange? { didSet { if oldValue != resultStatementRange { updateResultStatement() } } }
    /// QE5: the outline strip, when the setting is on.
    weak var outlineStrip: EditorOutlineStripView?
    /// ES3: the suggestion shown as ghost text after the caret, with the response it came from.
    var ghostSuggestion: (suggestion: SQLAutoCompletionSuggestion, response: SQLCompletionResponse)?
    var ghostTextLabel: NSTextField?
    /// QE2: the note at the end of what last ran.
    var runNote: QueryRunNote? { didSet { showRunNote() } }
    var runNoteLabel: NSTextField?
    /// Round 21 EM5 / round 22 ED1: the last run's error, as a squiggle with a bubble on hover.
    var errorMark: QueryErrorMark? { didSet { showErrorMark() } }
    var errorMarkView: QueryErrorMarkView?
    /// Round 28.10: whether the empty prompt is drawn.
    var showsEmptyPrompt = true
    override var string: String { didSet { refreshEmptyPrompt() } }
    static let maxValidationOverlays = 10
    let completionEngine = SQLAutoCompletionEngine()
    let ruleEngine = SQLAutocompleteRuleEngine()
    var completionController: SQLAutoCompletionController?
    var lastCompletionResponse: SQLCompletionResponse?
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
    /// Called when completions are requested with a cross-database path prefix (e.g. "employees.")
    /// and that database's schemas are not yet in the completion context.
    /// The caller should trigger an on-demand schema load for the named database.
    var onSchemaLoadNeeded: ((String) -> Void)?

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
    var suppressNextCompletionPopover = false

    init(theme: SQLEditorTheme, displayOptions: SQLEditorDisplayOptions, backgroundOverride: NSColor?, completionContext: SQLEditorCompletionContext? = nil, ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil) {
        self.theme = theme; self.displayOptions = displayOptions; self.backgroundOverride = backgroundOverride; self.completionContext = completionContext
        let textStorage = NSTextStorage(); let layoutManager = SQLLayoutManager(); let textContainer = NSTextContainer(size: NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.textFont = theme.nsFont
        layoutManager.lineHeightMultiple = theme.lineHeightMultiplier
        textStorage.addLayoutManager(layoutManager); layoutManager.addTextContainer(textContainer)
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 360), textContainer: textContainer)
        completionEngine.updateContext(completionContext); completionController = SQLAutoCompletionController(textView: self)
        self.nextResponder = fallbackResponder
        isEditable = true; isSelectable = true; isRichText = false; isAutomaticQuoteSubstitutionEnabled = false; isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false; isAutomaticSpellingCorrectionEnabled = false; isGrammarCheckingEnabled = false
        usesAdaptiveColorMappingForDarkAppearance = false; textContainerInset = NSSize(width: SpacingTokens.xxs, height: SpacingTokens.xs); allowsUndo = true
        usesFindBar = true; isIncrementalSearchingEnabled = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude); minSize = NSSize(width: 0, height: 320)
        isHorizontallyResizable = false; isVerticallyResizable = true; autoresizingMask = [.width]; wantsLayer = true; layer?.isOpaque = true
        if super.undoManager == nil { self.setValue(fallbackResponder.undoManagerInstance, forKey: "undoManager") }
        textContainer.widthTracksTextView = false; textContainer.lineFragmentPadding = SpacingTokens.xxs1
        configureDelegates(); applyTheme(); applyDisplayOptions(); scheduleHighlighting(after: 0)
        if let ruleTraceConfig { isRuleTracingEnabled = ruleTraceConfig.isEnabled; onRuleTrace = ruleTraceConfig.onTrace }
        NotificationCenter.default.addObserver(self, selector: #selector(handleCompletionContextUpdate(_:)), name: .completionContextDidUpdate, object: nil)
    }

    @objc private func handleCompletionContextUpdate(_ notification: Notification) {
        guard let context = notification.object as? SQLEditorCompletionContext else { return }
        completionContext = context
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(ruler: LineNumberRulerView) { lineNumberRuler = ruler }
    private func configureDelegates() { delegate = self }

    func applyTheme() {
        font = theme.nsFont; textColor = theme.tokenColors.plain.nsColor; insertionPointColor = .textInsertionPointColor
        drawsBackground = true; backgroundColor = backgroundOverride ?? theme.surfaces.background.nsColor; typingAttributes[.ligature] = theme.ligaturesEnabled ? 1 : 0
        updateParagraphStyle(); lineNumberRuler?.theme = theme
        let range = selectedLineRange()
        if range.location != NSNotFound { lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length)) }
        else { lineNumberRuler?.highlightedLines = IndexSet() }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero); scheduleHighlighting(after: 0)
        if displayOptions.highlightSelectedSymbol { scheduleSymbolHighlights(for: currentSelectionDescriptor(), immediate: true) }
        completionController?.panel.appearance = effectiveAppearance
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let ruler = enclosingScrollView?.verticalRulerView as? LineNumberRulerView { configure(ruler: ruler); ruler.sqlTextView = self }
        Task { @MainActor [weak self] in guard let self else { return }; self.window?.makeFirstResponder(self) }
    }

    override func keyDown(with event: NSEvent) {
        if acceptGhostTextIfNeeded(event) { return }
        if event.keyCode == 48 && !event.modifierFlags.contains(.shift) && expandSelectStarShorthandIfNeeded() { return }
        if handleSnippetNavigation(event) || completionController?.handleKeyDown(event) == true { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.charactersIgnoringModifiers == "l" { showGoToLinePanel(); return true }
        return super.performKeyEquivalent(with: event)
    }

    override func complete(_ sender: Any?) {
        _ = presentRequestedCompletions()
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        suppressNextCompletionPopover = false; let trigger = determineCompletionTrigger(for: string); super.insertText(string, replacementRange: replacementRange)
        let inserted = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        handleCompletionTrigger(trigger, insertedText: inserted)
        if inserted == ")" { flashMatchingBracket(closingAt: selectedRange().location - 1) }
    }

    override func deleteBackward(_ sender: Any?) {
        super.deleteBackward(sender)
        schedulePostDeletionRefresh()
    }

    override func deleteForward(_ sender: Any?) {
        super.deleteForward(sender)
        schedulePostDeletionRefresh()
    }

    var deletionRefreshWorkItem: DispatchWorkItem?

    private func schedulePostDeletionRefresh() {
        deletionRefreshWorkItem?.cancel()

        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound else { return }
        let nsString = string as NSString
        guard caretLocation <= nsString.length else { return }

        // After a dot → immediate (e.g., deleted "Customer" from "Sales.Customer" → now "Sales.")
        if caretLocation > 0 {
            let charBefore = nsString.character(at: caretLocation - 1)
            if charBefore == UnicodeScalar(".").value {
                deactivateManualCompletionSuppression()
                refreshCompletions(immediate: true)
                return
            }
        }

        // After a keyword space → immediate (e.g., deleted table name from "FROM users" → now "FROM ")
        if shouldTriggerAfterKeywordSpace() {
            deactivateManualCompletionSuppression()
            refreshCompletions(immediate: true)
            return
        }

        // Otherwise → debounced refresh (200ms) for general context re-evaluation
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.deletionRefreshWorkItem = nil
            if self.isCompletionVisible {
                self.deactivateManualCompletionSuppression()
                self.refreshCompletions(immediate: true)
            }
        }
        deletionRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    override func resignFirstResponder() -> Bool { hideCompletions(); return super.resignFirstResponder() }
    override func mouseDown(with event: NSEvent) { hideCompletions(); suppressNextCompletionPopover = true; window?.makeFirstResponder(self); super.mouseDown(with: event); notifySelectionPreview() }
    override func becomeFirstResponder() -> Bool { suppressNextCompletionPopover = true; return super.becomeFirstResponder() }

    func reapplyHighlighting() { scheduleHighlighting(after: 0) }

    override func didChangeText() {
        super.didChangeText(); sqlDelegate?.sqlTextView(self, didUpdateText: string); lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        refreshEmptyPrompt()
        notifySelectionChanged(); scheduleHighlighting()
        if !isApplyingCompletion { deactivateManualCompletionSuppression() }
        updateCompletionIndicator(); scheduleValidation()
        refreshStatements()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        (layoutManager as? SQLLayoutManager)?.selectedRanges = selectedRanges.map(\.rangeValue)
        notifySelectionChanged(); updateStatementFocus(); let range = selectedLineRange()
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
