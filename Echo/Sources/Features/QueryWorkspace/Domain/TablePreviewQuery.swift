import Foundation

/// The first-rows query for a table, as the Explorer's Data action and the empty query tab's
/// recent tables (QE6) insert it into the editor for the user to run.
nonisolated enum TablePreviewQuery {
    static let rowLimit = 1000

    static func sql(schema: String, table: String, databaseType: DatabaseType) -> String {
        let qualified = qualifiedName(schema: schema, table: table, databaseType: databaseType)
        return switch databaseType {
        case .microsoftSQL:
            "SELECT TOP \(rowLimit) * FROM \(qualified);"
        case .postgresql, .mysql, .sqlite:
            "SELECT * FROM \(qualified) LIMIT \(rowLimit);"
        }
    }

    static func qualifiedName(schema: String, table: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL:
            "\(bracketed(schema)).\(bracketed(table))"
        case .postgresql:
            "\(doubleQuoted(schema)).\(doubleQuoted(table))"
        case .mysql:
            "\(backticked(schema)).\(backticked(table))"
        case .sqlite:
            doubleQuoted(table)
        }
    }

    private static func bracketed(_ identifier: String) -> String {
        "[\(identifier.replacingOccurrences(of: "]", with: "]]"))]"
    }

    private static func doubleQuoted(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func backticked(_ identifier: String) -> String {
        "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
    }
}
