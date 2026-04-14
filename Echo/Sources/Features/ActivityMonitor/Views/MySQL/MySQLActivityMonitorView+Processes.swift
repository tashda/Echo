import SwiftUI

extension MySQLActivityMonitorView {
    @ViewBuilder
    var processListContent: some View {
        if let snap = mysqlSnapshot {
            if snap.processes.isEmpty {
                ContentUnavailableView {
                    Label("No Active Processes", systemImage: "person.3")
                } description: {
                    Text("No active connections found.")
                }
            } else {
                processTable(snap.processes)
            }
        } else {
            ActivitySectionLoadingView(title: "Process List", subtitle: "Loading process list\u{2026}")
        }
    }

    private func processTable(_ processes: [MySQLProcessInfo]) -> some View {
        Table(processes, selection: $selectedProcessIDs) {
            TableColumn("ID") { process in
                Text("\(process.id)")
                    .font(TypographyTokens.Table.sql)
            }
            .width(min: 40, ideal: 60)

            TableColumn("User") { process in
                Text(process.user)
                    .font(TypographyTokens.detail)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Host") { process in
                Text(process.host)
                    .font(TypographyTokens.detail)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Database") { process in
                Text(process.database ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(process.database != nil ? ColorTokens.Text.primary : ColorTokens.Text.placeholder)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Command") { process in
                Text(process.command)
                    .font(TypographyTokens.detail)
            }
            .width(min: 60, ideal: 90)

            TableColumn("Time (s)") { process in
                Text("\(process.time)")
                    .font(TypographyTokens.Table.sql)
                    .foregroundStyle(process.time > 30 ? ColorTokens.Status.warning : ColorTokens.Text.primary)
            }
            .width(min: 50, ideal: 60)

            TableColumn("State") { process in
                Text(process.state ?? "")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Query") { process in
                if let sql = process.info, !sql.isEmpty {
                    SQLQueryCell(sql: sql) { query in
                        selectedSQLContext = SQLPopoutContext(sql: query, title: "Query Details", dialect: .mysql)
                    }
                } else {
                    Text("")
                }
            }
            .width(min: 120, ideal: 320)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: MySQLProcessInfo.ID.self) { selection in
            if let processID = selection.first {
                Button("Kill Query \(processID)") {
                    Task { try? await viewModel.killMySQLQuery(id: processID) }
                }
                Button("Kill Connection \(processID)") {
                    Task { try? await viewModel.killSession(id: processID) }
                }
            }
        } primaryAction: { selection in
            if let processID = selection.first,
               let process = processes.first(where: { $0.id == processID }),
               let sql = process.info,
               !sql.isEmpty {
                selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details", dialect: .mysql)
            }
        }
    }
}
