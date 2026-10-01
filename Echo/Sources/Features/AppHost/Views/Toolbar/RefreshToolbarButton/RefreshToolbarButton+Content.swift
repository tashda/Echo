import SwiftUI

/// The Refresh button's face: the arrow at rest; a spinner while its reload runs (hover after 3 s
/// to cancel); then ✓ or ✗ for a moment. The phase comes from `TabReloader`.
struct RefreshButtonContent: View {
    let phase: TabReloader.Phase
    let resultMessage: String
    let onRefresh: () -> Void
    let onCancel: () -> Void

    @State private var isHovering = false
    @State private var hoverEnabled = true
    @State private var hoverEnableTask: Task<Void, Never>?
    @State private var hoverIntent = false
    @State private var refreshIconOpacity: Double = 1.0
    @State private var refreshIconScale: CGFloat = 1.0

    private var showCancel: Bool {
        phase == .refreshing && isHovering
    }

    private var helpText: String {
        switch phase {
        case .idle: "Refresh (⌘R)"
        case .refreshing: "Reloading; click to cancel"
        case .completed: resultMessage
        case .failed: resultMessage.isEmpty ? "Failed" : resultMessage
        }
    }

    var body: some View {
        Button {
            phase == .refreshing ? onCancel() : onRefresh()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .scaleEffect(refreshIconScale)
                .opacity(refreshIconOpacity)
                .overlay {
                    RefreshAnimatedOverlay(phase: phase, showCancel: showCancel)
                }
        }
        .buttonStyle(.automatic)
        .help(helpText)
        .accessibilityLabel(helpText)
        .onHover { hovering in
            hoverIntent = hovering
            if hoverEnabled {
                isHovering = hovering
            } else if !hovering {
                isHovering = false
            }
        }
        .onAppear { animateRefreshIcon(from: .idle, to: phase) }
        .onChange(of: phase) { oldPhase, newPhase in
            animateRefreshIcon(from: oldPhase, to: newPhase)
            if newPhase == .refreshing {
                startHoverDelay()
            } else {
                stopHoverDelay()
            }
        }
        .onDisappear { hoverEnableTask?.cancel() }
    }

    private func animateRefreshIcon(from oldPhase: TabReloader.Phase, to newPhase: TabReloader.Phase) {
        if newPhase == .idle {
            // Back at rest: the arrow fades in once the result symbol has shrunk.
            let delay: Double = (oldPhase == .completed || oldPhase == .failed) ? 0.15 : 0
            withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                refreshIconOpacity = 1.0
                refreshIconScale = 1.0
            }
        } else if oldPhase == .idle || refreshIconOpacity > 0 {
            withAnimation(.easeIn(duration: 0.15)) {
                refreshIconOpacity = 0
                refreshIconScale = 0.7
            }
        }
    }

    /// The cancel symbol appears on hover only after 3 s, so a quick second click doesn't cancel.
    private func startHoverDelay() {
        hoverEnableTask?.cancel()
        hoverEnabled = false
        isHovering = false
        hoverEnableTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            hoverEnabled = true
            if hoverIntent { isHovering = true }
        }
    }

    private func stopHoverDelay() {
        hoverEnableTask?.cancel()
        hoverEnableTask = nil
        hoverEnabled = true
        hoverIntent = false
        isHovering = false
    }
}
