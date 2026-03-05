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
        return trimmed?.isEmpty ?? true ? "main" : trimmed!
    }

    func quoteIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    func escapeSingleQuotes(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
