import SwiftUI
import PostgresKit

struct PostgresActivityIOStats: View {
    let connectionID: UUID
    @Environment(EnvironmentState.self) private var environmentState

    @State private var stats: [PostgresTableIOStats] = []
    @State private var sortOrder = [KeyPathComparator(\PostgresTableIOStats.heapBlksHit, order: .reverse)]
    @State private var selection: Set<String> = []
    @State private var isLoading = false
    @State private var schemaFilter = "public"

    private var sortedStats: [PostgresTableIOStats] {
        stats.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            table
        }
        .task { await loadStats() }
        .onChange(of: schemaFilter) { _, _ in Task { await loadStats() } }
    }

    private var filterBar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Schema:")
                .font(TypographyTokens.formLabel)
                .foregroundStyle(ColorTokens.Text.secondary)
            TextField("", text: $schemaFilter, prompt: Text("e.g. public"))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            }
            Button { Task { await loadStats() } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private var table: some View {
        Table(sortedStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Table", value: \.tableName) { stat in
                Text(stat.tableName).font(TypographyTokens.Table.name)
            }
            .width(min: 100, ideal: 180)

            TableColumn("Heap Read", value: \.heapBlksRead) { stat in
                Text(formatBlocks(stat.heapBlksRead)).font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Heap Hit", value: \.heapBlksHit) { stat in
                Text(formatBlocks(stat.heapBlksHit)).font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Idx Read", value: \.idxBlksRead) { stat in
                Text(formatBlocks(stat.idxBlksRead)).font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Idx Hit", value: \.idxBlksHit) { stat in
                Text(formatBlocks(stat.idxBlksHit)).font(TypographyTokens.Table.numeric)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Cache Hit %") { stat in
                let ratio = cacheHitRatio(stat)
                Text(ratio)
                    .font(TypographyTokens.Table.percentage)
                    .foregroundStyle(cacheHitColor(stat))
            }
            .width(min: 60, ideal: 80)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
    }

    private func cacheHitRatio(_ stat: PostgresTableIOStats) -> String {
        let total = stat.heapBlksRead + stat.heapBlksHit
        guard total > 0 else { return "\u{2014}" }
        let ratio = Double(stat.heapBlksHit) / Double(total) * 100
        return String(format: "%.1f%%", ratio)
    }

    private func cacheHitColor(_ stat: PostgresTableIOStats) -> Color {
        let total = stat.heapBlksRead + stat.heapBlksHit
        guard total > 0 else { return ColorTokens.Text.tertiary }
        let ratio = Double(stat.heapBlksHit) / Double(total) * 100
        if ratio >= 99 { return ColorTokens.Status.success }
        if ratio >= 90 { return ColorTokens.Text.secondary }
        return ColorTokens.Status.warning
    }

    private func formatBlocks(_ value: Int64) -> String {
        if value == 0 { return "0" }
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func loadStats() async {
        guard let session = environmentState.sessionGroup.sessionForConnection(connectionID),
              let pg = session.session as? PostgresSession else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            stats = try await pg.client.introspection.listTableIOStats(schema: schemaFilter)
        } catch {
            stats = []
        }
    }
}

extension PostgresTableIOStats: @retroactive Identifiable {
    public var id: String { "\(schemaName).\(tableName)" }
}
