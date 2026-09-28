import Foundation
import SQLServerKit

extension MSSQLMaintenanceIndexesView {
    func pushIndexInspector(_ index: SQLServerIndexFragmentation, toggle: Bool) {
        let kindLabel = index.isPrimaryKey ? "Primary Key" : index.isUnique ? "Unique" : "Index"
        let fields: [DatabaseObjectInspectorContent.Field] = [
            .init(label: "Index", value: index.indexName),
            .init(label: "Table", value: "\(index.schemaName).\(index.tableName)"),
            .init(label: "Kind", value: kindLabel),
            .init(label: "Type", value: index.indexType),
            .init(label: "Fragmentation", value: String(format: "%.1f%%", index.fragmentationPercent)),
            .init(label: "Index Size", value: ByteCountFormatter.string(fromByteCount: Int64(index.sizeKB * 1024), countStyle: .binary)),
            .init(label: "Table Size", value: ByteCountFormatter.string(fromByteCount: Int64(index.tableSizeKB * 1024), countStyle: .binary)),
            .init(label: "Index/Table Ratio", value: String(format: "%.0f%%", index.ratio)),
            .init(label: "Total Scans", value: "\(index.totalScans)"),
            .init(label: "Total Updates", value: "\(index.totalUpdates)"),
            .init(label: "Stats Updated", value: index.lastStatsUpdate?.formatted(date: .abbreviated, time: .shortened) ?? "—")
        ]
        let content = DatabaseObjectInspectorContent(
            title: index.indexName,
            subtitle: "\(kindLabel) \u{2022} \(index.indexType)",
            fields: fields
        )

        if toggle {
            environmentState.toggleDataInspector(content: .databaseObject(content), title: index.indexName, appState: appState)
        } else {
            environmentState.dataInspectorContent = .databaseObject(content)
        }
    }

    func openStructure(for index: SQLServerIndexFragmentation) {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }
        let object = SchemaObjectInfo(name: index.tableName, schema: index.schemaName, type: .table)
        environmentState.openStructureTab(
            for: session,
            object: object,
            focus: .indexes,
            databaseName: viewModel.selectedDatabase
        )
    }
}
