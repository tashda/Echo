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

    /// A script longer than this is coloured around what is on screen, not all of it: seven
    /// expressions over every character after each pause in typing made a script of a few
    /// hundred lines lag, and ones of thousands of lines freeze for seconds.
    static let fullHighlightLimit = 6_000
    /// How far past the visible text the colouring reaches, so a short scroll shows coloured text.
    static let highlightMargin = 1_500

    func applySyntaxHighlighting() {
        guard let textStorage = layoutManager?.textStorage else { return }
        let length = textStorage.length
        guard length > 0 else { return }
        let range = highlightRange(in: textStorage, length: length)
        highlightedRange = range

        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: theme.tokenColors.plain.nsColor, range: range)

        // Highlight logic (regex application)
        applyRegex(Self.singleLineCommentRegex, color: theme.tokenColors.comment.nsColor, in: textStorage, range: range)
        applyRegex(Self.blockCommentRegex, color: theme.tokenColors.comment.nsColor, in: textStorage, range: range)
        applyRegex(Self.singleQuotedStringRegex, color: theme.tokenColors.string.nsColor, in: textStorage, range: range)
        applyRegex(Self.numberRegex, color: theme.tokenColors.number.nsColor, in: textStorage, range: range)
        applyRegex(Self.keywordRegex, color: theme.tokenColors.keyword.nsColor, in: textStorage, range: range)
        applyRegex(Self.functionRegex, color: theme.tokenColors.function.nsColor, in: textStorage, range: range)
        applyRegex(Self.operatorRegex, color: theme.tokenColors.operatorSymbol.nsColor, in: textStorage, range: range)

        applySymbolMatches(in: textStorage, range: range)
        textStorage.endEditing()
    }

    /// The text to colour: all of a short script; for a long one the lines on screen and a margin
    /// around them, starting early enough to catch a block comment that began above.
    private func highlightRange(in textStorage: NSTextStorage, length: Int) -> NSRange {
        let full = NSRange(location: 0, length: length)
        guard length > Self.fullHighlightLimit,
              let layoutManager, let textContainer else { return full }
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard visibleGlyphs.location != NSNotFound else { return full }
        let visible = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let text = textStorage.mutableString
        let lower = max(visible.location - Self.highlightMargin, 0)
        let upper = min(NSMaxRange(visible) + Self.highlightMargin, length)
        var start = text.lineRange(for: NSRange(location: lower, length: 0)).location
        let end = NSMaxRange(text.lineRange(for: NSRange(location: upper, length: 0)))
        // A block comment that began above the window and has not ended before it.
        // Looked for in the 20 000 characters above only: a longer comment, still open, isn't tracked.
        if start > 0 {
            let reach = min(start, 20_000)
            let above = NSRange(location: start - reach, length: reach)
            let open = text.range(of: "/*", options: .backwards, range: above)
            if open.location != NSNotFound {
                let close = text.range(of: "*/", options: .backwards, range: above)
                if close.location == NSNotFound || close.location < open.location {
                    start = text.lineRange(for: NSRange(location: open.location, length: 0)).location
                }
            }
        }
        return NSRange(location: start, length: max(end - start, 0))
    }

    /// After a scroll: colours the text that came into view, once the scrolling pauses. Only a long
    /// script has any (see `fullHighlightLimit`).
    func highlightAfterScroll() {
        guard let textStorage = layoutManager?.textStorage, textStorage.length > Self.fullHighlightLimit,
              let layoutManager, let textContainer else { return }
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard visibleGlyphs.location != NSNotFound else { return }
        let visible = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        // Inside what is coloured, with half the margin to spare: nothing to do.
        let covered = NSRange(location: max(visible.location - Self.highlightMargin / 2, 0),
                              length: visible.length + Self.highlightMargin)
        if let highlightedRange, NSIntersectionRange(highlightedRange, covered) == covered { return }
        scheduleHighlighting(after: 0.06)
    }

    private func applyRegex(_ regex: NSRegularExpression, color: NSColor, in textStorage: NSTextStorage, range: NSRange) {
        regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                textStorage.addAttribute(.foregroundColor, value: color, range: matchRange)
            }
        }
    }

    private func applySymbolMatches(in textStorage: NSTextStorage, range: NSRange) {
        for matchRange in caretMatchRanges {
            if NSIntersectionRange(matchRange, range).length > 0 {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
                textStorage.addAttribute(.underlineColor, value: theme.tokenColors.keyword.nsColor.withAlphaComponent(0.5), range: matchRange)
            }
        }
    }

    /// Large scripts wait a moment so moving the caret stays cheap; others update at once, so a
    /// mark never outlives the selection it belonged to.
    private static let immediateHighlightLimit = 100_000

    func scheduleSymbolHighlights(for descriptor: SelectionDescriptor, immediate: Bool = false) {
        symbolHighlightWorkItem?.cancel()
        let immediate = immediate || (string as NSString).length < Self.immediateHighlightLimit
        if !immediate, !selectionMatchRanges.isEmpty {
            selectionMatchRanges = []
            setNeedsDisplay(visibleRect)
        }
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
            // Round 28.5: the word's other uses are drawn behind the text (SQLTextView+Background).
            setNeedsDisplay(visibleRect)
        }
    }
}

struct SelectionDescriptor {
    let range: NSRange
    let word: String?
}
#endif
