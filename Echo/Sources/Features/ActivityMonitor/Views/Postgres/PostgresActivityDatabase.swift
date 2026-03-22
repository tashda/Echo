import SwiftUI
import PostgresWire

struct PostgresActivityDatabase: View {
    let stats: [PostgresDatabaseStatDelta]
    @Binding var sortOrder: [KeyPathComparator<PostgresDatabaseStatDelta>]
    @Binding var selection: Set<PostgresDatabaseStatDelta.ID>
    var onDoubleClick: (() -> Void)?

    private var sortedStats: [PostgresDatabaseStatDelta] {
        stats.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Database") {
                Text($0.datname)
                    .font(TypographyTokens.Table.name)
            }.width(min: 100, ideal: 140)

            TableColumn("Cache Hit") {
                CacheHitCell(ratio: $0.cacheHitRatio)
            }.width(min: 70, ideal: 90)

            TableColumn("TX", value: \.xact_commit_delta) {
                Text("\($0.xact_commit_delta)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Status.success)
            }.width(60)

            TableColumn("Rollback", value: \.xact_rollback_delta) {
                Text("\($0.xact_rollback_delta)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.xact_rollback_delta > 0 ? ColorTokens.Status.error : ColorTokens.Text.quaternary)
            }.width(70)

            TableColumn("Inserted", value: \.tup_inserted_delta) {
                Text("\($0.tup_inserted_delta)").font(TypographyTokens.Table.numeric)
            }.width(70)

            TableColumn("Updated", value: \.tup_updated_delta) {
                Text("\($0.tup_updated_delta)").font(TypographyTokens.Table.numeric)
            }.width(70)

            TableColumn("Deleted", value: \.tup_deleted_delta) {
                Text("\($0.tup_deleted_delta)").font(TypographyTokens.Table.numeric)
            }.width(70)

            TableColumn("Temp Files", value: \.temp_files_delta) {
                Text("\($0.temp_files_delta)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.temp_files_delta > 0 ? ColorTokens.Status.warning : ColorTokens.Text.quaternary)
            }.width(70)

            TableColumn("Deadlocks", value: \.deadlocks_delta) {
                Text("\($0.deadlocks_delta)")
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle($0.deadlocks_delta > 0 ? ColorTokens.Status.error : ColorTokens.Text.quaternary)
            }.width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .tableColumnAutoResize()
        .contextMenu(forSelectionType: PostgresDatabaseStatDelta.ID.self) { _ in
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }
}

private struct CacheHitCell: View {
    let ratio: Double?

    var body: some View {
        if let ratio {
            Text(String(format: "%.1f%%", ratio))
                .font(TypographyTokens.Table.percentage)
                .foregroundStyle(ratio >= 99 ? ColorTokens.Status.success : ratio >= 95 ? ColorTokens.Status.warning : ColorTokens.Status.error)
        } else {
            Text("\u{2014}")
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }
}
