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
        // Line height is enforced by SQLLayoutManager's delegate — paragraph style
        // lineSpacing must be 0 to avoid double-spacing.
        style.lineSpacing = 0
        paragraphStyle = style

        // Update the layout manager's font metrics when theme changes.
        if let sqlLayout = layoutManager as? SQLLayoutManager {
            sqlLayout.textFont = theme.nsFont
            sqlLayout.lineHeightMultiple = theme.lineHeightMultiplier
            sqlLayout.extraLineSpacing = theme.lineSpacing
        }

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
            // Period (.) always opens/refreshes — for schema.table.column chaining
            triggerCompletion(immediate: true)
        case .standard:
            // Always ask EchoSense — it decides whether to show completions.
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

    func isIdentifierContinuation(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "$_"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Go to Line

    func goToLine(_ lineNumber: Int) {
        let nsString = string as NSString
        guard lineNumber >= 1 else { return }
        let targetLine = lineNumber
        let location = nsString.locationOfLine(targetLine)
        guard location != NSNotFound else { return }
        let lineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
        setSelectedRange(NSRange(location: lineRange.location, length: 0))
        scrollRangeToVisible(lineRange)
        lineNumberRuler?.highlightedLines = IndexSet(integer: targetLine)
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
    }

    func showGoToLinePanel() {
        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter a line number:"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "Line number"
        field.formatter = NumberFormatter()
        alert.accessoryView = field

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            if let lineNumber = Int(field.stringValue), lineNumber >= 1 {
                self?.goToLine(lineNumber)
            }
        }

        // Focus the text field
        alert.window.initialFirstResponder = field
    }

}
#endif
