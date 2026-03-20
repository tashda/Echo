import SwiftUI

/// Shows a spinner or failure icon in the refresh button slot while a connection is pending.
/// Clicking during the connecting phase cancels all pending connections.
struct RefreshButtonPendingContent: View {
    let isPending: Bool
    let isFailed: Bool
    let onCancel: () -> Void

    @State private var phase: Phase = .connecting
    @State private var resetTask: Task<Void, Never>?
    @State private var isHovering = false
    @State private var showOverlay = true

    enum Phase {
        case connecting
        case failed
    }

    private var showCancel: Bool {
        phase == .connecting && isHovering
    }

    var body: some View {
        Button {
            if phase == .connecting {
                onCancel()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .opacity(showOverlay ? 0 : 1)
                .overlay {
                    if showOverlay {
                        RefreshPendingOverlay(phase: phase, showCancel: showCancel)
                    }
                }
        }
        .buttonStyle(.automatic)
        .disabled(!showOverlay)
        .help(helpText)
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear { synchronize() }
        .onChange(of: isPending) { _, _ in synchronize() }
        .onChange(of: isFailed) { _, _ in synchronize() }
        .onDisappear { resetTask?.cancel() }
    }

    private var helpText: String {
        if !showOverlay { return "Refresh (No connection)" }
        if phase == .connecting {
            return isHovering ? "Cancel connection" : "Connecting\u{2026}"
        }
        return "Connection failed"
    }

    private func synchronize() {
        resetTask?.cancel()
        if isPending {
            showOverlay = true
            withAnimation(.easeInOut(duration: 0.2)) { phase = .connecting }
        } else if isFailed {
            showOverlay = true
            withAnimation(.easeInOut(duration: 0.2)) { phase = .failed }
            isHovering = false
            resetTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                showOverlay = false
            }
        }
    }
}

// MARK: - Overlay

private struct RefreshPendingOverlay: View {
    let phase: RefreshButtonPendingContent.Phase
    let showCancel: Bool

    @State private var failureScale: CGFloat = 0
    @State private var failureOpacity: Double = 0
    @State private var failureRotation: Double = -90

    var body: some View {
        ZStack {
            ProgressView()
                .controlSize(.small)
                .opacity(phase == .connecting && !showCancel ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: phase)
                .animation(.easeInOut(duration: 0.15), value: showCancel)

            // Cancel icon — visible on hover during connecting
            Image(systemName: "xmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary.opacity(0.65))
                .opacity(showCancel ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: showCancel)

            // Failure xmark — softened red, with rotation + spring entrance
            Image(systemName: "xmark")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.error.opacity(0.8))
                .scaleEffect(failureScale)
                .opacity(failureOpacity)
                .rotationEffect(.degrees(failureRotation))
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .failed {
                failureScale = 0.3
                failureRotation = -90
                failureOpacity = 0
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    failureScale = 1.0
                    failureOpacity = 1.0
                    failureRotation = 0
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    failureScale = 0.4
                    failureOpacity = 0
                    failureRotation = 90
                }
            }
        }
    }
}
