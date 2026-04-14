import Foundation

struct MSSQLScriptProvider: DatabaseScriptProvider {
    func quoteIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let escaped = trimmed.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    func scriptActions(for objectType: SchemaObjectInfo.ObjectType) -> [ScriptAction] {
        var actions: [ScriptAction] = [.create, .alter, .dropIfExists]
        switch objectType {
        case .function, .procedure:
            actions.append(.execute)
        case .table, .view, .materializedView:
            actions.append(contentsOf: [.select, .selectLimited(1000)])
        case .trigger, .extension, .sequence, .type, .synonym:
            break
        }
        return actions
    }

    func executeStatement(for objectType: SchemaObjectInfo.ObjectType, qualifiedName: String) -> String {
        if objectType == .function {
            return "SELECT * FROM \(qualifiedName)(/* arguments */);"
        } else {
            return "EXEC \(qualifiedName) /* arguments */;"
        }
    }

    func truncateStatement(qualifiedName: String) -> String {
        "TRUNCATE TABLE \(qualifiedName);"
    }

    func renameStatement(for object: SchemaObjectInfo, qualifiedName: String, newName: String?) -> String? {
        let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmedName.flatMap({ $0.isEmpty ? nil : $0 }) ?? "<new_name>"
        let escaped = effectiveName.replacingOccurrences(of: "'", with: "''")
        return "EXEC sp_rename '\(qualifiedForStoredProcedures(schema: object.schema, name: object.name))', '\(escaped)';"
    }

    func dropStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String, includeIfExists: Bool, triggerTargetName: String) -> String {
        let ifExists = includeIfExists ? "IF EXISTS " : ""
        switch object.type {
        case .trigger:
            return "DROP TRIGGER \(ifExists)\(qualifiedName) ON \(triggerTargetName);"
        default:
            return "DROP \(keyword) \(ifExists)\(qualifiedName);"
        }
    }

    func alterStatement(for object: SchemaObjectInfo, qualifiedName: String, keyword: String) -> String {
        """
        ALTER \(keyword) \(qualifiedName)
        -- Update definition here.
        GO
        """
    }

    func alterTableStatement(qualifiedName: String) -> String {
        """
        ALTER TABLE \(qualifiedName)
            ADD new_column_name data_type;
        """
    }

    func selectStatement(qualifiedName: String, columnLines: String, limit: Int?, offset: Int) -> String {
        var statement = """
        SELECT
            \(columnLines)
        FROM \(qualifiedName)
        """
        if let limit {
            statement += """
            \nORDER BY (SELECT NULL)
            OFFSET \(offset) ROWS
            FETCH NEXT \(limit) ROWS ONLY
            """
        }
        statement += ";"
        return statement
    }

    var supportsTruncateTable: Bool { true }
}
