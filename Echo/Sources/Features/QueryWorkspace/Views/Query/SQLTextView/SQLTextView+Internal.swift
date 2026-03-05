#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    func sqlRangeIsValid(_ range: NSRange, upperBound: Int) -> Bool {
        range.location != NSNotFound && NSMaxRange(range) <= upperBound
    }

    func selectedLineRange() -> NSRange {
        let selection = selectedRange()
        guard selection.location != NSNotFound else { return NSRange(location: NSNotFound, length: 0) }
        let nsString = string as NSString
        let startLine = nsString.lineNumber(at: selection.location)
        let endLine = nsString.lineNumber(at: NSMaxRange(selection))
        return NSRange(location: startLine, length: endLine - startLine + 1)
    }

    func selectedLines(for range: NSRange) -> ClosedRange<Int>? {
        guard range.location != NSNotFound else { return nil }
        let nsString = string as NSString
        let startLine = nsString.lineNumber(at: range.location)
        let endLine = nsString.lineNumber(at: NSMaxRange(range))
        return startLine...endLine
    }

    func selectLineRange(_ range: ClosedRange<Int>) {
        let nsString = string as NSString
        let startLocation = nsString.locationOfLine(range.lowerBound)
        let endLocation = nsString.endLocationOfLine(range.upperBound)
        let selectionRange = NSRange(location: startLocation, length: endLocation - startLocation)
        setSelectedRange(selectionRange)
        scrollRangeToVisible(selectionRange)
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

    func applyDisplayOptions() {
        if let scrollView = enclosingScrollView as? SQLScrollView {
            scrollView.setRulerVisible(displayOptions.showLineNumbers)
        }
        
        let container = textContainer
        if displayOptions.wrapLines {
            container?.widthTracksTextView = true
            isHorizontallyResizable = false
        } else {
            container?.widthTracksTextView = false
            container?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            isHorizontallyResizable = true
        }
        
        reapplyHighlighting()
    }

    func updateParagraphStyle() {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = theme.lineSpacing
        style.minimumLineHeight = theme.fontSize * theme.lineHeightMultiplier
        style.maximumLineHeight = theme.fontSize * theme.lineHeightMultiplier
        paragraphStyle = style
        
        let nsString = string as NSString
        if nsString.length > 0 {
            textStorage?.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: nsString.length))
        }
        typingAttributes[.paragraphStyle] = style
    }

    func isWholeWord(range: NSRange, in string: NSString) -> Bool {
        let start = range.location
        let end = NSMaxRange(range)
        
        if start > 0 {
            let before = string.character(at: start - 1)
            if let scalar = UnicodeScalar(UInt32(before)), CharacterSet.alphanumerics.contains(scalar) {
                return false
            }
        }
        
        if end < string.length {
            let after = string.character(at: end)
            if let scalar = UnicodeScalar(UInt32(after)), CharacterSet.alphanumerics.contains(scalar) {
                return false
            }
        }
        
        return true
    }

    func currentSelectionDescriptor() -> SelectionDescriptor {
        let range = selectedRange()
        if range.length == 0 {
            let wordRange = self.selectionRange(forProposedRange: range, granularity: .selectByWord)
            let word = (string as NSString).substring(with: wordRange)
            return SelectionDescriptor(range: wordRange, word: word)
        } else {
            let word = (string as NSString).substring(with: range)
            return SelectionDescriptor(range: range, word: word)
        }
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

}
#endif
