import Foundation

struct SQLiteScriptProvider: DatabaseScriptProvider {
    func quoteIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    func qualifiedName(schema: String, name: String) -> String {
        quoteIdentifier(name)
    }

    func scriptActions(for objectType: SchemaObjectInfo.ObjectType) -> [DatabaseObjectRow.ScriptAction] {
        var actions: [DatabaseObjectRow.ScriptAction] = [.create, .drop]
        switch objectType {
        case .table, .view, .materializedView:
            actions.append(contentsOf: [.select, .selectLimited(1000)])
        case .function, .procedure, .trigger:
            break
        }
        return actions
    }

    func executeStatement(for objectType: SchemaObjectInfo.ObjectType, qualifiedName: String) -> String {
        "-- Programmable object execution is not supported in SQLite."
    }

    func truncateStatement(qualifiedName: String) -> String {
        "-- TRUNCATE TABLE is not supported in SQLite."
    }

    func renameStatement(for object: SchemaObjectInfo, qualifiedName: String, newName: String?) -> String? {
        let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = (trimmedName?.isEmpty ?? true) ? "<new_name>" : trimmedName!
        let quotedNewName = quoteIdentifier(effectiveName)

        switch object.type {
        case .table:
            return "ALTER TABLE \(qualifiedName) RENAME TO \(quotedNewName);"
        case .view:
            return """
        -- SQLite cannot rename views directly.
        -- Drop and recreate the view with the desired name.
        """
        case .trigger, .function, .procedure, .materializedView:
            return "-- Renaming is not supported for this object in SQLite."
        }
    }

    func dropStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String, includeIfExists: Bool, triggerTargetName: String) -> String {
        let ifExists = includeIfExists ? "IF EXISTS " : ""
        return "DROP \(keyword) \(ifExists)\(qualifiedName);"
    }

    func alterStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String) -> String {
        "-- ALTER is not directly supported for this object. Consider using CREATE OR REPLACE."
    }

    func alterTableStatement(qualifiedName: String) -> String {
        """
        ALTER TABLE \(qualifiedName)
            RENAME COLUMN old_column TO new_column;
        """
    }

    func selectStatement(qualifiedName: String, columnLines: String, limit: Int?, offset: Int) -> String {
        var statement = """
        SELECT
            \(columnLines)
        FROM \(qualifiedName)
        """
        if let limit {
            statement += "\nLIMIT \(limit)"
            if offset > 0 {
                statement += "\nOFFSET \(offset)"
            }
        } else if offset > 0 {
            statement += "\nOFFSET \(offset)"
        }
        statement += ";"
        return statement
    }

    var supportsTruncateTable: Bool { false }
    var renameMenuLabel: String { "Rename (Limited)" }
}
