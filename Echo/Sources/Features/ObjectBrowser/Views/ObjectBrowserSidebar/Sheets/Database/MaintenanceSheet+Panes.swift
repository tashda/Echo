import SwiftUI
import SQLServerKit

extension MaintenanceSheet {

    var actionsPane: some View {
        Form {
            Section("Database Operations") {
                PropertyRow(title: "Check Integrity") {
                    Button("Run CHECKDB") {
                        Task { await runDatabaseOp(.checkDB) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)
                }

                PropertyRow(title: "Shrink Database") {
                    Button("Run Shrink") {
                        Task { await runDatabaseOp(.shrink) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)
                }
            }

            Section("Table Operations") {
                if isLoadingTables {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                } else {
                    tablePicker
                }

                PropertyRow(title: "Index Maintenance") {
                    HStack(spacing: SpacingTokens.xs) {
                        Button("Rebuild") {
                            Task { await runTableOp(.rebuildIndexes) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunning || selectedTable.isEmpty)

                        Button("Reorganize") {
                            Task { await runTableOp(.reorganizeIndexes) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRunning || selectedTable.isEmpty)
                    }
                }

                PropertyRow(title: "Statistics") {
                    Button("Update Statistics") {
                        Task { await runTableOp(.updateStats) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning || selectedTable.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    var tablePicker: some View {
        let uniqueSchemas = Array(Set(schemas.map(\.schema))).sorted()
        PropertyRow(title: "Schema") {
            Picker("", selection: $selectedSchema) {
                ForEach(uniqueSchemas, id: \.self) { schema in
                    Text(schema).tag(schema)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedSchema) {
                let tablesInSchema = schemas.filter { $0.schema == selectedSchema }
                selectedTable = tablesInSchema.first?.table ?? ""
            }
        }

        let tablesInSchema = schemas.filter { $0.schema == selectedSchema }
        PropertyRow(title: "Table") {
            Picker("", selection: $selectedTable) {
                ForEach(tablesInSchema) { pair in
                    Text(pair.table).tag(pair.table)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    var resultsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Results")
                .font(TypographyTokens.formSectionTitle)
                .padding(SpacingTokens.md)

            Divider()

            if results.isEmpty {
                VStack {
                    Spacer()
                    Text("Run a maintenance operation to see results here.")
                        .font(TypographyTokens.formDescription)
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
                                .font(TypographyTokens.formValue.weight(.medium))
                            Text(entry.message)
                                .font(TypographyTokens.formDescription)
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .lineLimit(3)
                        }
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(TypographyTokens.formDescription)
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
        let result: DatabaseMaintenanceResult
        do {
            let mssqlResult: SQLServerMaintenanceResult
            switch op {
            case .checkDB:
                mssqlResult = try await mssql.maintenance.checkDatabase(database: databaseName)
            case .shrink:
                mssqlResult = try await mssql.maintenance.shrinkDatabase(database: databaseName)
            }
            result = DatabaseMaintenanceResult(operation: mssqlResult.operation, messages: mssqlResult.messages, succeeded: mssqlResult.succeeded)
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
        let result: DatabaseMaintenanceResult
        do {
            let mssqlResult: SQLServerMaintenanceResult
            switch op {
            case .rebuildIndexes:
                mssqlResult = try await mssql.maintenance.rebuildIndexes(schema: selectedSchema, table: selectedTable)
            case .reorganizeIndexes:
                mssqlResult = try await mssql.maintenance.reorganizeIndexes(schema: selectedSchema, table: selectedTable)
            case .updateStats:
                mssqlResult = try await mssql.maintenance.updateStatistics(schema: selectedSchema, table: selectedTable)
            }
            result = DatabaseMaintenanceResult(operation: mssqlResult.operation, messages: mssqlResult.messages, succeeded: mssqlResult.succeeded)
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
