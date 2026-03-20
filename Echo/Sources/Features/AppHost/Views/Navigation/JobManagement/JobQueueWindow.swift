import SwiftUI

struct JobQueueWindow: Scene {
    static let sceneID = "job-queue"
    private let coordinator = AppDirector.shared

    var body: some Scene {
        WindowGroup(id: Self.sceneID, for: UUID.self) { $sessionID in
            if let sessionID {
                JobQueueWindowContent(connectionSessionID: sessionID)
                    .environment(coordinator.projectStore)
                    .environment(coordinator.connectionStore)
                    .environment(coordinator.navigationStore)
                    .environment(coordinator.tabStore)
                    .environment(coordinator.resultSpoolConfigCoordinator)
                    .environment(coordinator.diagramBuilder)
                    .environment(coordinator.navigationStore.navigationState)
                    .environment(coordinator.environmentState)
                    .environment(coordinator.appState)
                    .environment(coordinator.clipboardHistory)
                    .environment(coordinator.appearanceStore)
                    .environment(coordinator.notificationEngine)
                    .environment(coordinator.activityEngine)
            }
        }
        .defaultSize(width: 960, height: 620)
        .windowToolbarStyle(.unified(showsTitle: true))
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Refresh Phase

private enum RefreshPhase: Int {
    case idle, loading, succeeded, failed
}

// MARK: - Window Content

private struct JobQueueWindowContent: View {
    let connectionSessionID: UUID
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @State private var showInspector = false
    @State private var showNewJobSheet = false
    @State private var refreshPhase: RefreshPhase = .idle
    @State private var refreshClearTask: Task<Void, Never>?

    private var viewModel: JobQueueViewModel? {
        environmentState.detachedJobQueueViewModels[connectionSessionID]
    }

    private var connectionSession: ConnectionSession? {
        environmentState.sessionGroup.activeSessions.first { $0.id == connectionSessionID }
    }

    private var windowTitle: String {
        let name = connectionSession?.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "SQL Agent Jobs" : "SQL Agent Jobs — \(name)"
    }

    var body: some View {
        Group {
            if let viewModel {
                JobQueueView(viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "Session Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The connection session is no longer active.")
                )
            }
        }
        .inspector(isPresented: $showInspector) {
            InfoSidebarView()
                .environment(environmentState)
                .inspectorColumnWidth(min: 220, ideal: 280, max: 400)
        }
        .toolbar(id: "jobqueue-window") {
            // Play + New Job (same group)
            ToolbarItem(id: "jobqueue.play", placement: .primaryAction) {
                if let vm = viewModel, vm.selectedJobID != nil {
                    PlayStopToolbarButton(
                        isRunning: vm.isJobRunning,
                        runningLabel: "Stop Job",
                        stoppedLabel: "Start Job"
                    ) {
                        Task {
                            if vm.isJobRunning {
                                await vm.stopSelectedJob()
                            } else {
                                await vm.startSelectedJob()
                            }
                        }
                    }
                }
            }

            ToolbarItem(id: "jobqueue.newjob", placement: .primaryAction) {
                Button {
                    showNewJobSheet = true
                } label: {
                    Label("New Job", systemImage: "plus")
                }
                .help("New Job")
            }

            // Refresh (separate group)
            ToolbarItem(id: "jobqueue.refresh", placement: .primaryAction) {
                refreshButton
                    .glassEffect(.regular.interactive())
            }
            .sharedBackgroundVisibility(.hidden)

            // Inspector (separate group)
            ToolbarItem(id: "jobqueue.inspector", placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Inspector")
                .glassEffect(.regular.interactive())
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $showNewJobSheet) {
            if let session = connectionSession {
                NewAgentJobSheet(session: session, environmentState: environmentState) {
                    showNewJobSheet = false
                    Task { await viewModel?.reloadJobs() }
                }
            }
        }
        .onChange(of: environmentState.dataInspectorContent) { _, newValue in
            if newValue != nil && !showInspector {
                showInspector = true
            }
        }
        .onChange(of: viewModel?.manuallyStartedJobName) { old, new in
            if old == nil && new != nil {
                // Job was manually started — show progress
                setRefreshPhase(.loading)
            } else if old != nil && new == nil && refreshPhase == .loading {
                // Manually-started job finished
                finishRefresh(success: viewModel?.errorMessage == nil)
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .navigationTitle(windowTitle)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background(ColorTokens.Background.primary)
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
    }

    // MARK: - Refresh Button

    @ViewBuilder
    private var refreshButton: some View {
        Button {
            guard let vm = viewModel else { return }
            setRefreshPhase(.loading)
            Task {
                await vm.reloadJobs()
                finishRefresh(success: vm.errorMessage == nil)
            }
        } label: {
            switch refreshPhase {
            case .idle:
                Label("Refresh", systemImage: "arrow.clockwise")
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .succeeded:
                Image(systemName: "checkmark")
                    .foregroundStyle(ColorTokens.Status.success)
            case .failed:
                Image(systemName: "xmark")
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
        .help("Refresh Jobs")
        .disabled(refreshPhase == .loading)
    }

    // MARK: - Refresh Helpers

    private func setRefreshPhase(_ phase: RefreshPhase) {
        refreshClearTask?.cancel()
        refreshPhase = phase
    }

    private func finishRefresh(success: Bool) {
        refreshPhase = success ? .succeeded : .failed
        refreshClearTask?.cancel()
        let delay: UInt64 = success ? 1_500_000_000 : 3_000_000_000
        refreshClearTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            refreshPhase = .idle
        }
    }
}
