import SwiftUI

/// Errors on the line: Echo today shows a mistake found while typing (live validation) as a
/// glowing frame and a pill at the line's end (ValidationAccessoryView, ValidationInlineAnnotation),
/// and the server's error after a run as a squiggle with a bubble on hover (QueryErrorMarkView).
extension LabQEEditor {
    @ViewBuilder
    func errorMarks(_ layout: LabQELayout, width: CGFloat) -> some View {
        if hasError {
            let span = LabQESample.error
            ZStack(alignment: .topLeading) {
                errorDot(layout)
                errorWord(layout, span: span)
                errorMessage(layout, span: span, width: width)
                // Pointing at the word shows the bubble (round 21 EM5).
                let hit = layout.rect(span)
                Color.clear.frame(width: hit.width, height: hit.height).contentShape(Rectangle())
                    .onHover { isHoveringError = $0 }
                    .offset(x: hit.minX, y: hit.minY)
            }
        }
    }

    /// Echo today: the glow while typing, the squiggle after a run. A proposal uses its look for both.
    private var wordLook: LabQEErrorWord {
        scene.serverError && style.errorWord == .glow ? .squiggle : style.errorWord
    }

    private var messageLook: LabQEErrorMessage {
        scene.serverError && style.errorMessage == .pill ? .hover : style.errorMessage
    }

    private var message: String { scene.serverError ? LabQESample.serverErrorMessage : LabQESample.errorMessage }

    @ViewBuilder
    private func errorDot(_ layout: LabQELayout) -> some View {
        if style.errorDot == .dot, style.markers != .onNumber {
            let size = LayoutTokens.EditorGutter.markerSize
            Circle().fill(ColorTokens.Status.error).frame(width: size, height: size)
                .offset(x: layout.markerX, y: layout.y(line: LabQESample.error.line) + (layout.lineHeight - size) / 2)
        }
    }

    @ViewBuilder
    private func errorWord(_ layout: LabQELayout, span: LabQESpan) -> some View {
        let letters = layout.rect(span, lettersOnly: true)
        switch wordLook {
        case .glow:
            if style.errorGlow == .today {
                LabQEGlow(reduceMotion: motion.reduceMotion)
                    .frame(width: letters.width + SpacingTokens.xs, height: letters.height + SpacingTokens.xxs)
                    .offset(x: letters.minX - SpacingTokens.xxs, y: letters.minY - SpacingTokens.xxxs)
            } else {
                // Rev 2: the still glows sit just outside the letters, with the marks' corner.
                LabQEStillGlow(glow: style.errorGlow, corner: style.markCorner.points)
                    .frame(width: letters.width + SpacingTokens.xxs, height: letters.height + SpacingTokens.xxxs)
                    .offset(x: letters.minX - SpacingTokens.xxxs, y: letters.minY - SpacingTokens.micro)
            }
        case .squiggle:
            LabQESquiggle().stroke(ColorTokens.Status.error, lineWidth: 1)
                .frame(width: letters.width, height: SpacingTokens.nano)
                .offset(x: letters.minX, y: letters.maxY - SpacingTokens.xxxs)
        case .fill:
            RoundedRectangle(cornerRadius: max(style.markCorner.points, SpacingTokens.xxxs), style: .continuous)
                .fill(ColorTokens.Status.error.opacity(0.15))
                .frame(width: letters.width, height: letters.height)
                .offset(x: letters.minX, y: letters.minY)
        case .dotted:
            Line().stroke(ColorTokens.Status.error, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0, 4]))
                .frame(width: letters.width, height: 2)
                .offset(x: letters.minX, y: letters.maxY - 1)
        case .redLetters:
            EmptyView()
        default:
            LabQEErrorWordMark(look: wordLook, corner: style.markCorner.points, letters: letters)
        }
    }

    @ViewBuilder
    private func errorMessage(_ layout: LabQELayout, span: LabQESpan, width: CGFloat) -> some View {
        let lineEnd = layout.x(column: lines[span.line - 1].count)
        let y = layout.y(line: span.line)
        switch messageLook {
        case .pill:
            Label(message, systemImage: "tablecells")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Status.error)
                .padding(.horizontal, SpacingTokens.xxs2)
                .padding(.vertical, SpacingTokens.xxxs)
                .background(ColorTokens.Status.error.opacity(0.12), in: RoundedRectangle(cornerRadius: SpacingTokens.xxs))
                .fixedSize()
                .frame(height: layout.lineHeight)
                .offset(x: lineEnd + SpacingTokens.sm, y: y)
        case .text:
            Text(message).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                .fixedSize()
                .frame(height: layout.lineHeight)
                .offset(x: lineEnd + SpacingTokens.md, y: y)
        case .banner:
            Text(message).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error)
                .lineLimit(1)
                .padding(.horizontal, SpacingTokens.xxs2)
                .frame(width: max(width - lineEnd - SpacingTokens.sm - SpacingTokens.xs, 0), height: max(layout.lineHeight - SpacingTokens.xxs, 0), alignment: .leading)
                .background(ColorTokens.Status.error.opacity(0.1), in: RoundedRectangle(cornerRadius: SpacingTokens.xxs))
                .offset(x: lineEnd + SpacingTokens.sm, y: y + SpacingTokens.xxxs)
        case .hover:
            if isHoveringError || scene.caretOnError {
                let word = layout.rect(span)
                let bubble = LabQEErrorBubbleView(look: style.errorBubble, title: scene.serverError ? "Invalid object name" : "Unknown table",
                                                  message: message,
                                                  detail: scene.serverError ? "Msg 208, Level 16, State 1, Line 4" : "No table with that name in sales.")
                switch style.errorBubble {
                case .inline:
                    bubble.offset(x: layout.codeX, y: word.maxY + SpacingTokens.micro)
                case .margin:
                    bubble.frame(width: max(width - SpacingTokens.sm, 0), alignment: .trailing)
                        .frame(height: layout.lineHeight)
                        .offset(y: word.minY)
                default:
                    bubble.offset(x: word.minX - SpacingTokens.xs, y: word.maxY + SpacingTokens.xs)
                        .transition(.opacity)
                }
            }
        }
    }
}

/// Today's validation glow: three red gradient strokes, blurred, slowly shifting (GlowFrameView).
struct LabQEGlow: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let angle = Angle.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) * 90)
            let gradient = AngularGradient(colors: [ColorTokens.Status.error, ColorTokens.Status.warning, ColorTokens.Status.error.opacity(0.7), ColorTokens.Status.error], center: .center, angle: angle)
            let shape = RoundedRectangle(cornerRadius: SpacingTokens.xxs2, style: .continuous)
            ZStack {
                shape.stroke(gradient, lineWidth: 1).opacity(0.75)
                shape.stroke(gradient, lineWidth: 1.6).blur(radius: 6).opacity(0.4)
                shape.stroke(gradient, lineWidth: 2.3).blur(radius: 13).opacity(0.22)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The squiggle QueryErrorMarkView draws: 1.5pt high, a 4pt period.
struct LabQESquiggle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            var x = rect.minX
            var up = true
            path.move(to: CGPoint(x: x, y: rect.midY))
            while x < rect.maxX {
                x = min(x + 2, rect.maxX)
                path.addLine(to: CGPoint(x: x, y: up ? rect.minY : rect.maxY))
                up.toggle()
            }
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// Round 28.6 rev 3: the marks without a glow, drawn round the letters' rectangle.
struct LabQEErrorWordMark: View {
    let look: LabQEErrorWord
    let corner: CGFloat
    let letters: CGRect

    private var red: Color { ColorTokens.Status.error }

    var body: some View {
        Group {
            switch look {
            case .boldSquiggle:
                LabQESquiggle().stroke(red, lineWidth: 1.5)
                    .frame(width: letters.width, height: SpacingTokens.xxs)
                    .offset(x: letters.minX, y: letters.maxY - SpacingTokens.xxxs)
            case .doubleUnderline:
                VStack(spacing: SpacingTokens.xxxs) {
                    Rectangle().fill(red).frame(height: 1)
                    Rectangle().fill(red).frame(height: 1)
                }
                .frame(width: letters.width)
                .offset(x: letters.minX, y: letters.maxY - SpacingTokens.xxxs)
            case .redLettersSquiggle:
                LabQESquiggle().stroke(red, lineWidth: 1)
                    .frame(width: letters.width, height: SpacingTokens.nano)
                    .offset(x: letters.minX, y: letters.maxY - SpacingTokens.xxxs)
            case .cornerTicks:
                LabQECornerTicks().stroke(red, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: letters.width + SpacingTokens.xxs, height: letters.height + SpacingTokens.xxxs)
                    .offset(x: letters.minX - SpacingTokens.xxxs, y: letters.minY - SpacingTokens.micro)
            case .underBar:
                Capsule().fill(red)
                    .frame(width: letters.width, height: SpacingTokens.xxxs)
                    .offset(x: letters.minX, y: letters.maxY - SpacingTokens.micro)
            case .pill:
                Capsule().fill(red.opacity(0.14))
                    .frame(width: letters.width + SpacingTokens.xs, height: letters.height)
                    .offset(x: letters.minX - SpacingTokens.xxs, y: letters.minY)
            case .dashedOutline:
                RoundedRectangle(cornerRadius: max(corner, SpacingTokens.xxxs), style: .continuous)
                    .stroke(red, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: letters.width + SpacingTokens.xxs, height: letters.height + SpacingTokens.xxxs)
                    .offset(x: letters.minX - SpacingTokens.xxxs, y: letters.minY - SpacingTokens.micro)
            case .marker:
                Capsule().fill(red.opacity(0.28))
                    .frame(width: letters.width + SpacingTokens.xxs, height: letters.height * 0.45)
                    .offset(x: letters.minX - SpacingTokens.xxxs, y: letters.maxY - letters.height * 0.45)
            default:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}

/// Four short corner strokes, like a focus frame.
struct LabQECornerTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.3
        return Path { path in
            for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                     (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
                path.move(to: CGPoint(x: corner.x + dx * length, y: corner.y))
                path.addLine(to: corner)
                path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            }
        }
    }
}
