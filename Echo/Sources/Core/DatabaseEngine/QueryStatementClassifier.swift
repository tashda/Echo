import Foundation

enum QueryStatementClassifier {
    static func isLikelyMessageOnlyStatement(_ sql: String, databaseType: DatabaseType) -> Bool {
        let normalized = normalizedSQL(sql)
        guard let keyword = leadingKeyword(in: normalized) else { return false }

        if normalized.contains(" RETURNING ") || normalized.contains(" OUTPUT ") {
            return false
        }

        switch keyword {
        case "ALTER", "CREATE", "DROP", "RENAME", "TRUNCATE",
             "INSERT", "UPDATE", "DELETE", "MERGE",
             "GRANT", "REVOKE", "COMMENT",
             "USE", "SET",
             "BEGIN", "START", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE",
             "VACUUM", "ANALYZE", "REINDEX", "CLUSTER",
             "LISTEN", "UNLISTEN", "NOTIFY":
            return true
        case "CALL":
            return databaseType == .postgresql
        default:
            return false
        }
    }

    private static func normalizedSQL(_ sql: String) -> String {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let collapsed = trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return " \(collapsed.uppercased()) "
    }

    private static func leadingKeyword(in normalizedSQL: String) -> String? {
        normalizedSQL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1)
            .first
            .map(String.init)
    }
}
