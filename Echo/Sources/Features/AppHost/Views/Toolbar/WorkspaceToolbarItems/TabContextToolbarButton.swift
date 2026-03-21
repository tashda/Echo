import SwiftUI

/// Toolbar controls for Activity Monitor tabs — separate Liquid Glass group.
/// Uses eye/eye.slash to distinguish monitoring (passive observation) from execution actions.
struct ActivityMonitorToolbarItem: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, let vm = tab.activityMonitor {
            Button {
                if vm.isRunning { vm.stopStreaming() } else { vm.startStreaming() }
            } label: {
                Label(
                    vm.isRunning ? "Pause Monitoring" : "Resume Monitoring",
                    systemImage: vm.isRunning ? "eye.fill" : "eye.slash"
                )
                .contentTransition(.symbolEffect(.replace))
            }
            .help(vm.isRunning ? "Pause Monitoring" : "Resume Monitoring")
            .labelStyle(.iconOnly)
            .accessibilityLabel(vm.isRunning ? "Pause Monitoring" : "Resume Monitoring")
            .glassEffect(.regular.interactive())
        } else {
            EmptyView()
        }
    }
}

/// Toolbar button to start/stop a selected job in a Job Queue tab.
struct JobQueuePlayToolbarItem: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, let vm = tab.jobQueue, vm.selectedJobID != nil {
            ToolbarRunButton(
                isRunning: vm.isJobRunning,
                idleLabel: "Start Job",
                runningLabel: "Stop Job"
            ) {
                Task {
                    if vm.isJobRunning { await vm.stopSelectedJob() } else { await vm.startSelectedJob() }
                }
            }
        } else {
            EmptyView()
        }
    }
}

/// Toolbar button to pop a Job Queue tab into a separate window.
struct JobQueuePopOutToolbarItem: View {
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let tab = tabStore.activeTab, tab.kind == .jobQueue {
            Button {
                if let sessionID = environmentState.popOutJobQueueTab(tab) {
                    openWindow(id: JobQueueWindow.sceneID, value: sessionID)
                }
            } label: {
                Label("Open in Window", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .help("Open in separate window")
            .accessibilityLabel("Open in separate window")
            .glassEffect(.regular.interactive())
        } else {
            EmptyView()
        }
    }
}

/// Toolbar controls for maintenance database picker — separate Liquid Glass group.
struct TabContextToolbarButton: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab {
            tabControls(for: tab)
        }
    }

    @ViewBuilder
    private func tabControls(for tab: WorkspaceTab) -> some View {
        switch tab.kind {
        case .mssqlMaintenance:
            if let vm = tab.mssqlMaintenance {
                MaintenanceToolbarControls(
                    databases: vm.databaseList,
                    selectedDatabase: Binding(
                        get: { vm.selectedDatabase },
                        set: { db in
                            guard let db else { return }
                            Task { await vm.selectDatabase(db) }
                        }
                    )
                )
                .glassEffect(.regular.interactive())
            }
        case .maintenance:
            if let vm = tab.maintenance {
                MaintenanceToolbarControls(
                    databases: vm.databaseList,
                    selectedDatabase: Binding(
                        get: { vm.selectedDatabase },
                        set: { vm.selectedDatabase = $0 }
                    )
                )
                .glassEffect(.regular.interactive())
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Maintenance Controls

private struct MaintenanceToolbarControls: View {
    let databases: [String]
    @Binding var selectedDatabase: String?

    var body: some View {
        Menu {
            ForEach(databases, id: \.self) { db in
                Button {
                    selectedDatabase = db
                } label: {
                    HStack {
                        Text(db)
                        if selectedDatabase == db {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(selectedDatabase ?? "Select Database")
                .font(TypographyTokens.detail)
                .frame(minWidth: 24)
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
