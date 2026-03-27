import Foundation

/// A single maintenance operation that can be executed against a database session.
struct MaintenanceOperation: Identifiable {
    let id: String
    let name: String
    let description: String
    let action: @Sendable (DatabaseSession, String?) async throws -> DatabaseMaintenanceResult
    var lastResult: MaintenanceOperationResult?
}

/// Result of executing a maintenance operation.
struct MaintenanceOperationResult {
    let succeeded: Bool
    let message: String
}

// MARK: - Operation Builders

extension GenericMaintenanceView {

    static func buildOperations(for databaseType: DatabaseType) -> [MaintenanceOperation] {
        switch databaseType {
        case .mysql:
            return mysqlOperations
        case .sqlite:
            return sqliteOperations
        default:
            return []
        }
    }

    // MARK: - MySQL Operations

    private static var mysqlOperations: [MaintenanceOperation] {
        [
            MaintenanceOperation(
                id: "mysql-optimize",
                name: "Optimize All Tables",
                description: "Reclaims unused space and defragments the data file for all tables in the selected database.",
                action: { session, database in
                    guard let database else {
                        return DatabaseMaintenanceResult(operation: "Optimize", messages: ["No database selected."], succeeded: false)
                    }
                    let tables = try await session.listTablesAndViews(schema: database)
                    let tableNames = tables.filter { $0.type == .table }.map(\.name)
                    guard !tableNames.isEmpty else {
                        return DatabaseMaintenanceResult(operation: "Optimize", messages: ["No tables found."], succeeded: true)
                    }
                    let qualified = tableNames.map { "`\(database)`.`\($0)`" }.joined(separator: ", ")
                    let result = try await session.simpleQuery("OPTIMIZE TABLE \(qualified)")
                    let messages = result.rows.compactMap { $0.last ?? nil }
                    return DatabaseMaintenanceResult(operation: "Optimize", messages: messages.isEmpty ? ["Optimized \(tableNames.count) tables."] : messages, succeeded: true)
                }
            ),
            MaintenanceOperation(
                id: "mysql-analyze",
                name: "Analyze All Tables",
                description: "Updates index statistics so the optimizer can choose better query plans.",
                action: { session, database in
                    guard let database else {
                        return DatabaseMaintenanceResult(operation: "Analyze", messages: ["No database selected."], succeeded: false)
                    }
                    let tables = try await session.listTablesAndViews(schema: database)
                    let tableNames = tables.filter { $0.type == .table }.map(\.name)
                    guard !tableNames.isEmpty else {
                        return DatabaseMaintenanceResult(operation: "Analyze", messages: ["No tables found."], succeeded: true)
                    }
                    let qualified = tableNames.map { "`\(database)`.`\($0)`" }.joined(separator: ", ")
                    let result = try await session.simpleQuery("ANALYZE TABLE \(qualified)")
                    let messages = result.rows.compactMap { $0.last ?? nil }
                    return DatabaseMaintenanceResult(operation: "Analyze", messages: messages.isEmpty ? ["Analyzed \(tableNames.count) tables."] : messages, succeeded: true)
                }
            ),
            MaintenanceOperation(
                id: "mysql-check",
                name: "Check All Tables",
                description: "Checks tables for errors. Reports any corruption or inconsistencies found.",
                action: { session, database in
                    guard let database else {
                        return DatabaseMaintenanceResult(operation: "Check", messages: ["No database selected."], succeeded: false)
                    }
                    let tables = try await session.listTablesAndViews(schema: database)
                    let tableNames = tables.filter { $0.type == .table }.map(\.name)
                    guard !tableNames.isEmpty else {
                        return DatabaseMaintenanceResult(operation: "Check", messages: ["No tables found."], succeeded: true)
                    }
                    let qualified = tableNames.map { "`\(database)`.`\($0)`" }.joined(separator: ", ")
                    let result = try await session.simpleQuery("CHECK TABLE \(qualified)")
                    let messages = result.rows.compactMap { $0.last ?? nil }
                    let hasError = messages.contains(where: { $0.lowercased().contains("error") || $0.lowercased().contains("corrupt") })
                    return DatabaseMaintenanceResult(
                        operation: "Check",
                        messages: messages.isEmpty ? ["Checked \(tableNames.count) tables — no errors found."] : messages,
                        succeeded: !hasError
                    )
                }
            ),
            MaintenanceOperation(
                id: "mysql-repair",
                name: "Repair All Tables",
                description: "Attempts to repair corrupted MyISAM and ARCHIVE tables. InnoDB tables use automatic crash recovery.",
                action: { session, database in
                    guard let database else {
                        return DatabaseMaintenanceResult(operation: "Repair", messages: ["No database selected."], succeeded: false)
                    }
                    let tables = try await session.listTablesAndViews(schema: database)
                    let tableNames = tables.filter { $0.type == .table }.map(\.name)
                    guard !tableNames.isEmpty else {
                        return DatabaseMaintenanceResult(operation: "Repair", messages: ["No tables found."], succeeded: true)
                    }
                    let qualified = tableNames.map { "`\(database)`.`\($0)`" }.joined(separator: ", ")
                    let result = try await session.simpleQuery("REPAIR TABLE \(qualified)")
                    let messages = result.rows.compactMap { $0.last ?? nil }
                    let hasError = messages.contains(where: { $0.lowercased().contains("error") })
                    return DatabaseMaintenanceResult(
                        operation: "Repair",
                        messages: messages.isEmpty ? ["Repair completed for \(tableNames.count) tables."] : messages,
                        succeeded: !hasError
                    )
                }
            ),
        ]
    }

    // MARK: - SQLite Operations

    private static var sqliteOperations: [MaintenanceOperation] {
        [
            MaintenanceOperation(
                id: "sqlite-vacuum",
                name: "Vacuum",
                description: "Rebuilds the database file, repacking it into the minimum amount of disk space.",
                action: { session, _ in
                    _ = try await session.simpleQuery("VACUUM")
                    return DatabaseMaintenanceResult(operation: "Vacuum", messages: ["Database vacuumed successfully."], succeeded: true)
                }
            ),
            MaintenanceOperation(
                id: "sqlite-reindex",
                name: "Reindex",
                description: "Deletes and recreates all indexes, fixing any corruption in index data.",
                action: { session, _ in
                    _ = try await session.simpleQuery("REINDEX")
                    return DatabaseMaintenanceResult(operation: "Reindex", messages: ["All indexes rebuilt successfully."], succeeded: true)
                }
            ),
            MaintenanceOperation(
                id: "sqlite-analyze",
                name: "Analyze",
                description: "Gathers statistics about tables and indexes to help the query planner make better choices.",
                action: { session, _ in
                    _ = try await session.simpleQuery("ANALYZE")
                    return DatabaseMaintenanceResult(operation: "Analyze", messages: ["Statistics updated successfully."], succeeded: true)
                }
            ),
            MaintenanceOperation(
                id: "sqlite-integrity-check",
                name: "Integrity Check",
                description: "Performs a thorough check of the entire database for corruption, malformed records, and missing indexes.",
                action: { session, _ in
                    let result = try await session.simpleQuery("PRAGMA integrity_check")
                    let messages = result.rows.compactMap { $0.first ?? nil }
                    let isOK = messages.count == 1 && messages.first?.lowercased() == "ok"
                    return DatabaseMaintenanceResult(
                        operation: "Integrity Check",
                        messages: isOK ? ["Database integrity check passed."] : messages,
                        succeeded: isOK
                    )
                }
            ),
            MaintenanceOperation(
                id: "sqlite-wal-checkpoint",
                name: "WAL Checkpoint",
                description: "Forces a write-ahead log checkpoint, transferring WAL content back into the main database file.",
                action: { session, _ in
                    let result = try await session.simpleQuery("PRAGMA wal_checkpoint(TRUNCATE)")
                    let messages = result.rows.compactMap { row -> String? in
                        guard row.count >= 3 else { return nil }
                        let busy = row[0] ?? "?"
                        let log = row[1] ?? "?"
                        let checkpointed = row[2] ?? "?"
                        return "Busy: \(busy), Log pages: \(log), Checkpointed: \(checkpointed)"
                    }
                    return DatabaseMaintenanceResult(
                        operation: "WAL Checkpoint",
                        messages: messages.isEmpty ? ["WAL checkpoint completed."] : messages,
                        succeeded: true
                    )
                }
            ),
        ]
    }
}

