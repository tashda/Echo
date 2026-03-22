import SwiftUI
import SQLServerKit

struct MSSQLMaintenanceBackupsView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    @State private var sortOrder = [KeyPathComparator(\SQLServerBackupHistoryEntry.finishDate, order: .reverse)]
    @State private var selection: Set<SQLServerBackupHistoryEntry.ID> = []
    @State private var showBackupSheet = false
    @State private var showRestoreSheet = false

    var body: some View {
        if let permissionError = viewModel.backupPermissionError {
            ContentUnavailableView {
                Label("Insufficient Permissions", systemImage: "lock.shield")
            } description: {
                Text(permissionError)
            }
        } else {
            VStack(spacing: 0) {
                toolbar
                Divider()
                historyTable
            }
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

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Spacer()

            Button {
                viewModel.backupsVM?.resetBackupState()
                showBackupSheet = true
            } label: {
                Label("New Backup", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                viewModel.backupsVM?.resetRestoreState()
                showRestoreSheet = true
            } label: {
                Label("Restore", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
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

    private func pushBackupInspector(_ entry: SQLServerBackupHistoryEntry, toggle: Bool) {
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Database", value: entry.serverName),
            .init(label: "Backup Type", value: entry.typeDescription),
            .init(label: "Started", value: entry.startDate?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}"),
            .init(label: "Finished", value: entry.finishDate?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}"),
            .init(label: "Size", value: ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .binary)),
            .init(label: "Compressed Size", value: entry.compressedSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .binary) } ?? "N/A"),
            .init(label: "Physical Device", value: entry.physicalPath),
            .init(label: "Recovery Model", value: entry.recoveryModel),
            .init(label: "Server", value: entry.serverName)
        ]

        let content = DatabaseObjectInspectorContent(
            title: entry.name ?? "Backup #\(entry.id)",
            subtitle: "Backup Entry",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: entry.name ?? "Backup #\(entry.id)", appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }
}
