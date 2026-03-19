import SwiftUI
import SQLServerKit

struct MSSQLActivityQueries: View {
    let queries: [SQLServerExpensiveQuery]
    @Binding var sortOrder: [KeyPathComparator<SQLServerExpensiveQuery>]
    @Binding var selection: Set<SQLServerExpensiveQuery.ID>
    let onPopout: (String) -> Void
    var onDoubleClick: (() -> Void)?

    private var sortedQueries: [SQLServerExpensiveQuery] {
        queries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedQueries, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Query", value: \.sortableQuery) {
                SQLQueryCell(sql: $0.sqlText ?? "", onPopout: onPopout)
            }

            TableColumn("Count", value: \.executionCount) {
                Text("\($0.executionCount)")
                    .font(TypographyTokens.Table.numeric)
            }.width(55)

            TableColumn("Worker Time", value: \.totalWorkerTime) {
                Text(formatMs($0.totalWorkerTime))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.accent)
            }.width(80)

            TableColumn("Elapsed", value: \.totalElapsedTime) {
                Text(formatMs($0.totalElapsedTime))
                    .font(TypographyTokens.Table.numeric)
            }.width(70)

            TableColumn("Reads", value: \.totalLogicalReads) {
                Text(formatCount($0.totalLogicalReads))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(60)

            TableColumn("Writes", value: \.totalLogicalWrites) {
                Text(formatCount($0.totalLogicalWrites))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(60)

            TableColumn("Avg Time", value: \.avgWorkerTime) { query in
                let avg = query.executionCount > 0 ? query.totalWorkerTime / Int64(query.executionCount) : 0
                Text(formatMs(avg))
                    .font(TypographyTokens.Table.numeric)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }.width(70)

            TableColumn("Last Run", value: \.sortableLastRun) { query in
                if let date = query.lastExecutionTime {
                    Text(date, style: .relative)
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }.width(min: 80, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: SQLServerExpensiveQuery.ID.self) { selection in
            if let id = selection.first, let query = queries.first(where: { $0.id == id }) {
                Button("Details") {
                    if let sql = query.sqlText { onPopout(sql) }
                }
                .disabled(query.sqlText == nil)
            }
        } primaryAction: { _ in
            onDoubleClick?()
        }
    }

    private func formatMs(_ microseconds: Int64) -> String {
        let ms = microseconds / 1000
        if ms >= 60_000 { return String(format: "%.1fs", Double(ms) / 1000) }
        if ms >= 1000 { return String(format: "%.1fs", Double(ms) / 1000) }
        return "\(ms)ms"
    }

    private func formatCount(_ count: Int64) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
