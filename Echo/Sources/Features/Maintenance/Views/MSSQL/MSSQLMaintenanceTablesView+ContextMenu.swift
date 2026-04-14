import SwiftUI

extension MSSQLMaintenanceTablesView {

    @ViewBuilder
    func tableContextMenu(for table: SQLServerTableStat) -> some View {
        Button {
            Task { await viewModel.updateTableStats(table) }
        } label: {
            Label("Update Statistics", systemImage: "chart.bar")
        }
        .disabled(!(session?.permissions?.canManageServerState ?? true))

        Button {
            Task { await viewModel.checkTable(table) }
        } label: {
            Label("Check Table", systemImage: "checkmark.shield")
        }
        .disabled(!(session?.permissions?.canBackupRestore ?? true))

        Button {
            Task { await viewModel.rebuildAllIndexes(table) }
        } label: {
            Label("Rebuild All Indexes", systemImage: "hammer")
        }
        .disabled(!(session?.permissions?.canManageServerState ?? true))

        Button {
            Task { await viewModel.reorganizeAllIndexes(table) }
        } label: {
            Label("Reorganize All Indexes", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(!(session?.permissions?.canManageServerState ?? true))

        Divider()

        Button {
            Task { await viewModel.rebuildTable(table) }
        } label: {
            Label("Rebuild Table", systemImage: "arrow.clockwise")
        }
        .disabled(!(session?.permissions?.canManageServerState ?? true))

        Divider()

        Button {
            openStructure(for: table)
        } label: {
            Label("View Structure", systemImage: "tablecells")
        }
    }

    func pushTableInspector(_ table: SQLServerTableStat, toggle: Bool) {
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Schema", value: table.schemaName),
            .init(label: "Table", value: table.tableName),
            .init(label: "Type", value: table.tableType),
            .init(label: "Rows", value: formatCount(table.rowCount)),
            .init(label: "Data Size", value: ByteCountFormatter.string(fromByteCount: table.dataSpaceBytes, countStyle: .binary)),
            .init(label: "Index Size", value: ByteCountFormatter.string(fromByteCount: table.indexSpaceBytes, countStyle: .binary)),
            .init(label: "Unused Space", value: ByteCountFormatter.string(fromByteCount: table.unusedSpaceBytes, countStyle: .binary)),
            .init(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: table.totalSpaceBytes, countStyle: .binary)),
            .init(label: "Stats Updated", value: table.lastStatsUpdate?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}")
        ]

        let content = DatabaseObjectInspectorContent(
            title: table.tableName,
            subtitle: "\(table.tableType) \u{2022} \(table.schemaName)",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: table.tableName, appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }

    func openStructure(for table: SQLServerTableStat) {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }

        let object = SchemaObjectInfo(
            name: table.tableName,
            schema: table.schemaName,
            type: .table
        )

        environmentState.openStructureTab(
            for: session,
            object: object,
            databaseName: viewModel.selectedDatabase
        )
    }

    func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
