import Foundation

extension MSSQLMaintenanceViewModel {

    func refreshIndexes() async {
        isRefreshingIndexes = true
        defer { isRefreshingIndexes = false }
        do {
            let dbSession = try await resolveSession()
            fragmentedIndexes = try await dbSession.listFragmentedIndexes()
        } catch {
            // Keep existing data if refresh fails
        }
    }

    func rebuildIndex(_ index: SQLServerIndexFragmentation) async {
        let handle = activityEngine?.begin("Rebuild \(index.indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX [\(index.indexName)] ON [\(index.schemaName)].[\(index.tableName)] REBUILD", category: "Index Rebuild")
        do {
            let dbSession = try await resolveSession()
            let result = try await dbSession.rebuildIndex(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                await refreshIndexes()
                let msg = "Index \(index.indexName) rebuilt successfully."
                logOperation(msg, severity: .success, category: "Index Rebuild")
                notificationEngine?.post(category: .indexRebuilt, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to rebuild index \(index.indexName): \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Index Rebuild")
                notificationEngine?.post(category: .indexRebuildFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to rebuild index \(index.indexName): \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Index Rebuild")
            notificationEngine?.post(category: .indexRebuildFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func reorganizeIndex(_ index: SQLServerIndexFragmentation) async {
        let handle = activityEngine?.begin("Reorganize \(index.indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX [\(index.indexName)] ON [\(index.schemaName)].[\(index.tableName)] REORGANIZE", category: "Index Reorganize")
        do {
            let dbSession = try await resolveSession()
            let result = try await dbSession.reorganizeIndex(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                await refreshIndexes()
                let msg = "Index \(index.indexName) reorganized successfully."
                logOperation(msg, severity: .success, category: "Index Reorganize")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to reorganize index \(index.indexName): \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Index Reorganize")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to reorganize index \(index.indexName): \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Index Reorganize")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func updateStatistics(_ index: SQLServerIndexFragmentation) async {
        let handle = activityEngine?.begin("Update stats \(index.indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: UPDATE STATISTICS [\(index.schemaName)].[\(index.tableName)] [\(index.indexName)]", category: "Update Statistics")
        do {
            let dbSession = try await resolveSession()
            let result = try await dbSession.updateIndexStatistics(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                await refreshIndexes()
                let msg = "Statistics updated for index \(index.indexName) on table \(index.tableName)."
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
}
