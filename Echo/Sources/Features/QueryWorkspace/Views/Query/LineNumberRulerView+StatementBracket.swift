#if os(macOS)
import AppKit

/// Round 28.4 (B1, SR1): the statement at the caret as a thin accent bracket beside its line
/// numbers, and a selected script result's statement as the same bracket, solid. Collected while
/// the gutter walks its visible lines, then drawn once.
extension LineNumberRulerView {
    struct StatementBrackets {
        let focused: ClosedRange<Int>?
        let result: ClosedRange<Int>?
        private var focusedSpan: ClosedRange<CGFloat>?
        private var resultSpan: ClosedRange<CGFloat>?

        init(focused: ClosedRange<Int>?, result: ClosedRange<Int>?) {
            self.focused = focused
            self.result = result
        }

        /// Adds a visible line fragment (in text view coordinates) if it belongs to a statement.
        mutating func include(line: Int, fragment: NSRect) {
            if focused?.contains(line) == true { focusedSpan = Self.union(focusedSpan, fragment) }
            if result?.contains(line) == true { resultSpan = Self.union(resultSpan, fragment) }
        }

        func draw(numbersRight: CGFloat, context: LabelContext) {
            let x = numbersRight + LayoutTokens.EditorGutter.statementBracketGap
            if let focusedSpan, focused != result {
                bar(focusedSpan, x: x, context: context, alpha: LayoutTokens.EditorGutter.statementBracketOpacity)
            }
            if let resultSpan { bar(resultSpan, x: x, context: context, alpha: 1) }
        }

        private func bar(_ span: ClosedRange<CGFloat>, x: CGFloat, context: LabelContext, alpha: CGFloat) {
            let inset = LayoutTokens.EditorGutter.statementBracketInset
            let width = LayoutTokens.EditorGutter.statementBracketWidth
            let top = span.lowerBound + context.containerOriginY - context.scrollOffsetY + inset
            let height = max(span.upperBound - span.lowerBound - inset * 2, width)
            NSColor.controlAccentColor.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: top, width: width, height: height), xRadius: width / 2, yRadius: width / 2).fill()
        }

        private static func union(_ span: ClosedRange<CGFloat>?, _ rect: NSRect) -> ClosedRange<CGFloat> {
            guard let span else { return rect.minY...rect.maxY }
            return min(span.lowerBound, rect.minY)...max(span.upperBound, rect.maxY)
        }
    }
}
#endif
