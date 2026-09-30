import Foundation
import PostgresKit
import PostgresWire
import os

extension PostgresSession {
    nonisolated func sanitizeSQL(_ sql: String) -> String {
        var trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.last == ";" {
            trimmed.removeLast()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    nonisolated func normalizeError(_ error: Error, contextSQL: String? = nil) -> Error {
        if let sessionError = error as? PostgresSessionError {
            let message = sessionError.errorDescription ?? String(describing: sessionError)
            os.Logger.postgres.error("PostgreSQL session error: \(message)")
            return DatabaseError.queryError(message)
        }
        if let scriptError = error as? PostgresScriptError {
            return normalizeError(scriptError.underlying, contextSQL: scriptError.statement.text)
        }
        if let kitError = error as? PostgresKit.PostgresError {
            return formatServerError(
                message: kitError.serverMessage ?? kitError.message,
                detail: kitError.detail,
                hint: kitError.hint,
                sqlState: kitError.sqlState,
                position: kitError.position,
                contextSQL: contextSQL
            )
        }
        guard let pgError = error as? PSQLError else { return error }
        return formatServerError(
            message: pgError.serverInfo?[.message] ?? pgError.localizedDescription,
            detail: pgError.serverInfo?[.detail],
            hint: pgError.serverInfo?[.hint],
            sqlState: pgError.serverInfo?[.sqlState],
            position: pgError.serverInfo?[.position].flatMap { Int($0) },
            contextSQL: contextSQL
        )
    }

    /// Message, detail, hint, SQLSTATE and — when the server reports a position — the statement
    /// with a caret under the error.
    private nonisolated func formatServerError(
        message: String,
        detail: String?,
        hint: String?,
        sqlState: String?,
        position: Int?,
        contextSQL: String?
    ) -> Error {
        var lines: [String] = [message.isEmpty ? "PostgreSQL error" : message]
        if let detail, !detail.isEmpty { lines.append(detail) }
        if let hint, !hint.isEmpty { lines.append("Hint: \(hint)") }
        if let sqlState, !sqlState.isEmpty { lines.append("SQLSTATE: \(sqlState)") }
        if let position, position > 0, let sql = contextSQL {
            let limitedSQL = sql.prefix(2_000)
            lines.append(String(limitedSQL))
            let caretPosition = min(position - 1, limitedSQL.count - 1)
            let pointer = String(repeating: " ", count: max(0, caretPosition)) + "^"
            lines.append(pointer)
        }
        let joined = lines.joined(separator: "\n")
        os.Logger.postgres.error("PostgreSQL error: \(joined)")
        return DatabaseError.queryError(joined)
    }

    func simpleQueryFastPathLimit(for sql: String) -> Int? {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedPrefix = trimmed.lowercased()
        guard normalizedPrefix.hasPrefix("select") || normalizedPrefix.hasPrefix("with ") else { return nil }

        let pattern = #"(?i)\blimit\s+(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              match.numberOfRanges > 1,
              let bound = Range(match.range(at: 1), in: trimmed),
              let value = Int(trimmed[bound]) else {
            return nil
        }
        return value
    }
}
