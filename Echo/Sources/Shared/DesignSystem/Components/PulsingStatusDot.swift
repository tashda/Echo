import SwiftUI

struct PulsingStatusDot: View {
    let tint: Color
    let isPulsing: Bool
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            if isPulsing {
                Circle()
                    .fill(tint.opacity(0.35))
                    .frame(width: 10, height: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 0 : 0.8)
            }
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
        }
        .frame(width: 10, height: 10)
        .animation(
            isPulsing
                ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                : .default,
            value: isAnimating
        )
        .onChange(of: isPulsing, initial: true) { _, pulsing in
            isAnimating = pulsing
        }
    }
}
