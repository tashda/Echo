import Foundation
import JavaScriptCore
import OSLog
import EchoSense

/// Result of parsing SQL via node-sql-parser.
/// Contains either a successful parse with table/column references, or an error with position info.
struct SQLParseResult: Sendable {
    let success: Bool
    let tableReferences: [SQLTableReference]
    let columnReferences: [SQLColumnReference]
    let error: SQLParseError?
}

/// A table referenced in the SQL statement (extracted from FROM, JOIN, UPDATE, INTO, etc.)
struct SQLTableReference: Sendable, Equatable {
    /// The operation type: "select", "insert", "update", "delete"
    let operation: String
    /// Schema name if qualified (e.g., "dbo" in dbo.users), nil otherwise
    let schema: String?
    /// Table name
    let table: String
}

/// A column referenced in the SQL statement
struct SQLColumnReference: Sendable, Equatable {
    /// The operation type
    let operation: String
    /// Table qualifier if present (e.g., "u" in u.id), nil otherwise
    let table: String?
    /// Column name (or "*" for star)
    let column: String
}

/// Error from the SQL parser with position information
struct SQLParseError: Sendable {
    let message: String
    let line: Int?
    let column: Int?
    let offset: Int?
}

/// Bridge to node-sql-parser running in JavaScriptCore.
/// Follows the same thread-safety pattern as SQLFormatter: serial DispatchQueue protecting JSContext.
final class SQLParserBridge: Sendable {
    static let shared = SQLParserBridge()

    private let queue = DispatchQueue(label: "dev.echodb.echo.sqlparser", qos: .userInitiated)
    private nonisolated(unsafe) var jsContext: JSContext?

    private init() {
        queue.sync {
            self.jsContext = Self.createContext()
        }
    }

    /// Parse SQL and return table/column references or an error with position.
    /// Returns nil if the JS engine is not ready (bundle missing).
    func parse(sql: String, dialect: EchoSenseDatabaseType) async -> SQLParseResult? {
        await withCheckedContinuation { continuation in
            queue.async {
                let result = self.runParser(sql: sql, dialect: dialect)
                continuation.resume(returning: result)
            }
        }
    }

    /// Synchronous parse for use on the parser queue or in tests.
    func parseSync(sql: String, dialect: EchoSenseDatabaseType) -> SQLParseResult? {
        queue.sync {
            self.runParser(sql: sql, dialect: dialect)
        }
    }

    // MARK: - Private

    private static func createContext() -> JSContext? {
        guard let context = JSContext() else { return nil }

        context.exceptionHandler = { _, exception in
            if let message = exception?.toString() {
                Logger.validation.error("SQL parser JS exception: \(message)")
            }
        }

        guard let bundleURL = Bundle.main.url(forResource: "sql-parser.min", withExtension: "js"),
              let source = try? String(contentsOf: bundleURL, encoding: .utf8) else {
            Logger.validation.error("sql-parser.min.js not found in bundle")
            return nil
        }

        context.evaluateScript(source)
        return context
    }

    private func runParser(sql: String, dialect: EchoSenseDatabaseType) -> SQLParseResult? {
        guard let context = jsContext else { return nil }

        guard let parseFn = context.objectForKeyedSubscript("parseSQL"),
              !parseFn.isUndefined else {
            Logger.validation.error("parseSQL function not found in JS context")
            return nil
        }

        let result = parseFn.call(withArguments: [sql, dialect.sqlParserDatabase])

        if let exception = context.exception {
            let message = exception.toString() ?? "Unknown JS error"
            context.exception = nil
            Logger.validation.error("parseSQL threw: \(message)")
            return nil
        }

        guard let jsonString = result?.toString(),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let success = json["success"] as? Bool ?? false

        if success {
            let tables = Self.parseTableList(json["tableList"] as? [String] ?? [])
            let columns = Self.parseColumnList(json["columnList"] as? [String] ?? [])
            return SQLParseResult(success: true, tableReferences: tables, columnReferences: columns, error: nil)
        } else {
            let errorDict = json["error"] as? [String: Any] ?? [:]
            let message = errorDict["message"] as? String ?? "Unknown parse error"
            let location = errorDict["location"] as? [String: Any]
            let start = location?["start"] as? [String: Any]

            let error = SQLParseError(
                message: message,
                line: start?["line"] as? Int,
                column: start?["column"] as? Int,
                offset: start?["offset"] as? Int
            )
            return SQLParseResult(success: false, tableReferences: [], columnReferences: [], error: error)
        }
    }

    /// Parse table list entries like "select::schema::table" or "select::null::table"
    private static func parseTableList(_ list: [String]) -> [SQLTableReference] {
        list.compactMap { entry in
            let parts = entry.split(separator: "::", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            let schema = parts[1] == "null" ? nil : parts[1]
            return SQLTableReference(operation: parts[0], schema: schema, table: parts[2])
        }
    }

    /// Parse column list entries like "select::table::column" or "select::null::column"
    private static func parseColumnList(_ list: [String]) -> [SQLColumnReference] {
        list.compactMap { entry in
            let parts = entry.split(separator: "::", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            let table = parts[1] == "null" ? nil : parts[1]
            return SQLColumnReference(operation: parts[0], table: table, column: parts[2])
        }
    }
}

// MARK: - Dialect Mapping

extension EchoSenseDatabaseType {
    /// Maps to node-sql-parser's database parameter
    var sqlParserDatabase: String {
        switch self {
        case .postgresql: return "PostgreSQL"
        case .mysql: return "MySQL"
        case .sqlite: return "SQLite"
        case .microsoftSQL: return "TransactSQL"
        }
    }
}
