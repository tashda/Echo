import Foundation
import MySQLKit

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
                    try await runMySQLAdminOperation(
                        named: "Optimize",
                        session: session,
                        database: database
                    ) { admin, schema, table in
                        try await admin.optimizeTable(schema: schema, table: table)
                    }
                }
            ),
            MaintenanceOperation(
                id: "mysql-analyze",
                name: "Analyze All Tables",
                description: "Updates index statistics so the optimizer can choose better query plans.",
                action: { session, database in
                    try await runMySQLAdminOperation(
                        named: "Analyze",
                        session: session,
                        database: database
                    ) { admin, schema, table in
                        try await admin.analyzeTable(schema: schema, table: table)
                    }
                }
            ),
            MaintenanceOperation(
                id: "mysql-check",
                name: "Check All Tables",
                description: "Checks tables for errors. Reports any corruption or inconsistencies found.",
                action: { session, database in
                    try await runMySQLAdminOperation(
                        named: "Check",
                        session: session,
                        database: database
                    ) { admin, schema, table in
                        try await admin.checkTable(schema: schema, table: table)
                    }
                }
            ),
            MaintenanceOperation(
                id: "mysql-repair",
                name: "Repair All Tables",
                description: "Attempts to repair corrupted MyISAM and ARCHIVE tables. InnoDB tables use automatic crash recovery.",
                action: { session, database in
                    try await runMySQLAdminOperation(
                        named: "Repair",
                        session: session,
                        database: database
                    ) { admin, schema, table in
                        try await admin.repairTable(schema: schema, table: table)
                    }
                }
            ),
            MaintenanceOperation(
                id: "mysql-flush-tables",
                name: "Flush Tables",
                description: "Closes open table handles and flushes metadata so subsequent operations pick up the latest state.",
                action: { session, _ in
                    guard let mysqlSession = session as? MySQLSession else {
                        return DatabaseMaintenanceResult(operation: "Flush Tables", messages: ["MySQL admin APIs are unavailable for this session."], succeeded: false)
                    }

                    try await mysqlSession.client.admin.flushTables()
                    return DatabaseMaintenanceResult(
                        operation: "Flush Tables",
                        messages: ["Flushed open table handles successfully."],
                        succeeded: true
                    )
                }
            ),
        ]
    }

    private static func runMySQLAdminOperation(
        named operation: String,
        session: DatabaseSession,
        database: String?,
        executor: (MySQLAdminClient, String, String) async throws -> MySQLMaintenanceResult
    ) async throws -> DatabaseMaintenanceResult {
        guard let database, !database.isEmpty else {
            return DatabaseMaintenanceResult(operation: operation, messages: ["No database selected."], succeeded: false)
        }
        guard let mysqlSession = session as? MySQLSession else {
            return DatabaseMaintenanceResult(operation: operation, messages: ["MySQL admin APIs are unavailable for this session."], succeeded: false)
        }

        let tables = try await session.listTablesAndViews(schema: database)
        let tableNames = tables.filter { $0.type == .table }.map(\.name)
        guard !tableNames.isEmpty else {
            return DatabaseMaintenanceResult(operation: operation, messages: ["No tables found."], succeeded: true)
        }

        var messages: [String] = []
        for table in tableNames {
            let result = try await executor(mysqlSession.client.admin, database, table)
            if result.messages.isEmpty {
                messages.append("\(operation) completed for \(table).")
            } else {
                messages.append(contentsOf: result.messages.map { "\(table): \($0)" })
            }
        }

        let hasError = messages.contains { message in
            let normalized = message.lowercased()
            return normalized.contains("error") || normalized.contains("corrupt")
        }

        return DatabaseMaintenanceResult(
            operation: operation,
            messages: messages,
            succeeded: !hasError
        )
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
