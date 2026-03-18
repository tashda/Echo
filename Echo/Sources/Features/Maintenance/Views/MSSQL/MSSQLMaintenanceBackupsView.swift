import SwiftUI

struct MSSQLMaintenanceBackupsView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    
    @State private var sortOrder = [KeyPathComparator(\SQLServerBackupHistoryEntry.finishDate, order: .reverse)]
    @State private var selection: Set<SQLServerBackupHistoryEntry.ID> = []

    var body: some View {
        VStack(spacing: 0) {
            Table(viewModel.backupHistory, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Type", value: \.typeDescription)
                    .width(80)
                TableColumn("Finished") { entry in
                    Text(entry.finishDate?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                }
                TableColumn("Size") { entry in
                    Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .binary))
                        .font(TypographyTokens.monospaced)
                }
                TableColumn("Device") { entry in
                    Text(entry.physicalPath)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
            }
            .contextMenu(forSelectionType: SQLServerBackupHistoryEntry.ID.self) { ids in
                if let id = ids.first, let _ = viewModel.backupHistory.first(where: { $0.id == id }) {
                    Button {
                        appState.showInfoSidebar.toggle()
                    } label: {
                        Label("View Details", systemImage: "info.circle")
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
        }
    }

    private func pushBackupInspector(_ entry: SQLServerBackupHistoryEntry, toggle: Bool) {
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Database", value: entry.serverName), 
            .init(label: "Backup Type", value: entry.typeDescription),
            .init(label: "Started", value: entry.startDate?.formatted(date: .abbreviated, time: .shortened) ?? "—"),
            .init(label: "Finished", value: entry.finishDate?.formatted(date: .abbreviated, time: .shortened) ?? "—"),
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
