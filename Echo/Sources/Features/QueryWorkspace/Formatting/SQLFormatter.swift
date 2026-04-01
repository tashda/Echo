import Foundation
import JavaScriptCore
import OSLog

enum SQLFormatterError: LocalizedError {
    case engineNotReady
    case formattingFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineNotReady:
            return "SQL formatter engine could not be initialized. Ensure sql-formatter.min.js is included in the app bundle."
        case .formattingFailed(let message):
            return "SQL formatting failed: \(message)"
        }
    }
}

final class SQLFormatter: SQLFormatterProtocol, Sendable {
    static let shared = SQLFormatter()

    enum Dialect: String {
        case postgres
        case mysql
        case sqlite
        case duckdb
        case microsoftSQL

        var sqlFormatterLanguage: String {
            switch self {
            case .postgres:
                return "postgresql"
            case .mysql:
                return "mysql"
            case .sqlite:
                return "sqlite"
            case .duckdb:
                return "sql"
            case .microsoftSQL:
                return "transactsql"
            }
        }
    }

    private let queue = DispatchQueue(label: "dev.echodb.echo.sqlformatter", qos: .userInitiated)
    private nonisolated(unsafe) var jsContext: JSContext?

    private init() {
        queue.sync {
            self.jsContext = Self.createContext()
        }
    }

    func format(sql: String, dialect: Dialect = .postgres) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let formatted = try self.runFormatter(sql: sql, dialect: dialect)
                    continuation.resume(returning: formatted)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private static func createContext() -> JSContext? {
        guard let context = JSContext() else { return nil }

        context.exceptionHandler = { _, exception in
            if let message = exception?.toString() {
                Logger.formatting.error("JS exception: \(message)")
            }
        }

        guard let bundleURL = Bundle.main.url(forResource: "sql-formatter.min", withExtension: "js"),
              let source = try? String(contentsOf: bundleURL, encoding: .utf8) else {
            return nil
        }

        context.evaluateScript(source)
        return context
    }

    private func runFormatter(sql: String, dialect: Dialect) throws -> String {
        guard let context = jsContext else {
            throw SQLFormatterError.engineNotReady
        }

        guard let formatFn = context.objectForKeyedSubscript("formatSQL"),
              !formatFn.isUndefined else {
            throw SQLFormatterError.engineNotReady
        }

        let result = formatFn.call(withArguments: [sql, dialect.sqlFormatterLanguage, 4, "upper", 50])

        if let exception = context.exception {
            let message = exception.toString() ?? "Unknown error"
            context.exception = nil
            throw SQLFormatterError.formattingFailed(message)
        }

        guard let formatted = result?.toString(), !formatted.isEmpty else {
            return sql
        }

        return formatted
    }
}
