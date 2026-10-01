import SwiftUI

/// Round 28.7 rev 3: the statement's bracket while its query runs. Every look loops until the
/// result comes; with Reduce Motion it is drawn still, solid.
extension LabQEEditor {
    @ViewBuilder
    func runningMark(_ layout: LabQELayout) -> some View {
        if scene.isRunning, style.runningMark != .nothing, let ran = LabQESample.statements.first {
            let inset = LayoutTokens.EditorGutter.statementBracketInset
            let width = LayoutTokens.EditorGutter.statementBracketWidth
            let height = max(CGFloat(ran.count) * layout.lineHeight - inset * 2, width)
            TimelineView(.animation(minimumInterval: 1 / 60, paused: motion.reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate / motion.durationScale
                LabQERunningBracket(mark: style.runningMark, phase: motion.reduceMotion ? 0.5 : t, height: height, width: width)
            }
            .frame(width: width + SpacingTokens.xs, height: height)
            .offset(x: layout.numbersRight + LayoutTokens.EditorGutter.statementBracketGap - SpacingTokens.xxs,
                    y: layout.y(line: ran.lowerBound) + inset)
            .allowsHitTesting(false)
        }
    }
}

/// One frame of a running bracket; `phase` is time in seconds.
struct LabQERunningBracket: View {
    let mark: LabQERunningMark
    let phase: Double
    let height: CGFloat
    let width: CGFloat

    private var accent: Color { ColorTokens.accent }
    private func cycle(_ seconds: Double) -> Double { phase.truncatingRemainder(dividingBy: seconds) / seconds }

    var body: some View {
        ZStack(alignment: .top) {
            switch mark {
            case .nothing:
                EmptyView()
            case .breathe:
                Capsule().fill(accent.opacity(0.45 + 0.55 * (0.5 + 0.5 * sin(phase * 2 * .pi / 1.5))))
                    .frame(width: width)
            case .travel:
                Capsule().fill(accent.opacity(0.3)).frame(width: width)
                Capsule().fill(accent).frame(width: width, height: SpacingTokens.md)
                    .shadow(color: accent.opacity(0.8), radius: 3)
                    .offset(y: (height - SpacingTokens.md) * cycle(1.2))
            case .shimmer:
                Capsule().fill(accent.opacity(0.4)).frame(width: width)
                LinearGradient(colors: [.clear, Color.white.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: width, height: SpacingTokens.xl)
                    .offset(y: -SpacingTokens.xl + (height + SpacingTokens.xl) * cycle(1.4))
                    .frame(width: width, height: height, alignment: .top)
                    .clipShape(Capsule())
                    .blendMode(.plusLighter)
            case .glow:
                Capsule().fill(accent).frame(width: width)
                    .shadow(color: accent.opacity(0.9), radius: 4)
                    .shadow(color: accent.opacity(0.5), radius: 8)
            case .march:
                Rectangle().fill(.clear).frame(width: width, height: height)
                    .overlay {
                        Path { path in
                            path.move(to: CGPoint(x: width / 2, y: 0))
                            path.addLine(to: CGPoint(x: width / 2, y: height))
                        }
                        .stroke(accent, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [4, 4], dashPhase: -8 * cycle(0.5)))
                    }
            case .grow:
                Capsule().fill(accent.opacity(0.2)).frame(width: width)
                Capsule().fill(accent).frame(width: width, height: max(height * cycle(1.1), width))
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .frame(maxWidth: .infinity)
    }
}
