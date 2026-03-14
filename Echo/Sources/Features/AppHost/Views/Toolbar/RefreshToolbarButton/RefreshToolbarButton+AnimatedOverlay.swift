import SwiftUI
import EchoSense

struct RefreshAnimatedOverlay: View {
    let phase: RefreshButtonContent.Phase
    let showCancel: Bool
    let spinning: Bool
    let circleSize: CGFloat
    let glowPadding: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    @State private var rotation: Double = 0
    @State private var completionScale: CGFloat = 0.6

    private var shouldSpin: Bool {
        phase == .refreshing && !showCancel && spinning
    }

    private var currentSymbol: String {
        if showCancel { return "xmark" }
        switch phase {
        case .idle: return "arrow.clockwise"
        case .refreshing: return "arrow.clockwise"
        case .completed: return "checkmark"
        }
    }

    private var iconColor: Color {
        if showCancel {
            return ColorTokens.Text.primary.opacity(0.65)
        }
        switch phase {
        case .idle:
            return ColorTokens.Text.secondary
        case .refreshing:
            return ColorTokens.accent
        case .completed:
            return ColorTokens.Status.success
        }
    }

    var body: some View {
        Image(systemName: currentSymbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(iconColor)
            .rotationEffect(.degrees(shouldSpin ? rotation : 0))
            .scaleEffect(phase == .completed ? completionScale : 1.0)
            .contentTransition(.symbolEffect(.replace))
            .onChange(of: shouldSpin) { _, newValue in
                if newValue {
                    startSpinning()
                }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .completed {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        completionScale = 1.0
                    }
                } else {
                    completionScale = 0.6
                }
            }
            .onAppear {
                if shouldSpin { startSpinning() }
            }
    }

    private func startSpinning() {
        rotation = 0
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}
