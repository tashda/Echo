import SwiftUI

/// Smoothly animates a counter from one value to another using SwiftUI animation
/// without tying increments to backend delivery cadence.
struct AnimatedCounter: View {
    let targetValue: Int
    let isActive: Bool
    let formatter: (Int) -> String

    @State private var displayedValue: Double = 0
    @State private var previousTarget: Int = 0

    private func animationDuration(for delta: Int) -> Double {
        let perThousand: Double = 0.06
        let clamped = min(0.8, max(0.12, (Double(max(delta, 0)) / 1000.0) * perThousand))
        return clamped
    }

    var body: some View {
        Text(formatter(Int(displayedValue.rounded())))
            .font(TypographyTokens.detail)
            .lineLimit(1)
            .onChange(of: targetValue) { _, new in
                guard isActive else {
                    displayedValue = Double(new)
                    previousTarget = new
                    return
                }
                let delta = abs(new - previousTarget)
                previousTarget = new
                withAnimation(.linear(duration: animationDuration(for: delta))) {
                    displayedValue = Double(new)
                }
            }
            .onAppear {
                displayedValue = Double(targetValue)
                previousTarget = targetValue
            }
    }
}
