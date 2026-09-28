import SwiftUI

/// Hairline ring around a rail item that shows connection health and activity.
///
/// - Connected and idle: nothing. Healthy is the normal case and costs no attention.
/// - Connecting: a ring that draws itself around the server, then clears, and repeats.
/// - Running a query: a short comet with a fading tail orbits the server.
/// - Connection lost: a still, dashed red ring (the item also shows a red badge).
///
/// Motion comes from a `TimelineView` clock rather than repeating animations, which restart or
/// stutter when the view re-renders. Only items that are connecting or busy tick; with Reduce
/// Motion on, the ring is drawn in a still, representative pose.
struct ServerRailStatusRing: View {
    let status: ServerRailStatus
    let isBusy: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let connectingPeriod: TimeInterval = 1.4
    private static let cometPeriod: TimeInterval = 1.1

    var body: some View {
        ZStack {
            switch status {
            case .connecting:
                animated { time in connectingTrace(at: time) }
            case .failed:
                Circle()
                    .inset(by: lineWidth / 2)
                    .stroke(ColorTokens.Status.error, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .transition(.opacity)
            case .ready:
                if isBusy {
                    animated { time in comet(at: time) }
                        .transition(.opacity)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.25), value: status)
        .animation(.easeInOut(duration: 0.25), value: isBusy)
    }

    private var diameter: CGFloat {
        LayoutTokens.ServerRail.itemSize + LayoutTokens.ServerRail.ringOutset * 2
    }

    private var lineWidth: CGFloat { 1.75 }

    @ViewBuilder
    private func animated<Content: View>(@ViewBuilder _ content: @escaping (TimeInterval) -> Content) -> some View {
        if reduceMotion {
            content(0.45)
        } else {
            TimelineView(.animation) { context in
                content(context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    /// Draws around the circle, then retracts from the start, so it reads as "reaching" the server.
    private func connectingTrace(at time: TimeInterval) -> some View {
        let phase = time.truncatingRemainder(dividingBy: Self.connectingPeriod) / Self.connectingPeriod
        let drawEnd = 0.6
        let from = phase < drawEnd ? 0 : (phase - drawEnd) / (1 - drawEnd)
        let to = phase < drawEnd ? phase / drawEnd : 1

        return Circle()
            .inset(by: lineWidth / 2)
            .trim(from: easeInOut(from), to: easeInOut(to))
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    /// A short arc with a fading tail, orbiting once per period.
    private func comet(at time: TimeInterval) -> some View {
        let phase = time.truncatingRemainder(dividingBy: Self.cometPeriod) / Self.cometPeriod
        let length = 0.28

        return Circle()
            .inset(by: lineWidth / 2)
            .trim(from: 0, to: length)
            .stroke(
                AngularGradient(
                    colors: [Color.accentColor.opacity(0), Color.accentColor],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360 * length)
                ),
                style: StrokeStyle(lineWidth: lineWidth + 0.25, lineCap: .round)
            )
            .rotationEffect(.degrees(phase * 360 - 90))
    }

    private func easeInOut(_ value: Double) -> Double {
        if value < 0.5 { return 2 * value * value }
        let remaining = -2 * value + 2
        return 1 - remaining * remaining / 2
    }
}
