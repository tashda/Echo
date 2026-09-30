import SwiftUI

/// Sizes for round 24's glyphs, matched to play.fill and stop.fill at 13pt.
enum LabRMMetrics {
    static let glyphWidth: CGFloat = 11
    static let glyphHeight: CGFloat = 12
    /// Rounds the shape's corners as SF Symbols' filled glyphs are rounded.
    static let cornerStroke: CGFloat = 1.6
}

/// ▶ and ■ as one four-cornered shape. At 0 two corners sit together at the tip (a triangle);
/// at 1 they have slid apart into a square. Animatable, so the change is one continuous shape.
struct LabRMPlayStopShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let play: [CGPoint] = [.init(x: 0.10, y: 0.02), .init(x: 0.98, y: 0.5), .init(x: 0.98, y: 0.5), .init(x: 0.10, y: 0.98)]
    private static let stop: [CGPoint] = [.init(x: 0.08, y: 0.10), .init(x: 0.92, y: 0.10), .init(x: 0.92, y: 0.90), .init(x: 0.08, y: 0.90)]

    func path(in rect: CGRect) -> Path {
        let t = min(max(progress, 0), 1)
        let points = zip(Self.play, Self.stop).map { from, to in
            CGPoint(x: rect.minX + (from.x + (to.x - from.x) * t) * rect.width,
                    y: rect.minY + (from.y + (to.y - from.y) * t) * rect.height)
        }
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// The glyph in round 24's Run: ▶ at rest, ■ while running, drawn the way the Morph control says.
struct LabRMGlyph: View {
    let morph: LabRMMorph
    let isStop: Bool
    let colour: Color
    /// Overrides `isStop` for the slow-motion scrubber (shape morphs only).
    var scrub: Double?

    var body: some View {
        Group {
            switch morph {
            case .corners, .turn:
                let progress = scrub ?? (isStop ? 1 : 0)
                LabRMPlayStopShape(progress: progress)
                    .fill(colour)
                    .overlay {
                        LabRMPlayStopShape(progress: progress)
                            .stroke(colour, style: StrokeStyle(lineWidth: LabRMMetrics.cornerStroke, lineJoin: .round))
                    }
                    .frame(width: LabRMMetrics.glyphWidth, height: LabRMMetrics.glyphHeight)
                    .rotationEffect(.degrees(morph == .turn ? progress * 90 : 0))
            case .swap, .replace, .magic:
                Image(systemName: isStop ? "stop.fill" : "play.fill")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(colour)
                    .contentTransition(morph == .magic
                                       ? .symbolEffect(.replace.magic(fallback: .replace))
                                       : .symbolEffect(.replace))
            case .draw:
                ZStack {
                    Image(systemName: isStop ? "stop.fill" : "play.fill")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(colour)
                        .id(isStop)
                        .transition(AsymmetricTransition(insertion: SymbolEffectTransition.symbolEffect(.drawOn), removal: SymbolEffectTransition.symbolEffect(.drawOff)))
                }
            case .squeeze:
                ZStack {
                    Image(systemName: isStop ? "stop.fill" : "play.fill")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(colour)
                        .id(isStop)
                        .transition(.scale(scale: 0.05).combined(with: .opacity))
                }
            }
        }
        .frame(width: RunSpecimenGlyph.size, height: RunSpecimenGlyph.size)
    }
}
