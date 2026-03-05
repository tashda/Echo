#if os(macOS)
import AppKit
import Combine
import EchoSense

extension SQLTextView {
    
    // MARK: - Highlighting Orchestration
    
    func scheduleHighlighting(after delay: TimeInterval = 0.05) {
        highlightWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.applySyntaxHighlighting()
        }
        highlightWorkItem = workItem
        if delay == 0 {
            workItem.perform()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func applySyntaxHighlighting() {
        guard let textStorage = layoutManager?.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.plain.nsColor, range: fullRange)
        
        // Highlight logic (regex application)
        applyRegex(Self.singleLineCommentRegex, color: theme.tokenColors.comment.nsColor, in: textStorage, range: fullRange)
        applyRegex(Self.blockCommentRegex, color: theme.tokenColors.comment.nsColor, in: textStorage, range: fullRange)
        applyRegex(Self.singleQuotedStringRegex, color: theme.tokenColors.string.nsColor, in: textStorage, range: fullRange)
        applyRegex(Self.numberRegex, color: theme.tokenColors.number.nsColor, in: textStorage, range: fullRange)
        applyRegex(Self.keywordRegex, color: theme.tokenColors.keyword.nsColor, in: textStorage, range: fullRange)
        applyRegex(Self.functionRegex, color: theme.tokenColors.function.nsColor, in: textStorage, range: fullRange)
        applyRegex(Self.operatorRegex, color: theme.tokenColors.operatorSymbol.nsColor, in: textStorage, range: fullRange)

        applySymbolMatches(in: textStorage, range: fullRange)
        textStorage.endEditing()
    }

    private func applyRegex(_ regex: NSRegularExpression, color: NSColor, in textStorage: NSTextStorage, range: NSRange) {
        regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                textStorage.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }
    }

    private func applySymbolMatches(in textStorage: NSTextStorage, range: NSRange) {
        for matchRange in selectionMatchRanges {
            if NSIntersectionRange(matchRange, range).length > 0 {
                textStorage.addAttribute(.backgroundColor, value: theme.surfaces.selection.nsColor.withAlphaComponent(0.3), range: matchRange)
            }
        }
        for matchRange in caretMatchRanges {
            if NSIntersectionRange(matchRange, range).length > 0 {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
                textStorage.addAttribute(.underlineColor, value: theme.tokenColors.keyword.nsColor.withAlphaComponent(0.5), range: matchRange)
            }
        }
    }

    func scheduleSymbolHighlights(for descriptor: SelectionDescriptor, immediate: Bool = false) {
        symbolHighlightWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.updateSymbolHighlights(for: descriptor)
        }
        symbolHighlightWorkItem = workItem
        if immediate { workItem.perform() }
        else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem) }
    }

    private func updateSymbolHighlights(for descriptor: SelectionDescriptor) {
        let text = string as NSString
        var newSelectionMatches: [NSRange] = []
        let newCaretMatches: [NSRange] = []

        if let word = descriptor.word, word.count > 1, !Self.allKeywords.contains(word.lowercased()) {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                regex.enumerateMatches(in: string, options: [], range: NSRange(location: 0, length: text.length)) { match, _, _ in
                    if let matchRange = match?.range, matchRange != descriptor.range {
                        newSelectionMatches.append(matchRange)
                    }
                }
            }
        }

        if newSelectionMatches != selectionMatchRanges || newCaretMatches != caretMatchRanges {
            selectionMatchRanges = newSelectionMatches
            caretMatchRanges = newCaretMatches
            reapplyHighlighting()
        }
    }
}

struct SelectionDescriptor {
    let range: NSRange
    let word: String?
}
#endif
