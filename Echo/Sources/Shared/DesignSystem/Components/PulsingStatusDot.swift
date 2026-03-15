import SwiftUI

struct PulsingStatusDot: View {
    let tint: Color
    let isPulsing: Bool
    @State private var opacity: Double = 1

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 6, height: 6)
            .opacity(opacity)
            .onChange(of: isPulsing, initial: true) { _, pulsing in
                if pulsing {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        opacity = 0.25
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        opacity = 1
                    }
                }
            }
    }
}
