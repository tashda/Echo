import SwiftUI
import EchoSense

struct RefreshButtonContent: View {
    @Bindable var session: ConnectionSession
    var accent: Color
    let onRefresh: () -> Void
    let onCancel: () -> Void

    @State private var phase: Phase = .idle
    @State private var isHovering = false
    @State private var completionTask: Task<Void, Never>?
    @State private var completionMessage: String = "Completed"
    @State private var hoverEnabled = true
    @State private var hoverEnableTask: Task<Void, Never>?
    @State private var hoverIntent = false

    enum Phase: Equatable {
        case idle
        case refreshing
        case completed
        case failed
    }

    private var showCancel: Bool {
        phase == .refreshing && isHovering
    }

    private var helpText: String {
        switch phase {
        case .idle: return "Refresh"
        case .refreshing: return session.structureLoadingMessage ?? "Updating structure\u{2026}"
        case .completed: return completionMessage
        case .failed: return "Failed"
        }
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .opacity(phase == .idle ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: phase)
                .overlay {
                    RefreshAnimatedOverlay(
                        phase: phase,
                        showCancel: showCancel
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

    // MARK: - Actions

    private func handleTap() {
        switch phase {
        case .idle, .failed:
            transition(to: .refreshing)
            onRefresh()
        case .refreshing:
            cancelRefresh()
        case .completed:
            startHoverDelay()
            transition(to: .refreshing)
            onRefresh()
        }
    }

    // MARK: - State Management

    private func transition(to newPhase: Phase) {
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = newPhase
        }
        handleHoverStateChange(for: newPhase)
        if newPhase != .refreshing {
            hoverIntent = false
        }
    }

    private func synchronizePhase(with state: StructureLoadingState) {
        switch state {
        case .loading: beginRefreshing()
        case .ready: showCompletion()
        case .failed: showFailure()
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
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            resetToIdle()
        }
    }

    private func showFailure() {
        completionTask?.cancel()
        stopHoverDelay(resetIntent: true)
        transition(to: .failed)
        completionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
        case .completed, .idle, .failed:
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
