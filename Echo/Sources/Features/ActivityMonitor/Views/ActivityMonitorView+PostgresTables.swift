import SwiftUI
import PostgresWire

struct PostgresProcessesTable: View {
    let processes: [PostgresProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<PostgresProcessInfo>]
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void

    private var sortedProcesses: [PostgresProcessInfo] {
        processes.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedProcesses, sortOrder: $sortOrder) {
            TableColumn("PID", value: \.pid) { Text("\($0.pid)") }.width(min: 50, max: 70)
            TableColumn("DB") { Text($0.databaseName ?? "").font(TypographyTokens.detail) }.width(100)
            TableColumn("State") { StatusBadge(text: $0.state ?? "", isSystem: ($0.userName ?? "").isEmpty) }.width(90)
            TableColumn("Query") {
                if let sql = $0.query, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                }
            }
        }
        .contextMenu(forSelectionType: PostgresProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button("Details") {
                    if let sql = process.query { onPopout(sql) }
                }
                .disabled(process.query == nil)

                Divider()

                Button("Kill Process", role: .destructive) {
                    onKill(Int(id))
                }
            }
        }
    }
}

struct PostgresWaitsTable: View {
    let waits: [PostgresWaitStatDelta]
    @Binding var sortOrder: [KeyPathComparator<PostgresWaitStatDelta>]

    private var sortedWaits: [PostgresWaitStatDelta] {
        waits.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedWaits, sortOrder: $sortOrder) {
            TableColumn("Type", value: \.waitEventType) { Text($0.waitEventType).font(TypographyTokens.detail) }
            TableColumn("Event", value: \.waitEvent) { Text($0.waitEvent).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning) }
            TableColumn("Δ Count", value: \.countDelta) { Text("\($0.countDelta)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent) }.width(70)
        }
    }
}

struct PostgresDBStatsTable: View {
    let stats: [PostgresDatabaseStatDelta]
    @Binding var sortOrder: [KeyPathComparator<PostgresDatabaseStatDelta>]

    private var sortedStats: [PostgresDatabaseStatDelta] {
        stats.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedStats, sortOrder: $sortOrder) {
            TableColumn("Database") { Text($0.datname).font(TypographyTokens.detail) }
            TableColumn("TX", value: \.xact_commit_delta) { Text("\($0.xact_commit_delta)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.success) }.width(60)
            TableColumn("Rollback", value: \.xact_rollback_delta) { Text("\($0.xact_rollback_delta)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error) }.width(70)
            TableColumn("IO Read", value: \.blks_read_delta) { Text("\($0.blks_read_delta)").font(TypographyTokens.detail) }.width(70)
        }
    }
}

struct PostgresExpensiveQueriesTable: View {
    let queries: [PostgresExpensiveQuery]
    @Binding var sortOrder: [KeyPathComparator<PostgresExpensiveQuery>]
    let onPopout: (String) -> Void

    private var sortedQueries: [PostgresExpensiveQuery] {
        queries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedQueries, sortOrder: $sortOrder) {
            TableColumn("Query") { SQLQueryCell(sql: $0.query, onPopout: onPopout) }
            TableColumn("Calls", value: \.calls) { Text("\($0.calls)").font(TypographyTokens.detail) }.width(60)
            TableColumn("Total Time", value: \.total_exec_time) { Text(String(format: "%.1fms", $0.total_exec_time)).font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent) }.width(90)
            TableColumn("Rows", value: \.rows) { Text("\($0.rows)").font(TypographyTokens.detail) }.width(70)
        }
    }
}
