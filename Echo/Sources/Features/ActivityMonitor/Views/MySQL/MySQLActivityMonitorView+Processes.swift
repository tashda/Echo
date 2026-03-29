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
                VStack(alignment: .leading, spacing: SpacingTokens.md) {
                    processTable(snap.processes)
                        .frame(minHeight: 240)

                    if let selectedProcess {
                        processDetails(selectedProcess)
                    }
                }
            }
        } else {
            ActivitySectionLoadingView(title: "Process List", subtitle: "Loading process list…")
        }
    }

    private var selectedProcess: MySQLProcessInfo? {
        guard let processID = selectedProcessIDs.first else { return nil }
        return mysqlSnapshot?.processes.first(where: { $0.id == processID })
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
                        selectedSQLContext = SQLPopoutContext(sql: query, title: "Query Details")
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
                selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details")
            }
        }
    }

    private func processDetails(_ process: MySQLProcessInfo) -> some View {
        SectionContainer(
            title: "Selected Process",
            icon: "info.circle",
            info: "Inspect the selected MySQL thread and terminate either the current statement or the whole connection."
        ) {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                Group {
                    processDetailRow(title: "Thread ID", value: "\(process.id)")
                    processDetailRow(title: "User", value: process.user)
                    processDetailRow(title: "Host", value: process.host)
                    processDetailRow(title: "Database", value: process.database ?? "Not Selected")
                    processDetailRow(title: "Command", value: process.command)
                    processDetailRow(title: "State", value: process.state ?? "Idle")
                    processDetailRow(title: "Duration", value: "\(process.time) s")
                    processDetailRow(title: "Thread Type", value: process.threadTypeDescription)
                }

                if let sql = process.info, !sql.isEmpty {
                    VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                        HStack {
                            Text("Current Statement")
                                .font(TypographyTokens.formLabel)
                            Spacer()
                            Button("Open in Window") {
                                selectedSQLContext = SQLPopoutContext(sql: sql, title: "Query Details")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text(sql)
                            .font(TypographyTokens.monospaced)
                            .textSelection(.enabled)
                            .padding(SpacingTokens.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTokens.Background.secondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                HStack(spacing: SpacingTokens.sm) {
                    Button("Kill Query") {
                        Task { try? await viewModel.killMySQLQuery(id: process.id) }
                    }
                    .buttonStyle(.bordered)

                    Button("Kill Connection") {
                        Task { try? await viewModel.killSession(id: process.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(SpacingTokens.md)
        }
    }

    private func processDetailRow(title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .textSelection(.enabled)
        }
    }
}

private extension MySQLProcessInfo {
    var threadTypeDescription: String {
        if user == "system user" || command.caseInsensitiveCompare("Daemon") == .orderedSame {
            return "Background"
        }
        return "Foreground"
    }
}
