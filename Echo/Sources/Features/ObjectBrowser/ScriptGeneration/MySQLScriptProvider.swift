import Foundation

struct MySQLScriptProvider: DatabaseScriptProvider {
    func quoteIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed.replacingOccurrences(of: "`", with: "``")
        return "`\(escaped)`"
    }

    func scriptActions(for objectType: SchemaObjectInfo.ObjectType) -> [DatabaseObjectRow.ScriptAction] {
        var actions: [DatabaseObjectRow.ScriptAction] = [.create]
        if objectType == .view {
            actions.append(.createOrReplace)
        }
        if objectType == .table {
            actions.append(.alterTable)
        } else {
            actions.append(.alter)
        }
        actions.append(.drop)
        switch objectType {
        case .table, .view, .materializedView:
            actions.append(.select)
            actions.append(.selectLimited(1000))
        case .function, .procedure:
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
            return "SELECT \(qualifiedName)(/* arguments */);"
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
        case .table, .view:
            let destination = qualifiedDestinationName(schema: object.schema, newName: effectiveName)
            return "RENAME TABLE \(qualifiedName) TO \(destination);"
        case .trigger:
            return "RENAME TRIGGER \(qualifiedName) TO \(quotedNewName);"
        case .function:
            return trimmedName == nil
                ? """
            -- MySQL cannot rename functions directly.
            -- Drop and recreate the function with the desired name.
            """
                : nil
        case .procedure:
            return trimmedName == nil
                ? """
            -- MySQL cannot rename procedures directly.
            -- Drop and recreate the procedure with the desired name.
            """
                : nil
        case .materializedView:
            return "-- Materialized views are not supported in MySQL."
        case .extension:
            return nil
        }
    }

    func dropStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String, includeIfExists: Bool, triggerTargetName: String) -> String {
        let ifExists = includeIfExists ? "IF EXISTS " : ""
        switch object.type {
        case .trigger:
            return "DROP TRIGGER \(ifExists)\(qualifiedName);"
        default:
            return "DROP \(keyword) \(ifExists)\(qualifiedName);"
        }
    }

    func alterStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String) -> String {
        switch object.type {
        case .function, .procedure:
            return "ALTER FUNCTION \(qualifiedName)\n    -- Update characteristics here;\n"
        case .trigger:
            return "ALTER TRIGGER \(qualifiedName)\n    -- Update trigger definition here;\n"
        default:
            return "ALTER \(keyword) \(qualifiedName)\n    -- Provide ALTER clauses here;\n"
        }
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
