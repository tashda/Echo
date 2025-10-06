import SwiftUI
import Foundation
import Combine

// MARK: - SQL Formatter
class SQLFormatter: ObservableObject {

    enum DatabaseType: String, CaseIterable {
        case postgresql = "PostgreSQL"
        case mysql = "MySQL"
        case sqlite = "SQLite"
        case mssql = "Microsoft SQL Server"

        var keywords: Set<String> {
            switch self {
            case .postgresql:
                return postgresqlKeywords
            case .mysql:
                return mysqlKeywords
            case .sqlite:
                return sqliteKeywords
            case .mssql:
                return mssqlKeywords
            }
        }
    }

    @Published var databaseType: DatabaseType = .postgresql
    @Published var useColorHighlighting: Bool = true
    @Published var indentSize: Int = 2
    @Published var uppercaseKeywords: Bool = true

    // MARK: - Format SQL
    func formatSQL(_ sql: String) -> AttributedString {
        let cleanSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)

        if useColorHighlighting {
            return highlightSQL(cleanSQL)
        } else {
            return AttributedString(cleanSQL)
        }
    }

    // MARK: - SQL Syntax Highlighting
    private func highlightSQL(_ sql: String) -> AttributedString {
        var attributed = AttributedString(sql)
        let keywords = databaseType.keywords

        // Split into tokens while preserving positions
        let pattern = #"\b\w+\b|\S"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(location: 0, length: sql.count)
        let matches = regex.matches(in: sql, options: [], range: range)

        for match in matches.reversed() {
            let matchRange = match.range
            let startIndex = sql.index(sql.startIndex, offsetBy: matchRange.location)
            let endIndex = sql.index(startIndex, offsetBy: matchRange.length)
            let token = String(sql[startIndex..<endIndex])

            // Convert NSRange to AttributedString.Index
            if let attrStartIndex = AttributedString.Index(startIndex, within: attributed),
               let attrEndIndex = AttributedString.Index(endIndex, within: attributed) {

                let tokenUpper = token.uppercased()

                if keywords.contains(tokenUpper) {
                    // SQL Keywords
                    attributed[attrStartIndex..<attrEndIndex].foregroundColor = .blue
                    attributed[attrStartIndex..<attrEndIndex].font = .system(.body, design: .monospaced).weight(.semibold)

                    if uppercaseKeywords {
                        attributed.characters.replaceSubrange(attrStartIndex..<attrEndIndex, with: tokenUpper)
                    }
                } else if token.hasPrefix("'") && token.hasSuffix("'") {
                    // String literals
                    attributed[attrStartIndex..<attrEndIndex].foregroundColor = .green
                    attributed[attrStartIndex..<attrEndIndex].font = .system(.body, design: .monospaced)
                } else if token.hasPrefix("--") || (token.hasPrefix("/*") && token.hasSuffix("*/")) {
                    // Comments
                    attributed[attrStartIndex..<attrEndIndex].foregroundColor = .secondary
                    attributed[attrStartIndex..<attrEndIndex].font = .system(.body, design: .monospaced).italic()
                } else if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: token)) {
                    // Numbers
                    attributed[attrStartIndex..<attrEndIndex].foregroundColor = .orange
                    attributed[attrStartIndex..<attrEndIndex].font = .system(.body, design: .monospaced)
                } else {
                    // Default text
                    attributed[attrStartIndex..<attrEndIndex].font = .system(.body, design: .monospaced)
                    attributed[attrStartIndex..<attrEndIndex].foregroundColor = .primary
                }
            }
        }

        return attributed
    }
}

// MARK: - SQL Keywords by Database Type
private let postgresqlKeywords: Set<String> = [
    "SELECT", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER",
    "ON", "AS", "AND", "OR", "NOT", "IN", "EXISTS", "BETWEEN", "LIKE", "ILIKE",
    "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP",
    "ALTER", "TABLE", "VIEW", "INDEX", "SEQUENCE", "TRIGGER", "FUNCTION",
    "PROCEDURE", "RETURNS", "LANGUAGE", "PLPGSQL", "BEGIN", "END", "IF", "THEN",
    "ELSE", "ELSIF", "CASE", "WHEN", "WHILE", "FOR", "LOOP", "RETURN",
    "DECLARE", "TYPE", "RECORD", "ARRAY", "JSONB", "JSON", "UUID", "TIMESTAMP",
    "TIMESTAMPTZ", "DATE", "TIME", "INTERVAL", "BOOLEAN", "INTEGER", "BIGINT",
    "SMALLINT", "DECIMAL", "NUMERIC", "REAL", "DOUBLE", "PRECISION", "SERIAL",
    "BIGSERIAL", "TEXT", "VARCHAR", "CHAR", "BYTEA", "CONSTRAINT", "PRIMARY",
    "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "CHECK", "DEFAULT", "NULL",
    "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "INTERSECT",
    "EXCEPT", "DISTINCT", "ALL", "ANY", "SOME", "PARTITION", "WINDOW", "OVER"
]

private let mysqlKeywords: Set<String> = [
    "SELECT", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "CROSS",
    "ON", "AS", "AND", "OR", "NOT", "IN", "EXISTS", "BETWEEN", "LIKE",
    "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP",
    "ALTER", "TABLE", "VIEW", "INDEX", "TRIGGER", "FUNCTION", "PROCEDURE",
    "DELIMITER", "BEGIN", "END", "IF", "THEN", "ELSE", "ELSEIF", "CASE",
    "WHEN", "WHILE", "REPEAT", "UNTIL", "LOOP", "LEAVE", "ITERATE",
    "DECLARE", "HANDLER", "CONDITION", "CURSOR", "OPEN", "CLOSE", "FETCH",
    "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "DECIMAL", "NUMERIC",
    "FLOAT", "DOUBLE", "REAL", "BIT", "BOOLEAN", "SERIAL", "DATE", "TIME",
    "DATETIME", "TIMESTAMP", "YEAR", "CHAR", "VARCHAR", "BINARY", "VARBINARY",
    "TINYBLOB", "BLOB", "MEDIUMBLOB", "LONGBLOB", "TINYTEXT", "TEXT",
    "MEDIUMTEXT", "LONGTEXT", "ENUM", "SET", "JSON", "GEOMETRY"
]

private let sqliteKeywords: Set<String> = [
    "SELECT", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "CROSS", "ON", "AS",
    "AND", "OR", "NOT", "IN", "EXISTS", "BETWEEN", "LIKE", "GLOB", "MATCH",
    "REGEXP", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE",
    "DROP", "ALTER", "TABLE", "VIEW", "INDEX", "TRIGGER", "TEMPORARY", "TEMP",
    "IF", "NOT", "EXISTS", "BEGIN", "END", "COMMIT", "ROLLBACK", "SAVEPOINT",
    "RELEASE", "TRANSACTION", "DEFERRED", "IMMEDIATE", "EXCLUSIVE", "PRAGMA",
    "VACUUM", "REINDEX", "ANALYZE", "ATTACH", "DETACH", "DATABASE", "SCHEMA",
    "INTEGER", "REAL", "TEXT", "BLOB", "NUMERIC", "BOOLEAN", "DATE", "DATETIME",
    "CONSTRAINT", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "CHECK",
    "DEFAULT", "NULL", "AUTOINCREMENT", "COLLATE", "ORDER", "BY", "GROUP",
    "HAVING", "LIMIT", "OFFSET", "UNION", "INTERSECT", "EXCEPT", "DISTINCT",
    "ALL", "CASE", "WHEN", "THEN", "ELSE", "CAST", "TYPEOF", "LENGTH"
]

private let mssqlKeywords: Set<String> = [
    "SELECT", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "CROSS",
    "ON", "AS", "AND", "OR", "NOT", "IN", "EXISTS", "BETWEEN", "LIKE",
    "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP",
    "ALTER", "TABLE", "VIEW", "INDEX", "TRIGGER", "FUNCTION", "PROCEDURE",
    "BEGIN", "END", "IF", "ELSE", "WHILE", "FOR", "BREAK", "CONTINUE",
    "RETURN", "DECLARE", "SET", "PRINT", "RAISERROR", "TRY", "CATCH",
    "THROW", "EXEC", "EXECUTE", "SP_EXECUTESQL", "OPENQUERY", "OPENROWSET",
    "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "DECIMAL", "NUMERIC",
    "FLOAT", "REAL", "MONEY", "SMALLMONEY", "BIT", "DATE", "TIME", "DATETIME",
    "DATETIME2", "SMALLDATETIME", "DATETIMEOFFSET", "TIMESTAMP", "CHAR",
    "VARCHAR", "NCHAR", "NVARCHAR", "TEXT", "NTEXT", "BINARY", "VARBINARY",
    "IMAGE", "UNIQUEIDENTIFIER", "XML", "GEOGRAPHY", "GEOMETRY", "HIERARCHYID",
    "SQL_VARIANT", "TABLE", "CURSOR", "IDENTITY", "ROWGUIDCOL", "WITH",
    "PARTITION", "WINDOW", "OVER", "ROW_NUMBER", "RANK", "DENSE_RANK", "NTILE"
]

// MARK: - SwiftUI Integration
extension SQLFormatter {
    static let shared = SQLFormatter()
}

// MARK: - Settings Key
extension SQLFormatter {
    func loadSettings() {
        if let typeString = UserDefaults.standard.string(forKey: "SQLFormatterDatabaseType"),
           let type = DatabaseType(rawValue: typeString) {
            self.databaseType = type
        }
        self.useColorHighlighting = UserDefaults.standard.object(forKey: "SQLFormatterUseColorHighlighting") as? Bool ?? true
        self.indentSize = UserDefaults.standard.object(forKey: "SQLFormatterIndentSize") as? Int ?? 2
        self.uppercaseKeywords = UserDefaults.standard.object(forKey: "SQLFormatterUppercaseKeywords") as? Bool ?? true
    }

    func saveSettings() {
        UserDefaults.standard.set(databaseType.rawValue, forKey: "SQLFormatterDatabaseType")
        UserDefaults.standard.set(useColorHighlighting, forKey: "SQLFormatterUseColorHighlighting")
        UserDefaults.standard.set(indentSize, forKey: "SQLFormatterIndentSize")
        UserDefaults.standard.set(uppercaseKeywords, forKey: "SQLFormatterUppercaseKeywords")
    }
}