import AppKit
import SwiftUI

/// What is drawn behind and over the text: the caret's line, the statement, what ran, the
/// word's other uses, find matches, the selection, the caret and the gutter's Run arrow.
extension LabQEEditor {
    func backgroundMarks(_ layout: LabQELayout, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            currentLineBand(layout, width: width)
            ranHighlight(layout, width: width)
            statementBand(layout, width: width)
            wordHighlights(layout)
            findMatches(layout)
            selection(layout, width: width)
        }
    }

    func foregroundMarks(_ layout: LabQELayout, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            caret(layout)
            runArrow(layout)
            // The gutter tracks the pointer itself, so the arrow can appear and light up under it.
            Color.clear.frame(width: layout.gutterEdge, height: layout.y(line: lines.count + 1))
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        isHoveringGutter = true
                        isHoveringArrow = runArrowLine.map { arrowRect(layout, line: $0).contains(point) } ?? false
                    case .ended:
                        isHoveringGutter = false
                        isHoveringArrow = false
                    }
                }
        }
    }

    @ViewBuilder
    private func currentLineBand(_ layout: LabQELayout, width: CGFloat) -> some View {
        if scene.hasCaret, !scene.selection, !scene.empty {
            let y = layout.y(line: LabQESample.caret.line)
            let inset = LayoutTokens.EditorGutter.currentLineInset
            let radius = LayoutTokens.EditorGutter.currentLineCornerRadius
            switch style.currentLine {
            case .band:
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(palette.currentLine)
                    .frame(width: max(width - layout.gutterEdge - inset * 2, 0), height: layout.lineHeight)
                    .offset(x: layout.gutterEdge + inset, y: y)
            case .fullWidth:
                Rectangle().fill(palette.currentLine)
                    .frame(width: max(width - layout.gutterEdge, 0), height: layout.lineHeight)
                    .offset(x: layout.gutterEdge, y: y)
            case .outline:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(ColorTokens.Separator.primary, lineWidth: LayoutTokens.EditorGutter.edgeWidth)
                    .frame(width: max(width - layout.gutterEdge - inset * 2, 0), height: layout.lineHeight)
                    .offset(x: layout.gutterEdge + inset, y: y)
            case .noBand:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func statementBand(_ layout: LabQELayout, width: CGFloat) -> some View {
        if let statement = focusedStatement {
            let top = layout.y(line: statement.lowerBound)
            let height = CGFloat(statement.count) * layout.lineHeight
            switch style.statement {
            case .band:
                Rectangle().fill(ColorTokens.accent.opacity(LayoutTokens.EditorGutter.statementBandOpacity))
                    .frame(width: max(width - layout.gutterEdge, 0), height: height)
                    .offset(x: layout.gutterEdge, y: top)
            case .hoverBand:
                Rectangle().fill(ColorTokens.accent.opacity(LayoutTokens.EditorGutter.statementBandOpacity))
                    .frame(width: max(width - layout.gutterEdge, 0), height: height)
                    .offset(x: layout.gutterEdge, y: top)
                    .opacity(isHoveringArrow ? 1 : 0)
                    .animation(motion.hover, value: isHoveringArrow)
            case .bracket where !(scene.isRunning && style.runningMark != .nothing):
                Capsule().fill(ColorTokens.accent.opacity(0.7))
                    .frame(width: SpacingTokens.xxxs, height: max(height - SpacingTokens.xxs, 0))
                    .offset(x: layout.numbersRight + SpacingTokens.xxs, y: top + SpacingTokens.xxxs)
            case .bracket, .nothing:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func ranHighlight(_ layout: LabQELayout, width: CGFloat) -> some View {
        if scene.runNote != nil, let ran = LabQESample.statements.first {
            let rect = CGRect(x: layout.gutterEdge + SpacingTokens.xxxs, y: layout.y(line: ran.lowerBound),
                              width: max(width - layout.gutterEdge - SpacingTokens.xxs, 0), height: CGFloat(ran.count) * layout.lineHeight)
            let shape = RoundedRectangle(cornerRadius: LayoutTokens.EditorGutter.currentLineCornerRadius, style: .continuous)
            switch style.ranHighlight {
            case .nothing: EmptyView()
            case .flash: shape.fill(ColorTokens.accent.opacity(0.22 * flash)).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            case .outline: shape.strokeBorder(ColorTokens.accent.opacity(0.6), lineWidth: 1).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            case .tint: shape.fill(ColorTokens.accent.opacity(0.08)).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            case .gentleTint: shape.fill(ColorTokens.accent.opacity(0.08 * flash)).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            case .outlineFade:
                shape.strokeBorder(ColorTokens.accent.opacity(0.7 * flash), lineWidth: 1).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            case .sweep:
                LinearGradient(colors: [.clear, ColorTokens.accent.opacity(0.14), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: rect.width, height: layout.lineHeight * 3)
                    .offset(y: -layout.lineHeight * 3 + (rect.height + layout.lineHeight * 3) * sweep)
                    .frame(width: rect.width, height: rect.height, alignment: .top)
                    .clipped()
                    .offset(x: rect.minX, y: rect.minY)
            case .edgeGlow:
                LinearGradient(colors: [ColorTokens.accent.opacity(0.25 * flash), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: SpacingTokens.xl, height: rect.height).offset(x: rect.minX, y: rect.minY)
            case .gutterLine:
                Capsule().fill(ColorTokens.accent.opacity(flash))
                    .frame(width: LayoutTokens.EditorGutter.statementBracketWidth, height: max(rect.height - SpacingTokens.xxs, 0))
                    .offset(x: layout.numbersRight + LayoutTokens.EditorGutter.statementBracketGap, y: rect.minY + SpacingTokens.xxxs)
            case .bracketPulse:
                Capsule().fill(ColorTokens.accent.opacity(flash))
                    .frame(width: LayoutTokens.EditorGutter.statementBracketWidth + SpacingTokens.xxxs * flash, height: max(rect.height - SpacingTokens.xxs, 0))
                    .offset(x: layout.numbersRight + LayoutTokens.EditorGutter.statementBracketGap - SpacingTokens.micro * flash, y: rect.minY + SpacingTokens.xxxs)
            }
        }
    }

    @ViewBuilder
    private func wordHighlights(_ layout: LabQELayout) -> some View {
        if scene.wordHighlight, scene.hasCaret, !scene.selection, !scene.empty, !scene.find {
            let letters = style.markHeight == .letters
            ForEach(Array(LabQESample.caretWord.enumerated()), id: \.offset) { _, span in
                let rect = layout.rect(span, lettersOnly: letters)
                let shape = RoundedRectangle(cornerRadius: style.markCorner.points, style: .continuous)
                switch style.wordHighlight {
                case .today: shape.fill(palette.selection.opacity(0.3)).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                case .soft: shape.fill(ColorTokens.Text.primary.opacity(0.09)).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                case .underline:
                    Rectangle().fill(ColorTokens.accent.opacity(0.7)).frame(width: rect.width, height: 1.5)
                        .offset(x: rect.minX, y: layout.rect(span, lettersOnly: true).maxY - 1.5)
                case .off: EmptyView()
                }
            }
        }
    }

    /// Round 28.5 rev 2: every way of marking find matches; the first match is the current one.
    @ViewBuilder
    private func findMatches(_ layout: LabQELayout) -> some View {
        if scene.find {
            let yellow = Color(nsColor: .findHighlightColor)
            let corner = style.findLook == .native ? SpacingTokens.nano : style.markCorner.points
            ForEach(Array(LabQESample.findMatches.enumerated()), id: \.offset) { index, span in
                let rect = layout.rect(span, lettersOnly: true)
                let isCurrent = index == 0
                let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
                Group {
                    switch style.findLook {
                    case .native:
                        shape.fill(isCurrent ? yellow : ColorTokens.Workspace.card)
                            .shadow(color: .black.opacity(isCurrent ? 0.25 : 0), radius: 2, y: 1)
                    case .echo:
                        shape.fill(isCurrent ? yellow : ColorTokens.Text.primary.opacity(0.09))
                    case .yellow:
                        shape.fill(yellow.opacity(isCurrent ? 1 : 0.35))
                    case .accent:
                        shape.fill(ColorTokens.accent.opacity(isCurrent ? 0.3 : 0.12))
                            .overlay(shape.strokeBorder(ColorTokens.accent.opacity(isCurrent ? 0.8 : 0), lineWidth: 1))
                    case .underline:
                        if isCurrent {
                            shape.fill(yellow)
                        } else {
                            Rectangle().fill(yellow).frame(height: SpacingTokens.xxxs).frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
                .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
            }
        }
    }

    /// The system's incremental find dims everything but the matches while its field has the keyboard.
    @ViewBuilder
    func findDimming(_ layout: LabQELayout, size: CGSize) -> some View {
        if scene.find, style.findLook == .native {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.black.opacity(0.28))
                ForEach(Array(LabQESample.findMatches.enumerated()), id: \.offset) { _, span in
                    let rect = layout.rect(span, lettersOnly: true)
                    RoundedRectangle(cornerRadius: SpacingTokens.nano, style: .continuous)
                        .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                        .blendMode(.destinationOut)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .compositingGroup()
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func selection(_ layout: LabQELayout, width: CGFloat) -> some View {
        if scene.selection {
            let range = LabQESample.selection
            let corner: CGFloat = style.selectionShape == .rounded ? SpacingTokens.nano : 0
            ForEach(range.from.line...range.to.line, id: \.self) { line in
                let startX = line == range.from.line ? layout.x(column: range.from.column) : layout.codeX
                let endX = line == range.to.line ? layout.x(column: range.to.column) : width - SpacingTokens.xxs
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(selectionColour)
                    .frame(width: max(endX - startX, 0), height: layout.lineHeight)
                    .offset(x: startX, y: layout.y(line: line))
            }
        }
    }

    private var selectionColour: Color {
        switch style.selectionColour {
        case .palette: palette.selection
        case .system: Color(nsColor: isActive ? .selectedTextBackgroundColor : .unemphasizedSelectedTextBackgroundColor)
        case .accent: ColorTokens.accent.opacity(isActive ? 0.25 : 0.12)
        }
    }

    @ViewBuilder
    private func caret(_ layout: LabQELayout) -> some View {
        if scene.hasCaret, !scene.selection, isActive {
            let position = scene.empty ? LabQEPosition(line: 1, column: 0) : LabQESample.caret
            let rect = layout.rect(.init(line: position.line, start: position.column, end: position.column), lettersOnly: true)
            let colour: Color = switch style.caret {
            case .operatorColour: palette.operatorSymbol
            case .accent: ColorTokens.accent
            case .text: palette.plain
            }
            RoundedRectangle(cornerRadius: 1).fill(colour)
                .frame(width: SpacingTokens.xxxs, height: rect.height)
                .offset(x: rect.minX - 1, y: rect.minY)
        }
    }

    @ViewBuilder
    private func runArrow(_ layout: LabQELayout) -> some View {
        if let line = runArrowLine, showsRunArrow, !(hasError && line == LabQESample.error.line) {
            let size = LayoutTokens.EditorGutter.runArrowSize
            let accent = style.runArrow == .triangle || isHoveringArrow
            let rect = arrowRect(layout, line: line)
            LabQETriangle()
                .fill(accent ? ColorTokens.accent : ColorTokens.Text.tertiary)
                .frame(width: size * 0.85, height: size)
                .offset(x: rect.minX + SpacingTokens.xxxs, y: rect.minY + SpacingTokens.xxxs)
                .allowsHitTesting(false)
        }
    }

    /// The arrow with a little room round it, as Echo's click target.
    private func arrowRect(_ layout: LabQELayout, line: Int) -> CGRect {
        let size = LayoutTokens.EditorGutter.runArrowSize
        return CGRect(x: layout.markerX - SpacingTokens.xxxs, y: layout.y(line: line) + (layout.lineHeight - size) / 2 - SpacingTokens.xxxs,
                      width: size * 0.85 + SpacingTokens.xxs, height: size + SpacingTokens.xxs)
    }
}

/// The Run arrow, as LineNumberRulerView draws it.
struct LabQETriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
