import SwiftUI
import SQLServerKit

extension MaintenanceSheet {

    var actionsPane: some View {
        Form {
            Section("Database Operations") {
                Button("Check Integrity (CHECKDB)") {
                    Task { await runDatabaseOp(.checkDB) }
                }
                .disabled(isRunning)

                Button("Shrink Database") {
                    Task { await runDatabaseOp(.shrink) }
                }
                .disabled(isRunning)
            }

            Section("Table Operations") {
                if isLoadingTables {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    tablePicker
                }

                Button("Rebuild Indexes") {
                    Task { await runTableOp(.rebuildIndexes) }
                }
                .disabled(isRunning || selectedTable.isEmpty)

                Button("Reorganize Indexes") {
                    Task { await runTableOp(.reorganizeIndexes) }
                }
                .disabled(isRunning || selectedTable.isEmpty)

                Button("Update Statistics") {
                    Task { await runTableOp(.updateStats) }
                }
                .disabled(isRunning || selectedTable.isEmpty)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    var tablePicker: some View {
        let uniqueSchemas = Array(Set(schemas.map(\.schema))).sorted()
        Picker("Schema", selection: $selectedSchema) {
            ForEach(uniqueSchemas, id: \.self) { schema in
                Text(schema).tag(schema)
            }
        }
        .onChange(of: selectedSchema) {
            let tablesInSchema = schemas.filter { $0.schema == selectedSchema }
            selectedTable = tablesInSchema.first?.table ?? ""
        }

        let tablesInSchema = schemas.filter { $0.schema == selectedSchema }
        Picker("Table", selection: $selectedTable) {
            ForEach(tablesInSchema) { pair in
                Text(pair.table).tag(pair.table)
            }
        }
    }

    var resultsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Results")
                .font(TypographyTokens.standard.weight(.semibold))
                .padding(SpacingTokens.sm)

            Divider()

            if results.isEmpty {
                VStack {
                    Spacer()
                    Text("Run a maintenance operation to see results here.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(results) { entry in
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.succeeded ? ColorTokens.Status.success : ColorTokens.Status.error)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.operation)
                                .font(TypographyTokens.standard.weight(.medium))
                            Text(entry.message)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .lineLimit(3)
                        }
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(.vertical, SpacingTokens.xxs)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Operations

    func runDatabaseOp(_ op: DatabaseOp) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        isRunning = true
        let result: SQLServerMaintenanceResult
        do {
            switch op {
            case .checkDB:
                result = try await mssql.maintenance.checkDatabase(database: databaseName)
            case .shrink:
                result = try await mssql.maintenance.shrinkDatabase(database: databaseName)
            }
        } catch {
            appendResult(
                operation: op == .checkDB ? "Check Database" : "Shrink Database",
                succeeded: false,
                message: error.localizedDescription
            )
            isRunning = false
            return
        }
        appendResult(operation: result.operation, succeeded: result.succeeded, message: result.messages.joined(separator: " "))
        isRunning = false
    }

    func runTableOp(_ op: TableOp) async {
        guard let mssql = session.session as? MSSQLSession else { return }
        guard !selectedTable.isEmpty else { return }
        isRunning = true
        let result: SQLServerMaintenanceResult
        do {
            switch op {
            case .rebuildIndexes:
                result = try await mssql.maintenance.rebuildIndexes(schema: selectedSchema, table: selectedTable)
            case .reorganizeIndexes:
                result = try await mssql.maintenance.reorganizeIndexes(schema: selectedSchema, table: selectedTable)
            case .updateStats:
                result = try await mssql.maintenance.updateStatistics(schema: selectedSchema, table: selectedTable)
            }
        } catch {
            let opName: String
            switch op {
            case .rebuildIndexes: opName = "Rebuild Indexes"
            case .reorganizeIndexes: opName = "Reorganize Indexes"
            case .updateStats: opName = "Update Statistics"
            }
            appendResult(operation: opName, succeeded: false, message: error.localizedDescription)
            isRunning = false
            return
        }
        appendResult(operation: result.operation, succeeded: result.succeeded, message: result.messages.joined(separator: " "))
        isRunning = false
    }
}
