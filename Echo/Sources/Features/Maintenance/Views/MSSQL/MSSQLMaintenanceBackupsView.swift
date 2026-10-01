import SwiftUI
import SQLServerKit

struct MSSQLMaintenanceBackupsView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) var environmentState
    @Environment(AppState.self) var appState

    @State private var sortOrder = [KeyPathComparator(\SQLServerBackupHistoryEntry.finishDate, order: .reverse)]
    @State private var selection: Set<SQLServerBackupHistoryEntry.ID> = []
    @State private var showBackupSheet = false
    @State private var showRestoreSheet = false

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        Group {
            if let permissionError = viewModel.backupPermissionError {
                TabContentUnavailableView("Insufficient Permissions", systemImage: "lock.shield") {
                    Text(permissionError)
                }
            } else {
                // New Backup is the page's special button, Restore its group (round 37.5).
                historyContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tabToolbar(special: newBackupItem, groups: [[restoreItem]])
                .sheet(isPresented: $showBackupSheet) {
                    if let vm = viewModel.backupsVM {
                        MSSQLBackupSidebarSheet(viewModel: vm) {
                            showBackupSheet = false
                            Task { await viewModel.refreshBackups() }
                        }
                    }
                }
                .sheet(isPresented: $showRestoreSheet) {
                    if let vm = viewModel.backupsVM {
                        MSSQLRestoreSidebarSheet(viewModel: vm) {
                            showRestoreSheet = false
                            Task { await viewModel.refreshBackups() }
                        }
                    }
                }
            }
        }
        .tabContentFrame()
    }

    private var canBackupRestore: Bool { session?.permissions?.canBackupRestore ?? true }

    private var newBackupItem: TabToolbarItem {
        TabToolbarItem(id: "newBackup", title: "New Backup", symbol: "plus", isDisabled: !canBackupRestore) {
            viewModel.backupsVM?.resetBackupState()
            showBackupSheet = true
        }
    }

    private var restoreItem: TabToolbarItem {
        TabToolbarItem(id: "restore", title: "Restore", symbol: "arrow.counterclockwise", isDisabled: !canBackupRestore) {
            viewModel.backupsVM?.resetRestoreState()
            showRestoreSheet = true
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if viewModel.isRefreshingBackups && viewModel.backupHistory.isEmpty {
            TabInitializingPlaceholder(
                icon: "externaldrive",
                title: "Loading Backup History",
                subtitle: "Fetching recent database backups…"
            )
        } else if viewModel.backupHistory.isEmpty {
            TabContentUnavailableView("No Backup History", systemImage: "externaldrive") {
                Text("No recent backups were found for the selected database.")
            } actions: {
                Button("New Backup") {
                    viewModel.backupsVM?.resetBackupState()
                    showBackupSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(!(session?.permissions?.canBackupRestore ?? true))
            }
        } else {
            historyTable
        }
    }

    private var historyTable: some View {
        Table(viewModel.backupHistory, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Type") { entry in
                Text(entry.typeDescription)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(80)
            TableColumn("Finished") { entry in
                if let date = entry.finishDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    Text("\u{2014}")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .width(130)
            TableColumn("Size") { entry in
                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .binary))
                    .font(TypographyTokens.Table.numeric)
            }
            .width(80)
            TableColumn("Device") { entry in
                Text(entry.physicalPath)
                    .font(TypographyTokens.Table.path)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: SQLServerBackupHistoryEntry.ID.self) { ids in
            if ids.first != nil {
                Button {
                    appState.showInfoSidebar.toggle()
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }
                Button {
                    if let id = ids.first, let entry = viewModel.backupHistory.first(where: { $0.id == id }) {
                        viewModel.backupsVM?.restoreDiskPath = entry.physicalPath
                        viewModel.backupsVM?.restoreDatabaseName = viewModel.selectedDatabase ?? ""
                        viewModel.backupsVM?.restorePhase = .idle
                        showRestoreSheet = true
                    }
                } label: {
                    Label("Restore from this Backup", systemImage: "arrow.counterclockwise")
                }
                .disabled(!(session?.permissions?.canBackupRestore ?? true))
            }
        } primaryAction: { _ in
            if let id = selection.first, let entry = viewModel.backupHistory.first(where: { $0.id == id }) {
                pushBackupInspector(entry, toggle: true)
            }
        }
        .onChange(of: selection) { _, newSelection in
            if let id = newSelection.first, let entry = viewModel.backupHistory.first(where: { $0.id == id }) {
                pushBackupInspector(entry, toggle: false)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.backupHistory.sort(using: newOrder)
        }
        .onAppear {
            if viewModel.backupsActiveForm == .backup {
                viewModel.backupsActiveForm = nil
                showBackupSheet = true
            } else if viewModel.backupsActiveForm == .restore {
                viewModel.backupsActiveForm = nil
                showRestoreSheet = true
            }
        }
    }

}
