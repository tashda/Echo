import Foundation
import PostgresKit
import PostgresWire
import Logging

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
        guard let pgError = error as? PSQLError else { return error }

        var lines: [String] = []
        if let message = pgError.serverInfo?[.message], !message.isEmpty {
            lines.append(message)
        } else {
            lines.append(pgError.localizedDescription)
        }
        if let detail = pgError.serverInfo?[.detail], !detail.isEmpty {
            lines.append(detail)
        }
        if let hint = pgError.serverInfo?[.hint], !hint.isEmpty {
            lines.append("Hint: \(hint)")
        }
        if let sqlState = pgError.serverInfo?[.sqlState], !sqlState.isEmpty {
            lines.append("SQLSTATE: \(sqlState)")
        }
        if
            let positionString = pgError.serverInfo?[.position],
            let position = Int(positionString),
            position > 0,
            let sql = contextSQL
        {
            let limitedSQL = sql.prefix(2_000)
            lines.append(String(limitedSQL))
            let caretPosition = min(position - 1, limitedSQL.count - 1)
            let pointer = String(repeating: " ", count: max(0, caretPosition)) + "^"
            lines.append(pointer)
        }

        let message = lines.joined(separator: "\n")
        logger.error(.init(stringLiteral: "PostgreSQL error: \(message)"))
        return DatabaseError.queryError(message)
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
