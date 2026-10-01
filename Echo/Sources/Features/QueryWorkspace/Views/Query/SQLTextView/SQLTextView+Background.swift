#if os(macOS)
import AppKit

/// What the editor draws behind its text, in the marks' language (round 28.15): the other uses of
/// the word at the caret (round 28.5) and the empty prompt.
extension SQLTextView {
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawWordHighlights(in: rect)
        drawFindMarks(in: rect)
        drawEmptyPrompt()
    }

    /// Round 28.5 and 28.15: the word's other uses, soft and grey (“the same word”).
    private func drawWordHighlights(in rect: NSRect) {
        for range in selectionMatchRanges { fillMarks(for: range, .same, .soft, in: rect) }
    }
}
#endif
