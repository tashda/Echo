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
            let lane = laneRect(layout, height: height)
            let radius: CGFloat = switch style.laneCorner {
            case .eight: LayoutTokens.EditorGutter.laneCornerRadius
            case .concentric: max(cornerRadius - LayoutTokens.EditorGutter.laneInset, SpacingTokens.xxs)
            case .capsule: lane.width / 2
            }
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            Group {
                switch style.laneFill {
                case .palette: shape.fill(palette.gutterBackground)
                case .system: shape.fill(ColorTokens.Workspace.groupFill)
                case .outline: shape.strokeBorder(ColorTokens.Separator.primary, lineWidth: edge)
                }
            }
            .frame(width: lane.width, height: lane.height)
            .offset(x: lane.minX, y: lane.minY)
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

    /// Round 28.14: the lane's rectangle. Echo today draws it inside the scroll view, which stops
    /// 20pt above the card's bottom (QueryInputSection's padding).
    func laneRect(_ layout: LabQELayout, height: CGFloat) -> CGRect {
        let inset = LayoutTokens.EditorGutter.laneInset
        let bottom = style.laneHeight == .short ? inset + SpacingTokens.md2 : inset
        let side = SpacingTokens.xxs2
        let minX = style.laneHolds == .everything ? inset : layout.numbersLeft - side
        let maxX = style.laneHolds == .everything ? layout.gutterEdge - inset : layout.numbersRight + side
        return CGRect(x: minX, y: inset, width: max(maxX - minX, 0), height: max(height - inset - bottom, 0))
    }

    private func row(line: Int, text: String, _ layout: LabQELayout) -> some View {
        let isCurrent = scene.hasCaret && !scene.selection && line == LabQESample.caret.line
            || scene.selection && (LabQESample.selection.from.line...LabQESample.selection.to.line).contains(line)
        // Round 28.14 (LA1): the numbers centred in the lane.
        let centredLane = style.gutter == .lane && style.laneAlign == .centre ? laneRect(layout, height: 0) : nil
        return HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.none) {
            Text(verbatim: "\(line)")
                .font(Font(numberFont(isCurrent: isCurrent, layout)))
                .foregroundStyle(numberColour(line: line, isCurrent: isCurrent))
                .opacity(hidesNumber(line: line) ? 0 : 1)
                .frame(width: centredLane?.width ?? layout.numbersRight - layout.numbersLeft, alignment: centredLane == nil ? .trailing : .center)
                .padding(.leading, centredLane?.minX ?? layout.numbersLeft)
            Color.clear.frame(width: layout.codeX - (centredLane?.maxX ?? layout.numbersRight), height: 1)
            Text(attributed(text, line: line))
                .font(Font(layout.codeFont))
                .fixedSize()
        }
        .frame(height: layout.lineHeight, alignment: .leading)
    }

    private func attributed(_ text: String, line: Int) -> AttributedString {
        // 28.6 rev 3: E6 and E7 turn the wrong word's letters red.
        let redWord = hasError && line == LabQESample.error.line && [.redLetters, .redLettersSquiggle].contains(style.errorWord)
        var result = AttributedString()
        var column = 0
        for token in LabQESample.tokens(text) {
            var part = AttributedString(token.text)
            let isError = redWord && column >= LabQESample.error.start && column < LabQESample.error.end
            part.foregroundColor = isError ? ColorTokens.Status.error : palette.color(for: token.kind)
            result += part
            column += token.text.count
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
