import SwiftUI
import EchoSense

struct RefreshAnimatedOverlay: View {
    let phase: RefreshButtonContent.Phase
    let showCancel: Bool

    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkOpacity: Double = 0.0
    @State private var failureScale: CGFloat = 0.0
    @State private var failureOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Spinner — visible only during refresh (no cancel hover)
            ProgressView()
                .controlSize(.small)
                .opacity(phase == .refreshing && !showCancel ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: phase)
                .animation(.easeInOut(duration: 0.15), value: showCancel)

            // Cancel icon — visible on hover during refresh
            Image(systemName: "xmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary.opacity(0.65))
                .opacity(showCancel ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: showCancel)

            // Checkmark — appears with scale bounce on completion
            Image(systemName: "checkmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.success)
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkOpacity)

            // Failure xmark — appears with scale bounce on failure
            Image(systemName: "xmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.error)
                .scaleEffect(failureScale)
                .opacity(failureOpacity)
        }
        .onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .completed:
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    checkmarkScale = 1.0
                    checkmarkOpacity = 1.0
                }
                failureScale = 0.0
                failureOpacity = 0.0
            case .failed:
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    failureScale = 1.0
                    failureOpacity = 1.0
                }
                checkmarkScale = 0.0
                checkmarkOpacity = 0.0
            default:
                checkmarkScale = 0.0
                checkmarkOpacity = 0.0
                failureScale = 0.0
                failureOpacity = 0.0
            }
        }
    }
}
