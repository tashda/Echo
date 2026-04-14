import SwiftUI

struct MSSQLMaintenanceIndexesView: View {
    @Bindable var viewModel: MSSQLMaintenanceViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    
    @State private var sortOrder = [KeyPathComparator(\SQLServerIndexFragmentation.fragmentationPercent, order: .reverse)]
    @State private var selection: Set<SQLServerIndexFragmentation.ID> = []

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        VStack(spacing: 0) {
            Table(viewModel.fragmentedIndexes, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Kind") { index in
                    Text(index.isPrimaryKey ? "PK" : index.isUnique ? "UQ" : "IX")
                        .font(TypographyTokens.Table.kindBadge)
                        .foregroundStyle(index.isPrimaryKey ? .orange : index.isUnique ? .blue : ColorTokens.Text.tertiary)
                }
                .width(35)

                TableColumn("Index") { index in
                    Text(index.indexName)
                        .font(TypographyTokens.Table.name)
                }
                TableColumn("Table") { index in
                    Text(index.tableName)
                        .font(TypographyTokens.Table.name)
                }

                
                TableColumn("Type") { index in
                    Text(index.indexType.lowercased())
                        .font(TypographyTokens.Table.category)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(100)

                TableColumn("Size") { index in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(index.sizeKB * 1024), countStyle: .binary))
                        .font(TypographyTokens.Table.numeric)
                }
                .width(80)

                TableColumn("Ratio") { index in
                    Text(String(format: "%.0f%%", index.ratio))
                        .font(TypographyTokens.Table.percentage)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(50)

                TableColumn("Scans") { index in
                    Text("\(index.totalScans)")
                        .font(TypographyTokens.Table.numeric)
                        .foregroundStyle(index.totalScans == 0 ? .orange : ColorTokens.Text.primary)
                }
                .width(60)

                TableColumn("Stats Updated") { index in
                    if let date = index.lastStatsUpdate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(TypographyTokens.Table.date)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    } else {
                        Text("—")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                .width(130)

                TableColumn("Status") { index in
                    statusBadge(for: index)
                }
                .width(100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: SQLServerIndexFragmentation.ID.self) { ids in
                if let id = ids.first, let index = viewModel.fragmentedIndexes.first(where: { $0.id == id }) {
                    Button {
                        Task {
                            await viewModel.rebuildIndex(index)
                        }
                    } label: {
                        Label("Rebuild Index", systemImage: "hammer")
                    }
                    .disabled(!(session?.permissions?.canManageServerState ?? true))

                    Button {
                        Task {
                            await viewModel.reorganizeIndex(index)
                        }
                    } label: {
                        Label("Reorganize Index", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!(session?.permissions?.canManageServerState ?? true))

                    Button {
                        Task {
                            await viewModel.updateStatistics(index)
                        }
                    } label: {
                        Label("Update Statistics", systemImage: "chart.bar")
                    }
                    .disabled(!(session?.permissions?.canManageServerState ?? true))
                    
                    Divider()
                    
                    Button {
                        openStructure(for: index)
                    } label: {
                        Label("View Structure", systemImage: "table")
                    }
                }
            } primaryAction: { _ in
                if let id = selection.first, let index = viewModel.fragmentedIndexes.first(where: { $0.id == id }) {
                    pushIndexInspector(index, toggle: true)
                }
            }
            .onChange(of: selection) { _, newSelection in
                if let id = newSelection.first, let index = viewModel.fragmentedIndexes.first(where: { $0.id == id }) {
                    pushIndexInspector(index, toggle: false)
                }
            }
            .onChange(of: sortOrder) { _, newOrder in
                viewModel.fragmentedIndexes.sort(using: newOrder)
            }
            .onChange(of: viewModel.isRefreshingIndexes) { old, new in
                if old && !new {
                    viewModel.fragmentedIndexes.sort(using: sortOrder)
                }
            }
        }
    }

    private func statusBadge(for index: SQLServerIndexFragmentation) -> some View {
        let label = index.status
        let color = if label == "Healthy" {
            ColorTokens.Status.success
        } else if label == "Unused" {
            Color.orange
        } else {
            ColorTokens.Status.error
        }

        return Text(label)
            .font(TypographyTokens.Table.status)
            .foregroundStyle(color)
    }

    private func pushIndexInspector(_ index: SQLServerIndexFragmentation, toggle: Bool) {
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

    private func openStructure(for index: SQLServerIndexFragmentation) {
        guard let session = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID) else { return }
        
        let object = SchemaObjectInfo(
            name: index.tableName,
            schema: index.schemaName,
            type: .table
        )
        
        environmentState.openStructureTab(
            for: session,
            object: object,
            focus: .indexes,
            databaseName: viewModel.selectedDatabase
        )
    }
}
