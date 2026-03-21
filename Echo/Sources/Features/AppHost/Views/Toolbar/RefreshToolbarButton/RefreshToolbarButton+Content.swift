import SwiftUI
import EchoSense

struct RefreshButtonContent: View {
    @Bindable var session: ConnectionSession
    var activityEngine: ActivityEngine
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
    @State private var refreshIconOpacity: Double = 1.0
    @State private var refreshIconScale: CGFloat = 1.0

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
        case .refreshing:
            return activityEngine.activeMessage(for: session.id)
                ?? activityEngine.activeLabel(for: session.id)
                ?? session.structureLoadingMessage
                ?? "Updating structure\u{2026}"
        case .completed: return completionMessage
        case .failed: return completionMessage.isEmpty ? "Failed" : completionMessage
        }
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .scaleEffect(refreshIconScale)
                .opacity(refreshIconOpacity)
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
        .onChange(of: activityEngine.isActive(for: session.id)) { _, isActive in
            if isActive {
                beginRefreshing()
            } else if session.structureLoadingState == .idle || session.structureLoadingState == .ready {
                // Activity engine finished and structure loading isn't running — check for result
                synchronizeActivityResult()
            }
        }
        .onChange(of: activityEngine.lastResult?.id) { _, _ in
            synchronizeActivityResult()
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
        let oldPhase = phase
        phase = newPhase
        animateRefreshIcon(from: oldPhase, to: newPhase)
        handleHoverStateChange(for: newPhase)
        if newPhase != .refreshing {
            hoverIntent = false
        }
    }

    private func animateRefreshIcon(from oldPhase: Phase, to newPhase: Phase) {
        if newPhase == .idle {
            // Returning to idle — fade the refresh icon back in with a gentle scale-up
            // Delay slightly so the result symbol has time to shrink first
            let delay: Double = (oldPhase == .completed || oldPhase == .failed) ? 0.15 : 0
            withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                refreshIconOpacity = 1.0
                refreshIconScale = 1.0
            }
        } else if oldPhase == .idle {
            // Leaving idle — shrink + fade the refresh icon out
            withAnimation(.easeIn(duration: 0.15)) {
                refreshIconOpacity = 0
                refreshIconScale = 0.7
            }
        }
        // For non-idle → non-idle transitions (e.g. refreshing → completed),
        // the refresh icon stays hidden — no animation needed.
    }

    private func synchronizePhase(with state: StructureLoadingState) {
        // If the activity engine has active operations for this session, stay in refreshing
        if activityEngine.isActive(for: session.id) {
            beginRefreshing()
            return
        }
        switch state {
        case .loading: beginRefreshing()
        case .ready: showCompletion()
        case .failed: showFailure()
        case .idle: resetToIdle()
        }
    }

    private func synchronizeActivityResult() {
        guard let result = activityEngine.lastResult,
              result.connectionSessionID == session.id else { return }
        // Don't override if structure loading is still in progress
        if case .loading = session.structureLoadingState { return }

        switch result.outcome {
        case .succeeded:
            showCompletion(with: result.label)
        case .failed(let message):
            showFailure(with: message.isEmpty ? result.label : "\(result.label): \(message)")
        case .cancelled:
            break
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

    private func showFailure(with message: String? = nil) {
        completionTask?.cancel()
        if let message { completionMessage = message }
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
