import Foundation

extension MSSQLMaintenanceViewModel {

    func refreshTables() async {
        isRefreshingTables = true
        defer { isRefreshingTables = false }
        do {
            if let db = selectedDatabase {
                _ = try await session.sessionForDatabase(db)
            }
            tableStats = try await session.listTableStats()
        } catch {
            // Keep existing data if refresh fails
        }
    }

    func updateTableStats(_ table: SQLServerTableStat) async {
        let handle = activityEngine?.begin("Update stats \(table.tableName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: UPDATE STATISTICS [\(table.schemaName)].[\(table.tableName)]", category: "Update Statistics")
        do {
            let result = try await session.updateTableStatistics(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "Statistics updated for table \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Update Statistics")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to update statistics: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Update Statistics")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to update statistics: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Update Statistics")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func checkTable(_ table: SQLServerTableStat) async {
        let handle = activityEngine?.begin("Check table \(table.tableName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC CHECKTABLE('[\(table.schemaName)].[\(table.tableName)]')", category: "Check Table")
        do {
            let result = try await session.checkTable(schema: table.schemaName, table: table.tableName)
            for msg in result.messages {
                logOperation(msg, severity: result.succeeded ? .info : .warning, category: "Check Table")
            }
            let summary = result.succeeded
                ? "Table check completed successfully for \(table.schemaName).\(table.tableName)."
                : "Table check finished with issues: \(result.messages.first ?? "Unknown")"
            logOperation(summary, severity: result.succeeded ? .success : .warning, category: "Check Table")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            if result.succeeded { handle?.succeed() } else { handle?.fail(summary) }
        } catch {
            logOperation("Table check failed: \(error.localizedDescription)", severity: .error, category: "Check Table")
            notificationEngine?.post(category: .maintenanceFailed, message: "Table check failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func rebuildTable(_ table: SQLServerTableStat) async {
        let label = "Rebuild \(table.schemaName).\(table.tableName)"
        let handle = activityEngine?.begin(label, connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER TABLE [\(table.schemaName)].[\(table.tableName)] REBUILD", category: "Rebuild Table")
        do {
            let result = try await session.rebuildTable(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "Table rebuilt for \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Rebuild Table")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to rebuild table: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Rebuild Table")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to rebuild table: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Rebuild Table")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func rebuildAllIndexes(_ table: SQLServerTableStat) async {
        let label = "Rebuild indexes \(table.schemaName).\(table.tableName)"
        let handle = activityEngine?.begin(label, connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX ALL ON [\(table.schemaName)].[\(table.tableName)] REBUILD", category: "Rebuild Indexes")
        do {
            let result = try await session.rebuildIndexes(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "All indexes rebuilt for \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Rebuild Indexes")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to rebuild indexes: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Rebuild Indexes")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to rebuild indexes: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Rebuild Indexes")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func reorganizeAllIndexes(_ table: SQLServerTableStat) async {
        let label = "Reorganize indexes \(table.schemaName).\(table.tableName)"
        let handle = activityEngine?.begin(label, connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX ALL ON [\(table.schemaName)].[\(table.tableName)] REORGANIZE", category: "Reorganize Indexes")
        do {
            let result = try await session.reorganizeIndexes(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "All indexes reorganized for \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Reorganize Indexes")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to reorganize indexes: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Reorganize Indexes")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to reorganize indexes: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Reorganize Indexes")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }
}
