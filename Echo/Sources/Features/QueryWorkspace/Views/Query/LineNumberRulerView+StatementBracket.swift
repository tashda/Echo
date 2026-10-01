#if os(macOS)
import AppKit

/// Round 28.4 (B1, SR1): the statement at the caret as a thin accent bracket beside its line
/// numbers, and a selected script result's statement as the same bracket, solid. Round 28.7: the
/// running statement's bracket (RR1) and what ran (H9) are layers placed on the same spot.
/// Collected while the gutter walks its visible lines, then drawn once.
extension LineNumberRulerView {
    struct StatementBrackets {
        let focused: ClosedRange<Int>?
        let result: ClosedRange<Int>?
        let running: ClosedRange<Int>?
        let ran: ClosedRange<Int>?
        private(set) var focusedSpan: ClosedRange<CGFloat>?
        private(set) var resultSpan: ClosedRange<CGFloat>?
        private(set) var runningSpan: ClosedRange<CGFloat>?
        private(set) var ranSpan: ClosedRange<CGFloat>?

        init(focused: ClosedRange<Int>?, result: ClosedRange<Int>?, running: ClosedRange<Int>? = nil, ran: ClosedRange<Int>? = nil) {
            self.focused = focused
            self.result = result
            self.running = running
            self.ran = ran
        }

        /// Adds a visible line fragment (in text view coordinates) if it belongs to a statement.
        mutating func include(line: Int, fragment: NSRect) {
            if focused?.contains(line) == true { focusedSpan = Self.union(focusedSpan, fragment) }
            if result?.contains(line) == true { resultSpan = Self.union(resultSpan, fragment) }
            if running?.contains(line) == true { runningSpan = Self.union(runningSpan, fragment) }
            if ran?.contains(line) == true { ranSpan = Self.union(ranSpan, fragment) }
        }

        func draw(numbersRight: CGFloat, context: LabelContext) {
            if let focusedSpan, focused != result, running == nil {
                fill(Self.frame(focusedSpan, numbersRight: numbersRight, context: context), alpha: LayoutTokens.EditorGutter.statementBracketOpacity)
            }
            if let resultSpan { fill(Self.frame(resultSpan, numbersRight: numbersRight, context: context), alpha: 1) }
        }

        /// The bracket's rectangle for a span of lines, in the gutter's coordinates.
        static func frame(_ span: ClosedRange<CGFloat>, numbersRight: CGFloat, context: LabelContext) -> NSRect {
            let inset = LayoutTokens.EditorGutter.statementBracketInset
            let width = LayoutTokens.EditorGutter.statementBracketWidth
            let top = span.lowerBound + context.containerOriginY - context.scrollOffsetY + inset
            let height = max(span.upperBound - span.lowerBound - inset * 2, width)
            return NSRect(x: numbersRight + LayoutTokens.EditorGutter.statementBracketGap, y: top, width: width, height: height)
        }

        private func fill(_ rect: NSRect, alpha: CGFloat) {
            NSColor.controlAccentColor.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.width / 2).fill()
        }

        private static func union(_ span: ClosedRange<CGFloat>?, _ rect: NSRect) -> ClosedRange<CGFloat> {
            guard let span else { return rect.minY...rect.maxY }
            return min(span.lowerBound, rect.minY)...max(span.upperBound, rect.maxY)
        }
    }
}
#endif
