import SwiftUI

/// Smoothly animates a counter using TimelineView for per-frame rendering
/// at the display refresh rate (60-120Hz).
struct AnimatedCounter: View {
    let targetValue: Int
    let isActive: Bool
    let formatter: (Int) -> String

    @State private var animationStart: Date = .now
    @State private var startValue: Double = 0
    @State private var endValue: Double = 0
    @State private var duration: TimeInterval = 0.3

    private var isAnimating: Bool {
        isActive && abs(endValue - startValue) >= 1
    }

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let value = isAnimating ? Int(interpolatedValue(at: context.date)) : targetValue
            Text(formatter(value))
                .font(TypographyTokens.detail)
                .lineLimit(1)
        }
        .onChange(of: targetValue) { _, newTarget in
            let newEnd = Double(newTarget)
            guard isActive else {
                startValue = newEnd
                endValue = newEnd
                return
            }
            let now = Date.now
            let currentPos = interpolatedValue(at: now)

            // Snap instantly when target decreases (new query starting)
            if newEnd < currentPos {
                startValue = newEnd
                endValue = newEnd
                return
            }

            startValue = currentPos
            endValue = newEnd
            let delta = abs(newEnd - currentPos)
            duration = min(0.8, max(0.2, delta / 5000.0))
            animationStart = now
        }
        .onChange(of: isActive) { _, active in
            if !active {
                startValue = Double(targetValue)
                endValue = Double(targetValue)
            }
        }
        .onAppear {
            startValue = Double(targetValue)
            endValue = Double(targetValue)
        }
    }

    private func interpolatedValue(at date: Date) -> Double {
        guard duration > 0 else { return endValue }
        let elapsed = date.timeIntervalSince(animationStart)
        let progress = min(elapsed / duration, 1.0)
        return startValue + (endValue - startValue) * progress
    }
}
