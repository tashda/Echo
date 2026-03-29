import SwiftUI
import PostgresKit

struct TableStructureStatisticsView: View {
    @Bindable var viewModel: TableStructureEditorViewModel

    @State private var details: PostgresTableDetails?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading statistics\u{2026}")
                    .controlSize(.small)
                Spacer()
            } else if let details {
                statsForm(details: details)
            } else {
                ContentUnavailableView {
                    Label("No Statistics", systemImage: "chart.bar")
                } description: {
                    Text("Statistics are not available for this table.")
                }
            }
        }
        .task { await loadStats() }
    }

    private func statsForm(details: PostgresTableDetails) -> some View {
        Form {
            Section("Size") {
                PropertyRow(title: "Total Size") {
                    Text(EchoFormatters.bytes(Int(details.totalSizeBytes)))
                        .font(TypographyTokens.Table.numeric)
                }
                PropertyRow(title: "Table Size") {
                    Text(EchoFormatters.bytes(Int(details.tableSizeBytes)))
                        .font(TypographyTokens.Table.numeric)
                }
                PropertyRow(title: "Indexes Size") {
                    Text(EchoFormatters.bytes(Int(details.indexesSizeBytes)))
                        .font(TypographyTokens.Table.numeric)
                }
            }

            Section("Rows") {
                PropertyRow(title: "Estimated Row Count") {
                    Text(EchoFormatters.compactNumber(details.estimatedRowCount))
                        .font(TypographyTokens.Table.numeric)
                }
            }

            Section("Properties") {
                PropertyRow(title: "Owner") {
                    Text(details.owner)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Tablespace") {
                    Text(details.tablespace ?? "pg_default")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                PropertyRow(title: "Has Indexes") {
                    Image(systemName: details.hasIndexes ? "checkmark" : "minus")
                        .foregroundStyle(details.hasIndexes ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
                }
                PropertyRow(title: "Has Triggers") {
                    Image(systemName: details.hasTriggers ? "checkmark" : "minus")
                        .foregroundStyle(details.hasTriggers ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
                }
                PropertyRow(title: "Row Level Security") {
                    Image(systemName: details.rowSecurity ? "checkmark" : "minus")
                        .foregroundStyle(details.rowSecurity ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                }
                PropertyRow(title: "Is Partitioned") {
                    Image(systemName: details.isPartitioned ? "checkmark" : "minus")
                        .foregroundStyle(details.isPartitioned ? ColorTokens.Status.info : ColorTokens.Text.tertiary)
                }
            }

            if let options = details.options, !options.isEmpty {
                Section("Storage Options") {
                    ForEach(options, id: \.self) { option in
                        let parts = option.split(separator: "=", maxSplits: 1)
                        if parts.count == 2 {
                            PropertyRow(title: String(parts[0])) {
                                Text(String(parts[1]))
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }
                }
            }

            if let desc = details.description, !desc.isEmpty {
                Section("Description") {
                    Text(desc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func loadStats() async {
        guard let pg = viewModel.session as? PostgresSession else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            details = try await pg.client.introspection.fetchTableDetails(schema: viewModel.schemaName, table: viewModel.tableName)
        } catch {
            viewModel.lastError = error.localizedDescription
        }
    }
}
