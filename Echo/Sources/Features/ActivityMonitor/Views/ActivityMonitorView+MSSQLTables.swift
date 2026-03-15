import SwiftUI
import SQLServerKit

struct MSSQLProcessesTable: View {
    let processes: [SQLServerProcessInfo]
    @Binding var sortOrder: [KeyPathComparator<SQLServerProcessInfo>]
    let onPopout: (String) -> Void
    let onKill: (Int) -> Void

    private var sortedProcesses: [SQLServerProcessInfo] {
        processes.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedProcesses, sortOrder: $sortOrder) {
            TableColumn("ID", value: \.sessionId) { Text("\($0.sessionId)") }.width(min: 40, max: 60)
            TableColumn("User") {
                Text($0.loginName ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(($0.loginName ?? "").isEmpty ? ColorTokens.Text.secondary : ColorTokens.Text.primary)
            }.width(min: 100)
            TableColumn("Status") { StatusBadge(text: $0.sessionStatus ?? "", isSystem: ($0.loginName ?? "").isEmpty) }.width(80)
            TableColumn("Command") {
                if let sql = $0.request?.sqlText, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                } else {
                    Text($0.request?.command ?? "")
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            TableColumn("CPU") { Text("\($0.sessionCpuTimeMs ?? 0)ms").font(TypographyTokens.detail) }.width(70)
            TableColumn("Memory") { Text("\($0.memoryUsageKB ?? 0) KB").font(TypographyTokens.detail) }.width(80)
        }
        .contextMenu(forSelectionType: SQLServerProcessInfo.ID.self) { selection in
            if let id = selection.first, let process = processes.first(where: { $0.id == id }) {
                Button("Details") {
                    if let sql = process.request?.sqlText { onPopout(sql) }
                }
                .disabled(process.request?.sqlText == nil)

                Divider()

                Button("Kill Process", role: .destructive) {
                    onKill(id)
                }
            }
        }
    }
}

struct MSSQLWaitsTable: View {
    let waits: [SQLServerWaitStatDelta]
    @Binding var sortOrder: [KeyPathComparator<SQLServerWaitStatDelta>]

    private var sortedWaits: [SQLServerWaitStatDelta] {
        waits.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedWaits, sortOrder: $sortOrder) {
            TableColumn("Wait Type", value: \.waitType) { Text($0.waitType).font(TypographyTokens.detail) }
            TableColumn("Time", value: \.waitTimeMsDelta) { Text("\($0.waitTimeMsDelta)ms").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning) }.width(70)
            TableColumn("Tasks", value: \.waitingTasksCountDelta) { Text("\($0.waitingTasksCountDelta)").font(TypographyTokens.detail) }.width(60)
        }
    }
}

struct MSSQLFileIOTable: View {
    let io: [SQLServerFileIOStatDelta]
    @Binding var sortOrder: [KeyPathComparator<SQLServerFileIOStatDelta>]

    private var sortedIO: [SQLServerFileIOStatDelta] {
        io.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedIO, sortOrder: $sortOrder) {
            TableColumn("DB", value: \.databaseId) { Text("\($0.databaseId)").font(TypographyTokens.detail) }.width(40)
            TableColumn("Read", value: \.bytesReadDelta) { Text("\($0.bytesReadDelta) b").font(TypographyTokens.detail) }
            TableColumn("Write", value: \.bytesWrittenDelta) { Text("\($0.bytesWrittenDelta) b").font(TypographyTokens.detail) }
            TableColumn("Stall", value: \.ioStallReadMsDelta) { Text("\($0.ioStallReadMsDelta)ms").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error) }.width(60)
        }
    }
}

struct MSSQLExpensiveQueriesTable: View {
    let queries: [SQLServerExpensiveQuery]
    @Binding var sortOrder: [KeyPathComparator<SQLServerExpensiveQuery>]
    let onPopout: (String) -> Void

    private var sortedQueries: [SQLServerExpensiveQuery] {
        queries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedQueries, sortOrder: $sortOrder) {
            TableColumn("Query") { SQLQueryCell(sql: $0.sqlText ?? "", onPopout: onPopout) }
            TableColumn("Count", value: \.executionCount) { Text("\($0.executionCount)").font(TypographyTokens.detail) }.width(60)
            TableColumn("Worker Time", value: \.totalWorkerTime) { Text("\($0.totalWorkerTime)ms").font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent) }.width(90)
        }
    }
}
