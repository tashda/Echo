import SwiftUI
import EchoSense

struct RefreshButtonContent: View {
    @ObservedObject var session: ConnectionSession
    var accent: Color
    let onRefresh: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var phase: Phase = .idle
    @State private var spinning = false
    @State private var isHovering = false
    @State private var completionTask: Task<Void, Never>?
    @State private var completionMessage: String = "Completed"
    @State private var hoverEnabled = true
    @State private var hoverEnableTask: Task<Void, Never>?
    @State private var hoverIntent = false

    private let circleSize: CGFloat = 32
    private let glowPadding: CGFloat = 12

    enum Phase: Equatable {
        case idle
        case refreshing
        case completed
    }

    private var showCancel: Bool {
        phase == .refreshing && isHovering
    }

    private var helpText: String {
        switch phase {
        case .idle: return "Refresh"
        case .refreshing: return session.structureLoadingMessage ?? "Updating structure\u{2026}"
        case .completed: return completionMessage
        }
    }

    var body: some View {
        Group {
            if phase == .idle {
                idleButton
            } else {
                animatedButton
            }
        }
        .animation(.easeInOut(duration: 0.24), value: phase)
    }

    private var idleButton: some View {
        Button {
            transition(to: .refreshing)
            onRefresh()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.automatic)
        .help("Refresh")
    }

    private var animatedButton: some View {
        Button {
            if phase == .refreshing {
                cancelRefresh()
            } else {
                startHoverDelay()
                transition(to: .refreshing)
                onRefresh()
            }
        } label: {
            Label("Refresh", systemImage: "circle")
                .labelStyle(.iconOnly)
                .foregroundStyle(.clear)
                .overlay {
                    RefreshAnimatedOverlay(
                        phase: phase,
                        showCancel: showCancel,
                        spinning: spinning,
                        circleSize: circleSize,
                        glowPadding: glowPadding
                    )
                }
        }
        .buttonStyle(.automatic)
        .help(helpText)
        .accessibilityLabel(helpText)
#if os(macOS)
        .onHover { hovering in
            hoverIntent = hovering
            if hoverEnabled {
                isHovering = hovering
            } else if !hovering {
                isHovering = false
            }
        }
#endif
        .onAppear {
            synchronizePhase(with: session.structureLoadingState)
        }
        .onChange(of: session.structureLoadingState) { _, newValue in
            synchronizePhase(with: newValue)
        }
        .onDisappear {
            completionTask?.cancel()
            hoverEnableTask?.cancel()
        }
    }

    // MARK: - State Management

    private func transition(to newPhase: Phase) {
        withAnimation(.easeInOut(duration: 0.24)) {
            phase = newPhase
        }
        spinning = (newPhase == .refreshing)
        handleHoverStateChange(for: newPhase)
        if newPhase != .refreshing {
            hoverIntent = false
        }
    }

    private func synchronizePhase(with state: StructureLoadingState) {
        switch state {
        case .loading: beginRefreshing()
        case .ready: showCompletion()
        case .failed: showCompletion(with: "Failed")
        case .idle: resetToIdle()
        }
    }

    private func beginRefreshing() {
        completionTask?.cancel()
        if hoverEnableTask == nil { startHoverDelay() }
        transition(to: .refreshing)
    }

    private func showCompletion(with message: String? = nil) {
        completionTask?.cancel()
        completionMessage = message ?? "Completed"
        stopHoverDelay(resetIntent: true)
        transition(to: .completed)
        completionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            resetToIdle()
        }
    }

    private func resetToIdle() {
        guard phase != .idle else { return }
        completionTask?.cancel()
        stopHoverDelay(resetIntent: true)
        transition(to: .idle)
    }

    private func cancelRefresh() {
        guard phase == .refreshing else { return }
        completionTask?.cancel()
        onCancel()
        stopHoverDelay(resetIntent: true)
        transition(to: .idle)
    }

    private func handleHoverStateChange(for newPhase: Phase) {
        switch newPhase {
        case .refreshing:
            if hoverEnableTask == nil { startHoverDelay() }
        case .completed, .idle:
            stopHoverDelay(resetIntent: true)
        }
    }

    private func startHoverDelay() {
        hoverEnableTask?.cancel()
        hoverEnabled = false
        isHovering = false
        hoverEnableTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            if phase == .refreshing {
                hoverEnabled = true
                if hoverIntent { isHovering = true }
            }
        }
    }

    private func stopHoverDelay(resetIntent: Bool) {
        hoverEnableTask?.cancel()
        hoverEnableTask = nil
        hoverEnabled = true
        if resetIntent { hoverIntent = false }
        isHovering = false
    }
}
