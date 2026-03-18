import Foundation
import Logging
import SQLiteNIO

actor SQLiteSession: DatabaseSession {
    private(set) var connection: SQLiteConnection?
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func bootstrap(with connection: SQLiteConnection) {
        self.connection = connection
    }

    func close() async {
        if let connection {
            do {
                try await connection.close()
            } catch {
                logger.warning("Failed to close SQLite connection: \(String(describing: error))")
            }
        }
        connection = nil
    }

    func requireConnection() throws -> SQLiteConnection {
        guard let connection else {
            throw DatabaseError.connectionFailed("SQLite connection has been closed")
        }
        return connection
    }

    func normalizedDatabaseName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return "main" }
        return trimmed
    }

    func quoteIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    func escapeSingleQuotes(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        _ = try await simpleQuery("REINDEX \(quoteIdentifier(index))")
        return DatabaseMaintenanceResult(operation: "Reindex", messages: ["Index reindexed."], succeeded: true)
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        _ = try await simpleQuery("REINDEX \(quoteIdentifier(table))")
        return DatabaseMaintenanceResult(operation: "Reindex", messages: ["Table reindexed."], succeeded: true)
    }

    func listFragmentedIndexes() async throws -> [SQLServerIndexFragmentation] {
        []
    }

    func getDatabaseHealth() async throws -> SQLServerDatabaseHealth {
        SQLServerDatabaseHealth(name: "main", owner: "", createDate: Date(), sizeMB: 0, recoveryModel: "N/A", status: "ONLINE", compatibilityLevel: 0, collationName: nil)
    }

    func getBackupHistory(limit: Int) async throws -> [SQLServerBackupHistoryEntry] {
        []
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        _ = try await simpleQuery("PRAGMA integrity_check")
        return DatabaseMaintenanceResult(operation: "Check Integrity", messages: ["Integrity check completed."], succeeded: true)
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        _ = try await simpleQuery("VACUUM")
        return DatabaseMaintenanceResult(operation: "Shrink", messages: ["Database shrunk via VACUUM."], succeeded: true)
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        _ = try await simpleQuery("ANALYZE \(quoteIdentifier(table))")
        return DatabaseMaintenanceResult(operation: "Analyze", messages: ["Statistics updated."], succeeded: true)
    }
}
