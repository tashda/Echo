import Foundation

extension MaintenanceViewModel {

    func vacuumTable(database: String, schema: String, table: String, full: Bool = false, analyze: Bool = false) async throws {
        let variant = full ? "VACUUM (FULL)" : analyze ? "VACUUM (ANALYZE)" : "VACUUM"
        let handle = activityEngine?.begin("\(variant) \(table)", connectionSessionID: connectionSessionID)
        logOperation("Executing: \(variant) \(schema).\(table)", category: "Vacuum")
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let dbSession = try await session.sessionForDatabase(database)
            try await dbSession.vacuumTable(schema: schema, table: table, full: full, analyze: analyze)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logOperation("Vacuum completed for \(schema).\(table).", severity: .success, category: "Vacuum", duration: elapsed)
            handle?.succeed()
        } catch {
            logOperation("Vacuum failed: \(error.localizedDescription)", severity: .error, category: "Vacuum")
            handle?.fail(error.localizedDescription)
            throw error
        }
    }

    func analyzeTable(database: String, schema: String, table: String) async throws {
        let handle = activityEngine?.begin("Analyze \(table)", connectionSessionID: connectionSessionID)
        logOperation("Executing: ANALYZE \(schema).\(table)", category: "Analyze")
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let dbSession = try await session.sessionForDatabase(database)
            try await dbSession.analyzeTable(schema: schema, table: table)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logOperation("Analyze completed for \(schema).\(table).", severity: .success, category: "Analyze", duration: elapsed)
            handle?.succeed()
        } catch {
            logOperation("Analyze failed: \(error.localizedDescription)", severity: .error, category: "Analyze")
            handle?.fail(error.localizedDescription)
            throw error
        }
    }

    func reindexTable(database: String, schema: String, table: String) async throws {
        let handle = activityEngine?.begin("Reindex \(table)", connectionSessionID: connectionSessionID)
        logOperation("Executing: REINDEX TABLE \(schema).\(table)", category: "Reindex")
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let dbSession = try await session.sessionForDatabase(database)
            try await dbSession.reindexTable(schema: schema, table: table)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logOperation("Reindex completed for \(schema).\(table).", severity: .success, category: "Reindex", duration: elapsed)
            handle?.succeed()
        } catch {
            logOperation("Reindex failed: \(error.localizedDescription)", severity: .error, category: "Reindex")
            handle?.fail(error.localizedDescription)
            throw error
        }
    }

    func reindexIndex(database: String, schema: String, indexName: String) async throws {
        let handle = activityEngine?.begin("Reindex \(indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: REINDEX INDEX \(schema).\(indexName)", category: "Reindex")
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let dbSession = try await session.sessionForDatabase(database)
            let quotedSchema = schema.replacingOccurrences(of: "\"", with: "\"\"")
            let quotedIndex = indexName.replacingOccurrences(of: "\"", with: "\"\"")
            _ = try await dbSession.simpleQuery("REINDEX INDEX \"\(quotedSchema)\".\"\(quotedIndex)\"")
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logOperation("Reindex completed for \(indexName).", severity: .success, category: "Reindex", duration: elapsed)
            handle?.succeed()
        } catch {
            logOperation("Reindex failed: \(error.localizedDescription)", severity: .error, category: "Reindex")
            handle?.fail(error.localizedDescription)
            throw error
        }
    }

    func reindex(_ index: PostgresIndexStat) async throws {
        guard let db = selectedDatabase else { return }
        try await reindexIndex(database: db, schema: index.schemaName, indexName: index.indexName)
        await fetchIndexStats(for: db)
    }

    func dropIndex(_ index: PostgresIndexStat) async throws {
        guard let db = selectedDatabase else { return }
        logOperation("Executing: DROP INDEX \(index.schemaName).\(index.indexName)", category: "Drop Index")
        do {
            let dbSession = try await session.sessionForDatabase(db)
            try await dbSession.dropIndex(schema: index.schemaName, name: index.indexName)
            logOperation("Index \(index.indexName) dropped.", severity: .success, category: "Drop Index")
            await fetchIndexStats(for: db)
        } catch {
            logOperation("Drop index failed: \(error.localizedDescription)", severity: .error, category: "Drop Index")
            throw error
        }
    }

    func refresh() async {
        guard let db = selectedDatabase else { return }
        await fetchTableStats(for: db)
        await fetchIndexStats(for: db)
    }
}
