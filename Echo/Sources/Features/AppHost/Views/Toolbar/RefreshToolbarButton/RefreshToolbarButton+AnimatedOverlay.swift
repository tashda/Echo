import SwiftUI
import EchoSense

struct RefreshAnimatedOverlay: View {
    let phase: RefreshButtonContent.Phase
    let showCancel: Bool

    // MARK: - Spinner

    @State private var spinnerOpacity: Double = 0

    // MARK: - Checkmark

    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkOpacity: Double = 0.0

    // MARK: - Failure

    @State private var failureScale: CGFloat = 0.0
    @State private var failureOpacity: Double = 0.0
    @State private var failureRotation: Double = -90

    var body: some View {
        ZStack {
            // Spinner — visible only during refresh (no cancel hover)
            ProgressView()
                .controlSize(.small)
                .opacity(spinnerOpacity)

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

            // Failure xmark — appears with rotation + scale on failure
            Image(systemName: "xmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.error.opacity(0.8))
                .scaleEffect(failureScale)
                .opacity(failureOpacity)
                .rotationEffect(.degrees(failureRotation))
        }
        .onChange(of: phase) { oldPhase, newPhase in
            animateTransition(from: oldPhase, to: newPhase)
        }
        .onChange(of: showCancel) { _, showingCancel in
            // Sync spinner visibility with cancel state during refreshing
            guard phase == .refreshing else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                spinnerOpacity = showingCancel ? 0 : 1
            }
        }
    }

    // MARK: - Transition Choreography

    private func animateTransition(from oldPhase: RefreshButtonContent.Phase, to newPhase: RefreshButtonContent.Phase) {
        switch newPhase {
        case .refreshing:
            enterRefreshing(from: oldPhase)
        case .completed:
            enterCompleted(from: oldPhase)
        case .failed:
            enterFailed(from: oldPhase)
        case .idle:
            exitToIdle(from: oldPhase)
        }
    }

    // MARK: - Enter Refreshing

    private func enterRefreshing(from oldPhase: RefreshButtonContent.Phase) {
        // Fade out any lingering result symbols first
        if oldPhase == .completed {
            withAnimation(.easeOut(duration: 0.15)) {
                checkmarkScale = 0.6
                checkmarkOpacity = 0
            }
        } else if oldPhase == .failed {
            withAnimation(.easeOut(duration: 0.15)) {
                failureScale = 0.6
                failureOpacity = 0
                failureRotation = 90
            }
        }
        // Fade in spinner after a tiny delay to avoid overlap
        withAnimation(.easeIn(duration: 0.2).delay(oldPhase == .idle ? 0 : 0.1)) {
            spinnerOpacity = showCancel ? 0 : 1
        }
    }

    // MARK: - Enter Completed

    private func enterCompleted(from oldPhase: RefreshButtonContent.Phase) {
        // Fade out spinner
        withAnimation(.easeOut(duration: 0.12)) {
            spinnerOpacity = 0
        }
        // Reset failure if present
        failureScale = 0
        failureOpacity = 0
        failureRotation = -90

        // Pop in the checkmark with a satisfying spring bounce
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.06)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
        }
    }

    // MARK: - Enter Failed

    private func enterFailed(from oldPhase: RefreshButtonContent.Phase) {
        // Fade out spinner
        withAnimation(.easeOut(duration: 0.12)) {
            spinnerOpacity = 0
        }
        // Reset checkmark if present
        checkmarkScale = 0
        checkmarkOpacity = 0

        // Rotate-in the X from -90 degrees with a spring
        failureScale = 0.3
        failureRotation = -90
        failureOpacity = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.06)) {
            failureScale = 1.0
            failureOpacity = 1.0
            failureRotation = 0
        }
    }

    // MARK: - Exit to Idle

    private func exitToIdle(from oldPhase: RefreshButtonContent.Phase) {
        // Gracefully shrink + fade the current result symbol
        switch oldPhase {
        case .completed:
            withAnimation(.easeInOut(duration: 0.3)) {
                checkmarkScale = 0.4
                checkmarkOpacity = 0
            }
        case .failed:
            withAnimation(.easeInOut(duration: 0.3)) {
                failureScale = 0.4
                failureOpacity = 0
                failureRotation = 90
            }
        case .refreshing:
            withAnimation(.easeOut(duration: 0.15)) {
                spinnerOpacity = 0
            }
        case .idle:
            break
        }
    }
}
