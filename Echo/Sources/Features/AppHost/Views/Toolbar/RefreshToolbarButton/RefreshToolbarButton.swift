import SwiftUI
import EchoSense

struct RefreshToolbarButton: View {
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(TabStore.self) private var tabStore

    @State private var refreshTask: Task<Void, Never>?

    private var activeSession: ConnectionSession? {
        environmentState.sessionGroup.activeSession ?? environmentState.sessionGroup.activeSessions.first
    }

    var body: some View {
        if let session = activeSession {
            RefreshButtonContent(session: session,
                                 accent: appearanceStore.accentColor,
                                 onRefresh: { startRefresh(for: session) },
                                 onCancel: { cancelRefresh(for: session) })
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
        } else if let selected = session.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines),
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
