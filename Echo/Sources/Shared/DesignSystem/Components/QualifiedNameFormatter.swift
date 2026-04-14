import Foundation

/// Formats schema-qualified object names per database dialect for drag & drop
/// and other contexts that need properly quoted identifiers.
enum QualifiedNameFormatter {

    static func format(
        schema: String,
        name: String,
        for databaseType: DatabaseType,
        database: String? = nil
    ) -> String {
        let qualifiedName: String
        switch databaseType {
        case .microsoftSQL:
            let schemaQuoted = mssqlQuote(schema)
            let nameQuoted = mssqlQuote(name)
            if let db = database {
                qualifiedName = "\(mssqlQuote(db)).\(schemaQuoted).\(nameQuoted)"
            } else {
                qualifiedName = "\(schemaQuoted).\(nameQuoted)"
            }
        case .postgresql:
            let schemaQuoted = pgQuote(schema)
            let nameQuoted = pgQuote(name)
            if let db = database {
                qualifiedName = "\(pgQuote(db)).\(schemaQuoted).\(nameQuoted)"
            } else {
                qualifiedName = "\(schemaQuoted).\(nameQuoted)"
            }
        case .mysql:
            let schemaQuoted = mysqlQuote(schema)
            let nameQuoted = mysqlQuote(name)
            if let db = database {
                qualifiedName = "\(mysqlQuote(db)).\(nameQuoted)"
            } else if !schema.isEmpty {
                qualifiedName = "\(schemaQuoted).\(nameQuoted)"
            } else {
                qualifiedName = nameQuoted
            }
        case .sqlite:
            qualifiedName = sqliteQuote(name)
        }
        return qualifiedName
    }

    /// Returns a single quoted database name for drag & drop.
    static func quotedDatabaseName(_ name: String, for databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL: return mssqlQuote(name)
        case .postgresql: return pgQuote(name)
        case .mysql: return mysqlQuote(name)
        case .sqlite: return sqliteQuote(name)
        }
    }

    private static func mssqlQuote(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    private static func pgQuote(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func mysqlQuote(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "`", with: "``")
        return "`\(escaped)`"
    }

    private static func sqliteQuote(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
