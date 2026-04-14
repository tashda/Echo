import SwiftUI
import EchoSense

struct RefreshToolbarButton: View {
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(TabStore.self) private var tabStore
    @Environment(ActivityEngine.self) private var activityEngine

    @State private var refreshTask: Task<Void, Never>?

    private var activeSession: ConnectionSession? {
        environmentState.sessionGroup.activeSession ?? environmentState.sessionGroup.activeSessions.first
    }

    private var hasPendingConnection: Bool {
        environmentState.pendingConnections.contains { $0.phase == .connecting }
    }

    private var hasFailedPendingConnection: Bool {
        environmentState.pendingConnections.contains { if case .failed = $0.phase { return true } else { return false } }
    }

    var body: some View {
        if let session = activeSession {
            RefreshButtonContent(session: session,
                                 activityEngine: activityEngine,
                                 accent: appearanceStore.accentColor,
                                 onRefresh: { startRefresh(for: session) },
                                 onCancel: { cancelRefresh(for: session) })
        } else if hasPendingConnection || hasFailedPendingConnection {
            RefreshButtonPendingContent(
                isPending: hasPendingConnection,
                isFailed: hasFailedPendingConnection,
                onCancel: { cancelAllPendingConnections() }
            )
        } else {
            Button(action: {}) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .disabled(true)
            .help("Refresh (No connection)")
        }
    }

    private func startRefresh(for session: ConnectionSession) {
        // Dispatch based on active tab type
        if let activeTab = tabStore.activeTab {
            switch activeTab.kind {
            case .maintenance:
                if let vm = activeTab.maintenance {
                    session.structureLoadingState = .loading(progress: nil)
                    refreshTask = Task {
                        await vm.refresh()
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .mssqlMaintenance:
                if let vm = activeTab.mssqlMaintenance {
                    session.structureLoadingState = .loading(progress: nil)
                    refreshTask = Task {
                        await vm.refresh()
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .activityMonitor:
                if let vm = activeTab.activityMonitor {
                    session.structureLoadingState = .loading(progress: nil)
                    vm.refresh()
                    // refresh() fires internally — signal completion after a brief delay
                    refreshTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .errorLog:
                if let vm = activeTab.errorLogVM {
                    session.structureLoadingState = .loading(progress: nil)
                    refreshTask = Task {
                        await vm.refresh()
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .extendedEvents:
                if let vm = activeTab.extendedEventsVM {
                    session.structureLoadingState = .loading(progress: nil)
                    refreshTask = Task {
                        await vm.loadSessions()
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .structure:
                if let vm = activeTab.structureEditor {
                    session.structureLoadingState = .loading(progress: nil)
                    refreshTask = Task {
                        await vm.reload()
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .jobQueue:
                if let vm = activeTab.jobQueue {
                    let handle = activityEngine.begin("Refresh Agent Jobs", connectionSessionID: session.id)
                    refreshTask = Task {
                        await vm.reloadJobs()
                        if vm.errorMessage != nil {
                            handle.fail(vm.errorMessage ?? "")
                        } else {
                            handle.succeed()
                        }
                        refreshTask = nil
                    }
                    return
                }
            case .diagram:
                if let vm = activeTab.diagram {
                    session.structureLoadingState = .loading(progress: nil)
                    refreshTask = Task {
                        await environmentState.diagramBuilder.refreshDiagram(for: vm)
                        session.structureLoadingState = .ready
                        refreshTask = nil
                    }
                    return
                }
            case .profiler:
                if let vm = activeTab.profilerVM {
                    vm.refresh() // Non-async but might start tasks
                    return
                }
            case .resourceGovernor:
                if let vm = activeTab.resourceGovernorVM {
                    vm.refresh()
                    return
                }
            case .serverProperties:
                // TODO: Implement server properties refresh
                break
            case .tuningAdvisor:
                if let vm = activeTab.tuningAdvisorVM {
                    vm.refresh()
                    return
                }
            case .policyManagement:
                if let vm = activeTab.policyManagementVM {
                    vm.refresh()
                    return
                }
            default:
                break
            }
        }

        // Default: refresh database structure
        refreshTask?.cancel()
        session.structureLoadingState = .loading(progress: 0)
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
            await environmentState.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: database
            )
        } else if let selected = session.sidebarFocusedDatabase?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !selected.isEmpty {
            await environmentState.refreshDatabaseStructure(
                for: session.id,
                scope: .selectedDatabase,
                databaseOverride: selected
            )
        } else {
            await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
        }
    }

    private func cancelAllPendingConnections() {
        let ids = environmentState.pendingConnections.map(\.id)
        for id in ids {
            environmentState.cancelPendingConnection(for: id)
        }
    }

    private func cancelRefresh(for session: ConnectionSession) {
        refreshTask?.cancel()
        refreshTask = nil
        session.structureLoadingState = .idle
        session.structureLoadingMessage = nil
    }
}

struct RefreshButtonPlaceholder: View {
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
