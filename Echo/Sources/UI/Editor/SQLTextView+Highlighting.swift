#if os(macOS)
import AppKit

extension SQLTextView {

    func scheduleHighlighting(after delay: TimeInterval = 0.05) {
        highlightWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.performHighlighting()
        }
        highlightWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func performHighlighting() {
        guard let textStorage = self.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.plain.nsColor, range: fullRange)
        textStorage.addAttribute(.font, value: theme.nsFont, range: fullRange)
        textStorage.addAttribute(.ligature, value: theme.ligaturesEnabled ? 1 : 0, range: fullRange)
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

        // Comments
        Self.blockCommentRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.comment.nsColor, range: range)
            }
        }
        Self.singleLineCommentRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.comment.nsColor, range: range)
            }
        }

        // Strings
        Self.singleQuotedStringRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.string.nsColor, range: range)
            }
        }
        SQLEditorRegex.doubleQuotedStringRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.identifier.nsColor, range: range)
            }
        }

        // Numbers
        Self.numberRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.number.nsColor, range: range)
            }
        }

        // Keywords
        Self.keywordRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.keyword.nsColor, range: range)
            }
        }

        // Functions
        Self.functionRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range(at: 1) {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.function.nsColor, range: range)
            }
        }

        // Operators
        Self.operatorRegex.enumerateMatches(in: textStorage.string, range: fullRange) { result, _, _ in
            if let range = result?.range {
                textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.operatorSymbol.nsColor, range: range)
            }
        }

        applyMatchHighlights(to: textStorage)
        textStorage.endEditing()
    }

    func applyMatchHighlights(to textStorage: NSTextStorage) {
        for range in selectionMatchRanges {
            if sqlRangeIsValid(range, upperBound: textStorage.length) {
                textStorage.addAttribute(.backgroundColor, value: theme.tokenColors.keyword.nsColor.withAlphaComponent(0.2), range: range)
            }
        }
        for range in caretMatchRanges {
            if sqlRangeIsValid(range, upperBound: textStorage.length) {
                textStorage.addAttribute(.backgroundColor, value: theme.tokenColors.keyword.nsColor.withAlphaComponent(0.3), range: range)
            }
        }
    }

    func scheduleSymbolHighlights(for selection: SQLEditorSelection, immediate: Bool = false) {
        symbolHighlightWorkItem?.cancel()

        guard displayOptions.highlightSelectedSymbol else {
            clearSymbolHighlights()
            return
        }

        guard selection.range.location != NSNotFound else {
            clearSymbolHighlights()
            return
        }

        let delay = immediate ? 0 : 0.15
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySymbolHighlights(for: selection)
        }
        symbolHighlightWorkItem = workItem
        let deadline: DispatchTime = delay <= 0 ? .now() : .now() + delay
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    func applySymbolHighlights(for selection: SQLEditorSelection) {
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

    func updateParagraphStyle() {
        paragraphStyle.lineSpacing = theme.lineSpacing
        paragraphStyle.minimumLineHeight = theme.nsFont.pointSize * 1.2
        paragraphStyle.maximumLineHeight = theme.nsFont.pointSize * 1.4
        defaultParagraphStyle = paragraphStyle
    }

    func applyDisplayOptions() {
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        usesFontPanel = false
        lnv_setUpLineNumberView()
        scheduleHighlighting(after: 0)
    }

    func lnv_setUpLineNumberView() {
        if displayOptions.showLineNumbers {
            if let scrollView = enclosingScrollView {
                scrollView.rulersVisible = true
                if let ruler = scrollView.verticalRulerView as? LineNumberRulerView {
                    lineNumberRuler = ruler
                    ruler.clientView = self
                }
            }
        } else {
            enclosingScrollView?.rulersVisible = false
        }
    }

    func selectedLineRange() -> NSRange {
        let selection = selectedRange()
        guard selection.location != NSNotFound else { return NSRange(location: 0, length: 0) }
        let nsString = string as NSString
        let startLine = nsString.substring(to: selection.location).components(separatedBy: .newlines).count
        let endLine = nsString.substring(to: NSMaxRange(selection)).components(separatedBy: .newlines).count
        return NSRange(location: startLine, length: endLine - startLine + 1)
    }

    func selectedLines(for range: NSRange) -> ClosedRange<Int>? {
        guard range.location != NSNotFound else { return nil }
        let nsString = string as NSString
        let startLine = nsString.substring(to: range.location).components(separatedBy: .newlines).count
        let endLine = nsString.substring(to: NSMaxRange(range)).components(separatedBy: .newlines).count
        return startLine...endLine
    }

    func isWholeWord(range: NSRange, in string: NSString) -> Bool {
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

    func wordRange(at location: Int, in string: NSString) -> NSRange? {
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
}
#endif
