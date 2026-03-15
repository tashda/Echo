import Foundation

struct PostgresScriptProvider: DatabaseScriptProvider {
    func quoteIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    func scriptActions(for objectType: SchemaObjectInfo.ObjectType) -> [DatabaseObjectRow.ScriptAction] {
        var actions: [DatabaseObjectRow.ScriptAction] = [.create]
        if objectType != .table {
            actions.append(.createOrReplace)
        }
        actions.append(.dropIfExists)
        switch objectType {
        case .table, .view, .materializedView:
            actions.append(.select)
            actions.append(.selectLimited(1000))
        case .function, .procedure:
            actions.append(.select)
            actions.append(.execute)
        case .trigger, .extension:
            break
        }
        return actions
    }

    func executeStatement(for objectType: SchemaObjectInfo.ObjectType, qualifiedName: String) -> String {
        if objectType == .procedure {
            return "CALL \(qualifiedName)(/* arguments */);"
        } else {
            return "SELECT * FROM \(qualifiedName)(/* arguments */);"
        }
    }

    func truncateStatement(qualifiedName: String) -> String {
        "TRUNCATE TABLE \(qualifiedName);"
    }

    func renameStatement(for object: SchemaObjectInfo, qualifiedName: String, newName: String?) -> String? {
        let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmedName.flatMap({ $0.isEmpty ? nil : $0 }) ?? "<new_name>"
        let quotedNewName = quoteIdentifier(effectiveName)

        switch object.type {
        case .table:
            return "ALTER TABLE \(qualifiedName) RENAME TO \(quotedNewName);"
        case .view:
            return "ALTER VIEW \(qualifiedName) RENAME TO \(quotedNewName);"
        case .materializedView:
            return "ALTER MATERIALIZED VIEW \(qualifiedName) RENAME TO \(quotedNewName);"
        case .function:
            return trimmedName == nil
                ? "ALTER FUNCTION \(qualifiedName)(/* arg_types */) RENAME TO \(quotedNewName);"
                : nil
        case .procedure:
            return trimmedName == nil
                ? "ALTER PROCEDURE \(qualifiedName)(/* arg_types */) RENAME TO \(quotedNewName);"
                : nil
        case .trigger:
            let target = triggerTargetName(for: object)
            return "ALTER TRIGGER \(quoteIdentifier(object.name)) ON \(target) RENAME TO \(quotedNewName);"
        case .extension:
            return nil
        }
    }

    func dropStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String, includeIfExists: Bool, triggerTargetName: String) -> String {
        let ifExists = includeIfExists ? "IF EXISTS " : ""
        switch object.type {
        case .trigger:
            return "DROP TRIGGER \(ifExists)\(quoteIdentifier(object.name)) ON \(triggerTargetName);"
        case .function, .procedure:
            return "DROP FUNCTION \(ifExists)\(qualifiedName)(/* arg_types */);"
        default:
            return "DROP \(keyword) \(ifExists)\(qualifiedName);"
        }
    }

    func alterStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String) -> String {
        "-- ALTER is not directly supported for this object. Consider using CREATE OR REPLACE."
    }

    func alterTableStatement(qualifiedName: String) -> String {
        """
        ALTER TABLE \(qualifiedName)
            ADD COLUMN new_column_name data_type;
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

    var supportsTruncateTable: Bool { true }
}
