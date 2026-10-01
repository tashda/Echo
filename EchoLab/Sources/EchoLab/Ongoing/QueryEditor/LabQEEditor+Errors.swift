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
            LabQEGlow(reduceMotion: motion.reduceMotion)
                .frame(width: letters.width + SpacingTokens.xs, height: letters.height + SpacingTokens.xxs)
                .offset(x: letters.minX - SpacingTokens.xxs, y: letters.minY - SpacingTokens.xxxs)
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
                LabQEErrorBubble(message: message, detail: scene.serverError ? "Msg 208, Level 16, State 1, Line 4" : "No table with that name in sales.")
                    .offset(x: word.minX - SpacingTokens.xs, y: word.maxY + SpacingTokens.xxs)
                    .transition(.opacity)
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

/// The server-error bubble (QueryErrorBubble in an NSPopover).
struct LabQEErrorBubble: View {
    let message: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label(message, systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(ColorTokens.Status.error)
            Text(detail).foregroundStyle(ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.detail)
        .fixedSize()
        .padding(SpacingTokens.xs)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
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
