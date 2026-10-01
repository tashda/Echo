import AppKit
import SwiftUI

/// The gutter's surface, the numbers and the code (LineNumberRulerView and SQLTextView).
extension LabQEEditor {
    @ViewBuilder
    func gutterSurface(_ layout: LabQELayout, height: CGFloat) -> some View {
        let edge = LayoutTokens.EditorGutter.edgeWidth
        switch style.gutter {
        case .subtle:
            EmptyView()
        case .column:
            Rectangle().fill(palette.gutterBackground)
                .frame(width: layout.gutterEdge, height: height)
                .overlay(alignment: .trailing) { Rectangle().fill(ColorTokens.Separator.primary).frame(width: edge) }
        case .lane:
            let inset = LayoutTokens.EditorGutter.laneInset
            RoundedRectangle(cornerRadius: LayoutTokens.EditorGutter.laneCornerRadius, style: .continuous)
                .fill(palette.gutterBackground)
                .frame(width: max(layout.gutterEdge - inset * 2, 0), height: max(height - inset * 2, 0))
                .offset(x: inset, y: inset)
        case .hairline:
            Rectangle().fill(ColorTokens.Separator.primary).frame(width: edge, height: height).offset(x: layout.gutterEdge)
        }
    }

    func textLines(_ layout: LabQELayout) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, text in
                row(line: index + 1, text: text, layout)
            }
        }
        .offset(y: layout.top)
    }

    private func row(line: Int, text: String, _ layout: LabQELayout) -> some View {
        let isCurrent = scene.hasCaret && !scene.selection && line == LabQESample.caret.line
            || scene.selection && (LabQESample.selection.from.line...LabQESample.selection.to.line).contains(line)
        return HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.none) {
            Text(verbatim: "\(line)")
                .font(Font(numberFont(isCurrent: isCurrent, layout)))
                .foregroundStyle(numberColour(line: line, isCurrent: isCurrent))
                .opacity(hidesNumber(line: line) ? 0 : 1)
                .frame(width: layout.numbersRight - layout.numbersLeft, alignment: .trailing)
                .padding(.leading, layout.numbersLeft)
            Color.clear.frame(width: layout.codeX - layout.numbersRight, height: 1)
            Text(attributed(text))
                .font(Font(layout.codeFont))
                .fixedSize()
        }
        .frame(height: layout.lineHeight, alignment: .leading)
    }

    private func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        for token in LabQESample.tokens(text) {
            var part = AttributedString(token.text)
            part.foregroundColor = palette.color(for: token.kind)
            result += part
        }
        return result
    }

    private func numberFont(isCurrent: Bool, _ layout: LabQELayout) -> NSFont {
        guard isCurrent, style.currentNumber == .today else { return layout.numberFont }
        return .monospacedDigitSystemFont(ofSize: layout.numberFont.pointSize, weight: .semibold)
    }

    private func numberColour(line: Int, isCurrent: Bool) -> Color {
        if hasError, line == LabQESample.error.line, style.errorDot == .number || style.markers == .onNumber && style.errorDot != .nothing {
            return ColorTokens.Status.error
        }
        if isCurrent {
            switch style.currentNumber {
            case .today: return palette.gutterAccent
            case .primary: return ColorTokens.Text.primary
            case .accent: return ColorTokens.accent
            case .same: break
            }
        }
        return switch style.numberColour {
        case .palette: palette.gutterText
        case .tertiary: ColorTokens.Text.tertiary
        case .secondary: ColorTokens.Text.secondary
        }
    }

    /// With markers on the number, the Run arrow takes the number's place.
    private func hidesNumber(line: Int) -> Bool {
        style.markers == .onNumber && line == runArrowLine && showsRunArrow
    }

    var hasError: Bool { scene.liveError || scene.serverError }

    /// The first line of the statement at the caret (QE1).
    var runArrowLine: Int? {
        guard scene.hasCaret, !scene.empty, let statement = focusedStatement else { return nil }
        return statement.lowerBound
    }

    var focusedStatement: ClosedRange<Int>? {
        guard !scene.empty else { return nil }
        let line = scene.selection ? LabQESample.selection.from.line : LabQESample.caret.line
        return LabQESample.statements.first { $0.contains(line) }
    }

    var showsRunArrow: Bool {
        switch style.runArrow {
        case .triangle, .symbol: true
        case .hover: isHoveringGutter
        case .hidden: false
        }
    }
}
