import SwiftUI
import PostgresWire

struct PostgresMaintenanceIndexes: View {
    var viewModel: MaintenanceViewModel
    @Binding var sortOrder: [KeyPathComparator<PostgresIndexStat>]
    @Binding var selection: Set<PostgresIndexStat.ID>
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    @State private var selectedDefinition: String?

    var body: some View {
        Group {
            if viewModel.isLoadingIndexes && viewModel.indexStats.isEmpty {
                loadingView
            } else if viewModel.indexStats.isEmpty {
                ContentUnavailableView {
                    Label("No Index Statistics", systemImage: "list.bullet.indent")
                } description: {
                    Text("No user indexes found in the selected database.")
                }
            } else {
                indexTable
            }
        }
        .sheet(item: Binding(
            get: { selectedDefinition.map { DefinitionContext(sql: $0) } },
            set: { selectedDefinition = $0?.sql }
        )) { context in
            definitionSheet(sql: context.sql)
        }
    }

    private var loadingView: some View {
        TabInitializingPlaceholder(
            icon: "list.bullet.indent",
            title: "Loading Indexes",
            subtitle: "Fetching index statistics\u{2026}"
        )
    }

    private var indexTable: some View {
        Table(viewModel.indexStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Kind") { index in
                Text(index.kindLabel)
                    .font(TypographyTokens.Table.kindBadge)
                    .foregroundStyle(kindColor(for: index))
            }.width(min: 28, ideal: 32)

            TableColumn("Index") { index in
                HStack(spacing: SpacingTokens.xxs) {
                    Text(index.indexName)
                        .font(TypographyTokens.Table.name)
                        .lineLimit(1)
                    if !index.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Status.error)
                            .font(TypographyTokens.compact)
                            .help("Invalid index \u{2014} needs REINDEX")
                    }
                }
            }.width(min: 140, ideal: 200)

            TableColumn("Table") { index in
                Text("\(index.schemaName).\(index.tableName)")
                    .font(TypographyTokens.Table.secondaryName)
                    .lineLimit(1)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 120, ideal: 180)

            TableColumn("Type") { index in
                Text(index.indexType)
                    .font(TypographyTokens.Table.category)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(min: 50, ideal: 60)

            TableColumn("Size", value: \.indexSizeBytes) { index in
                Text(formatBytes(index.indexSizeBytes))
                    .font(TypographyTokens.Table.numeric)
            }.width(min: 60, ideal: 70)

            TableColumn("Ratio", value: \.indexToTablePct) { index in
                Text(String(format: "%.0f%%", index.indexToTablePct))
                    .font(TypographyTokens.Table.percentage)
                    .foregroundStyle(index.isBloated ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
                    .help("Index size relative to table size")
            }.width(min: 50, ideal: 55)

            TableColumn("Scans", value: \.idxScan) { index in
                Text("\(index.idxScan)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(index.isUnused ? ColorTokens.Status.warning : ColorTokens.Text.primary)
            }.width(min: 60, ideal: 70)

            TableColumn("Rows Read", value: \.idxTupRead) { index in
                Text(formatCount(index.idxTupRead))
                    .font(TypographyTokens.Table.numeric)
            }.width(min: 70, ideal: 80)

            TableColumn("Status") { index in
                indexStatusLabel(for: index)
            }.width(min: 80, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.indexStats.sort(using: newOrder)
        }
        .onChange(of: viewModel.isLoadingIndexes) { old, new in
            if old && !new {
                viewModel.indexStats.sort(using: sortOrder)
            }
        }
        .contextMenu(forSelectionType: PostgresIndexStat.ID.self) { ids in
            let indexes = ids.compactMap { id in viewModel.indexStats.first(where: { $0.id == id }) }
            if !indexes.isEmpty {
                indexContextMenu(for: indexes)
            }
        } primaryAction: { _ in
            appState.showInfoSidebar.toggle()
        }
    }

    private func kindColor(for index: PostgresIndexStat) -> Color {
        if index.isPrimary { return Color.orange }
        if index.isUnique { return ColorTokens.Status.info }
        return ColorTokens.Text.tertiary
    }

    private func indexStatusLabel(for index: PostgresIndexStat) -> some View {
        let isUnused = index.isUnused
        let isBloated = index.isBloated
        
        return HStack(spacing: SpacingTokens.xxs) {
            if !index.isValid {
                Text("Invalid").foregroundStyle(ColorTokens.Status.error)
            } else if isUnused {
                Text("Unused").foregroundStyle(ColorTokens.Status.warning)
            } else if isBloated {
                Text("Bloated").foregroundStyle(ColorTokens.Status.warning)
            } else {
                Text("Healthy").foregroundStyle(ColorTokens.Status.success)
            }
        }
        .font(TypographyTokens.Table.status)
    }

    @ViewBuilder
    private func indexContextMenu(for indexes: [PostgresIndexStat]) -> some View {
        let countSuffix = indexes.count > 1 ? " (\(indexes.count))" : ""

        if indexes.count == 1, let index = indexes.first {
            Button {
                selectedDefinition = index.definition
            } label: {
                Label("View Definition", systemImage: "doc.text")
            }

            Divider()
        }

        Button {
            runOnAll(indexes: indexes, operation: "Reindex") { index in
                try await viewModel.reindex(index)
                return .reindexCompleted(schema: index.schemaName, table: index.indexName)
            }
        } label: {
            Label("REINDEX\(countSuffix)", systemImage: "arrow.clockwise")
        }

        Button(role: .destructive) {
            runOnAll(indexes: indexes, operation: "Drop Index") { index in
                try await viewModel.dropIndex(index)
                return .indexDropped(name: index.indexName)
            }
        } label: {
            Label("DROP INDEX\(countSuffix)", systemImage: "trash")
        }
    }

    private func runOnAll(indexes: [PostgresIndexStat], operation: String, action: @escaping (PostgresIndexStat) async throws -> NotificationEvent) {
        Task {
            for index in indexes {
                do {
                    let event = try await action(index)
                    environmentState.notificationEngine?.post(event)
                } catch {
                    environmentState.notificationEngine?.post(.maintenanceFailed(operation: "\(operation) on \(index.indexName)", reason: error.localizedDescription))
                }
            }
        }
    }

    private func definitionSheet(sql: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Index Definition")
                    .font(TypographyTokens.headline)
                Spacer()
                Button("Done") {
                    selectedDefinition = nil
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(ColorTokens.Background.secondary)

            Divider()

            ScrollView {
                Text(sql)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    private func formatCount(_ count: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

private struct DefinitionContext: Identifiable {
    let id = UUID()
    let sql: String
}
