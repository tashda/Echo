import SwiftUI

/// Toolbar controls for Activity Monitor tabs — separate Liquid Glass group.
struct ActivityMonitorToolbarItem: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, let vm = tab.activityMonitor {
            Button {
                if vm.isRunning {
                    vm.stopStreaming()
                } else {
                    vm.startStreaming()
                }
            } label: {
                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                    .foregroundStyle(vm.isRunning ? .green : .red)
                    .contentTransition(.symbolEffect(.replace))
            }
            .help(vm.isRunning ? "Pause Monitoring" : "Resume Monitoring")
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
