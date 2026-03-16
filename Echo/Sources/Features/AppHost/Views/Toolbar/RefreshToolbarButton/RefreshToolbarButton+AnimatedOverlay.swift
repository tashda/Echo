import SwiftUI
import EchoSense

struct RefreshAnimatedOverlay: View {
    let phase: RefreshButtonContent.Phase
    let showCancel: Bool

    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkOpacity: Double = 0.0

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
        }
        .onChange(of: phase) { oldPhase, newPhase in
            if newPhase == .completed {
                // Animate checkmark in with a bounce
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    checkmarkScale = 1.0
                    checkmarkOpacity = 1.0
                }
            } else {
                // Reset checkmark instantly when leaving completed state
                checkmarkScale = 0.0
                checkmarkOpacity = 0.0
            }
        }
    }
}
