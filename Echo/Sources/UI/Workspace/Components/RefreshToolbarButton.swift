import SwiftUI
import EchoSense

struct RefreshToolbarButton: View {
    @Environment(NavigationStore.self) private var navigationStore
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        if let session = appModel.sessionManager.activeSession ?? appModel.sessionManager.activeSessions.first {
            RefreshButtonContent(session: session,
                                 accent: themeManager.accentColor,
                                 onRefresh: { startRefresh(for: session) },
                                 onCancel: { cancelRefresh(for: session) })
        } else {
            RefreshButtonPlaceholder()
        }
    }

    private func startRefresh(for session: ConnectionSession) {
        refreshTask?.cancel()
        refreshTask = Task {
            await performRefresh(for: session)
            await MainActor.run {
                refreshTask = nil
            }
        }
    }

    @MainActor
    private func performRefresh(for session: ConnectionSession) async {
        guard !Task.isCancelled else {
            session.structureLoadingState = .idle
            session.structureLoadingMessage = nil
            return
        }

        let databaseOverride = navigationStore.navigationState.selectedDatabase?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let database = databaseOverride, !database.isEmpty {
            await appModel.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: database
            )
        } else if let selected = session.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !selected.isEmpty {
            await appModel.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: selected
            )
        } else {
            await appModel.refreshDatabaseStructure(for: session.id, scope: .full)
        }
    }

    private func cancelRefresh(for session: ConnectionSession) {
        refreshTask?.cancel()
        refreshTask = nil
        session.structureLoadingState = .idle
        session.structureLoadingMessage = nil
    }
}

private struct RefreshButtonContent: View {
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

    private enum Phase: Equatable {
        case idle
        case refreshing
        case completed
    }

    private var iconName: String {
        switch phase {
        case .completed: return "checkmark"
        default: return "arrow.clockwise"
        }
    }

    private var showCancel: Bool {
        phase == .refreshing && isHovering
    }

    private var spinnerSymbol: String {
        if showCancel {
            return "xmark"
        }
        return iconName
    }

    private var currentSymbol: String {
        shouldSpin ? "arrow.clockwise" : spinnerSymbol
    }

    private var shouldSpin: Bool {
        phase == .refreshing && !showCancel && spinning
    }

    private var iconColor: Color {
        if showCancel {
            return Color.primary.opacity(colorScheme == .dark ? 0.95 : 0.9)
        }
        switch phase {
        case .idle:
            return Color.secondary.opacity(colorScheme == .dark ? 0.85 : 0.65)
        case .refreshing:
            return Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.85)
        case .completed:
            return Color.white
        }
    }

    private var circleFill: Color {
        switch phase {
        case .idle:
            return idleFill
        case .refreshing:
            return Color.yellow.opacity(colorScheme == .dark ? 0.35 : 0.18)
        case .completed:
            return Color.green.opacity(colorScheme == .dark ? 0.45 : 0.22)
        }
    }

    private var idleFill: Color {
        toolbarIdleFill(for: colorScheme)
    }

    private var glowColor: Color {
        switch phase {
        case .refreshing:
            return Color.yellow
        case .completed:
            return Color.green
        case .idle:
            return .clear
        }
    }

    private var glowOpacity: Double {
        switch phase {
        case .refreshing: return isHovering ? 0.65 : 0.55
        case .completed: return 0.5
        case .idle: return 0
        }
    }

    private var helpText: String {
        switch phase {
        case .idle:
            return "Refresh"
        case .refreshing:
            return session.structureLoadingMessage ?? "Updating structure…"
        case .completed:
            return completionMessage
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
                    ZStack {
                        if glowOpacity > 0 {
                            GlowBorder(cornerRadius: circleSize / 2, color: glowColor)
                                .frame(width: circleSize + glowPadding, height: circleSize + glowPadding)
                                .opacity(glowOpacity)
                                .allowsHitTesting(false)
                        }

                        Circle()
                            .fill(circleFill)
                            .frame(width: circleSize, height: circleSize)

                        Image(systemName: currentSymbol)
                            .rotationEffect(shouldSpin ? .degrees(360) : .degrees(0))
                            .animation(
                                shouldSpin
                                    ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                                    : .easeInOut(duration: 0.2),
                                value: shouldSpin
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
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
        case .loading:
            beginRefreshing()
        case .ready:
            showCompletion()
        case .failed:
            showCompletion(with: "Failed")
        case .idle:
            resetToIdle()
        }
    }

    private func beginRefreshing() {
        completionTask?.cancel()
        if hoverEnableTask == nil {
            startHoverDelay()
        }
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
            if hoverEnableTask == nil {
                startHoverDelay()
            }
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
                if hoverIntent {
                    isHovering = true
                }
            }
        }
    }

    private func stopHoverDelay(resetIntent: Bool) {
        hoverEnableTask?.cancel()
        hoverEnableTask = nil
        hoverEnabled = true
        if resetIntent {
            hoverIntent = false
        }
        isHovering = false
    }
}

private struct RefreshButtonPlaceholder: View {
    var body: some View {
        Button(action: {}) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.automatic)
        .disabled(true)
        .help("Refresh (Unavailable)")
    }
}

private struct GlowBorder: View {
    var cornerRadius: CGFloat
    var color: Color

    @State private var gradientRotation: Angle = .degrees(0)

    private var animatedGradient: AngularGradient {
        let colors = [
            color,
            color.opacity(0.75),
            color.opacity(0.45),
            color.opacity(0.75),
            color
        ]
        return AngularGradient(gradient: Gradient(colors: colors), center: .center, angle: gradientRotation)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 4)
                .blur(radius: 7)
                .opacity(0.4)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 10)
                .blur(radius: 16)
                .opacity(0.24)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(animatedGradient, lineWidth: 18)
                .blur(radius: 26)
                .opacity(0.18)
        }
        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: gradientRotation)
        .onAppear {
            gradientRotation = .degrees(360)
        }
    }
}
