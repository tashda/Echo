import SwiftUI
import PostgresKit

struct TableStructurePartitionsView: View {
    @Bindable var viewModel: TableStructureEditorViewModel

    @State private var partitionInfo: PostgresPartitionInfo?
    @State private var partitions: [PostgresPartitionDetail] = []
    @State private var isLoading = false
    @State private var pendingDetach: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading partitions\u{2026}")
                    .controlSize(.small)
                Spacer()
            } else if let info = partitionInfo {
                partitionHeader(info: info)
                Divider()
                partitionTable
            } else {
                ContentUnavailableView {
                    Label("Not Partitioned", systemImage: "square.split.2x2")
                } description: {
                    Text("This table does not use partitioning.")
                }
            }
        }
        .task { await loadPartitions() }
        .dropConfirmationAlert(objectType: "Partition", objectName: $pendingDetach) { name in
            Task { await detachPartition(name) }
        }
    }

    private func partitionHeader(info: PostgresPartitionInfo) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Label(info.strategy.rawValue, systemImage: "square.split.2x2")
                .font(TypographyTokens.prominent.weight(.semibold))
            Text("Key: \(info.partitionKey)")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()
            Text("\(info.partitionCount) partitions")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private var partitionTable: some View {
        Table(partitions) {
            TableColumn("Partition") { p in
                Text(p.partitionName)
                    .font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Schema") { p in
                Text(p.schemaName)
                    .font(TypographyTokens.Table.secondaryName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Bound") { p in
                Text(p.boundSpec)
                    .font(TypographyTokens.Table.sql)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 150, ideal: 280)

            TableColumn("Rows") { p in
                Text(EchoFormatters.compactNumber(p.estimatedRows))
                    .font(TypographyTokens.Table.numeric)
            }
            .width(60)

            TableColumn("Size") { p in
                Text(EchoFormatters.bytes(Int(p.sizeBytes)))
                    .font(TypographyTokens.Table.numeric)
            }
            .width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: PostgresPartitionDetail.ID.self) { selection in
            if let id = selection.first, let part = partitions.first(where: { $0.id == id }) {
                Button(role: .destructive) { pendingDetach = part.partitionName } label: {
                    Label("Detach Partition", systemImage: "minus.square")
                }
            }
        } primaryAction: { _ in }
    }

    private func loadPartitions() async {
        guard let pg = viewModel.session as? PostgresSession else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            partitionInfo = try await pg.client.introspection.fetchPartitionInfo(schema: viewModel.schemaName, table: viewModel.tableName)
            if partitionInfo != nil {
                partitions = try await pg.client.introspection.listPartitions(schema: viewModel.schemaName, table: viewModel.tableName)
            }
        } catch {
            // Not partitioned — leave partitionInfo nil
        }
        viewModel.partitionsAvailable = partitionInfo != nil
    }

    private func detachPartition(_ name: String) async {
        guard let pg = viewModel.session as? PostgresSession else { return }
        let handle = viewModel.activityEngine?.begin("Detaching partition \(name)", connectionSessionID: viewModel.connectionSessionID)
        do {
            try await pg.client.admin.detachPartition(table: name, schema: viewModel.schemaName, parentTable: viewModel.tableName, parentSchema: viewModel.schemaName)
            handle?.succeed()
            await loadPartitions()
        } catch {
            handle?.fail(error.localizedDescription)
            viewModel.lastError = error.localizedDescription
        }
    }
}

extension PostgresPartitionDetail: @retroactive Identifiable {
    public var id: String { "\(schemaName).\(partitionName)" }
}
