import SwiftUI
import EchoSense

extension DatabaseObjectRow {
    internal func makeCreateTableScript(details: TableStructureDetails) -> String {
        let qualifiedTable = qualifiedName(schema: object.schema, name: object.name)
        
        var definitionLines = details.columns.map(columnDefinition)
        
        if let primaryKey = details.primaryKey {
            definitionLines.append(primaryKeyDefinition(primaryKey))
        }
        
        definitionLines.append(contentsOf: details.uniqueConstraints.map(uniqueConstraintDefinition))
        definitionLines.append(contentsOf: details.foreignKeys.map(foreignKeyDefinition))
        
        let body: String
        if definitionLines.isEmpty {
            body = ""
        } else {
            body = definitionLines.joined(separator: ",\n    ")
        }
        
        var script = "CREATE TABLE \(qualifiedTable)"
        if body.isEmpty {
            script += " (\n);\n"
        } else {
            script += " (\n    \(body)\n);"
        }
        
        let indexStatements = details.indexes
            .compactMap { indexStatement(for: $0, tableName: qualifiedTable) }
        
        if !indexStatements.isEmpty {
            script += "\n\n" + indexStatements.joined(separator: "\n")
        }
        
        return script
    }
    
    private func columnDefinition(_ column: TableStructureDetails.Column) -> String {
        var parts: [String] = [
            "\(quoteIdentifier(column.name)) \(column.dataType)"
        ]
        
        if let generated = generatedClause(for: column.generatedExpression) {
            parts.append(generated)
        }
        
        if let defaultClause = defaultClause(for: column.defaultValue) {
            parts.append(defaultClause)
        }
        
        if !column.isNullable {
            parts.append("NOT NULL")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func defaultClause(for value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.uppercased().hasPrefix("DEFAULT") {
            return raw
        }
        return "DEFAULT \(raw)"
    }
    
    private func generatedClause(for expression: String?) -> String? {
        guard let raw = expression?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.uppercased().hasPrefix("GENERATED") {
            return raw
        }
        return "GENERATED ALWAYS AS (\(raw))"
    }
    
    private func primaryKeyDefinition(_ primaryKey: TableStructureDetails.PrimaryKey) -> String {
        let columns = primaryKey.columns
            .map { quoteIdentifier($0) }
            .joined(separator: ", ")
        return "CONSTRAINT \(quoteIdentifier(primaryKey.name)) PRIMARY KEY (\(columns))"
    }
    
    private func uniqueConstraintDefinition(_ constraint: TableStructureDetails.UniqueConstraint) -> String {
        let columns = constraint.columns
            .map { quoteIdentifier($0) }
            .joined(separator: ", ")
        return "CONSTRAINT \(quoteIdentifier(constraint.name)) UNIQUE (\(columns))"
    }
    
    private func foreignKeyDefinition(_ foreignKey: TableStructureDetails.ForeignKey) -> String {
        let columns = foreignKey.columns
            .map { quoteIdentifier($0) }
            .joined(separator: ", ")
        let referencedColumns = foreignKey.referencedColumns
            .map { quoteIdentifier($0) }
            .joined(separator: ", ")
        let referencedTable = qualifiedName(
            schema: foreignKey.referencedSchema,
            name: foreignKey.referencedTable
        )
        
        var clause = "CONSTRAINT \(quoteIdentifier(foreignKey.name)) FOREIGN KEY (\(columns)) REFERENCES \(referencedTable) (\(referencedColumns))"
        
        if let onUpdate = foreignKey.onUpdate?.trimmingCharacters(in: .whitespacesAndNewlines),
           !onUpdate.isEmpty {
            clause += " ON UPDATE \(onUpdate)"
        }
        if let onDelete = foreignKey.onDelete?.trimmingCharacters(in: .whitespacesAndNewlines),
           !onDelete.isEmpty {
            clause += " ON DELETE \(onDelete)"
        }
        
        return clause
    }
    
    private func indexStatement(for index: TableStructureDetails.Index, tableName: String) -> String? {
        let sortedColumns = index.columns.sorted { $0.position < $1.position }
        guard !sortedColumns.isEmpty else { return nil }
        
        let columnClauses = sortedColumns.map { column in
            let sortKeyword = column.sortOrder == .descending ? "DESC" : "ASC"
            return "\(quoteIdentifier(column.name)) \(sortKeyword)"
        }.joined(separator: ", ")
        
        var statement = "CREATE "
        if index.isUnique {
            statement += "UNIQUE "
        }
        statement += "INDEX \(quoteIdentifier(index.name)) ON \(tableName) (\(columnClauses))"
        
        if let filter = index.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines),
           !filter.isEmpty {
            if filter.uppercased().hasPrefix("WHERE") {
                statement += " \(filter)"
            } else {
                statement += " WHERE \(filter)"
            }
        }
        
        statement += ";"
        return statement
    }
    
    internal func executeStatement() -> String {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        switch connection.databaseType {
        case .postgresql:
            if object.type == .procedure {
                return "CALL \(qualified)(/* arguments */);"
            } else {
                return "SELECT * FROM \(qualified)(/* arguments */);"
            }
        case .mysql:
            if object.type == .procedure {
                return "CALL \(qualified)(/* arguments */);"
            } else {
                return "SELECT \(qualified)(/* arguments */);"
            }
        case .microsoftSQL:
            if object.type == .function {
                return "SELECT * FROM \(qualified)(/* arguments */);"
            } else {
                return "EXEC \(qualified) /* arguments */;"
            }
        case .sqlite:
            return "-- Programmable object execution is not supported in SQLite."
        }
    }
    
    internal func truncateStatement() -> String {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL:
            return "TRUNCATE TABLE \(qualified);"
        case .sqlite:
            return "-- TRUNCATE TABLE is not supported in SQLite."
        }
    }
    
    internal func renameStatement(newName: String? = nil) -> String? {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = "<new_name>"
        let effectiveName = (trimmedName?.isEmpty ?? true) ? fallbackName : trimmedName!
        let quotedNewName = quoteIdentifier(effectiveName)
        
        switch connection.databaseType {
        case .postgresql:
            switch object.type {
            case .table:
                return "ALTER TABLE \(qualified) RENAME TO \(quotedNewName);"
            case .view:
                return "ALTER VIEW \(qualified) RENAME TO \(quotedNewName);"
            case .materializedView:
                return "ALTER MATERIALIZED VIEW \(qualified) RENAME TO \(quotedNewName);"
            case .function:
                return trimmedName == nil
                ? "ALTER FUNCTION \(qualified)(/* arg_types */) RENAME TO \(quotedNewName);"
                : nil
            case .procedure:
                return trimmedName == nil
                ? "ALTER PROCEDURE \(qualified)(/* arg_types */) RENAME TO \(quotedNewName);"
                : nil
            case .trigger:
                return "ALTER TRIGGER \(quoteIdentifier(object.name)) ON \(triggerTargetName()) RENAME TO \(quotedNewName);"
            }
            
        case .mysql:
            switch object.type {
            case .table, .view:
                let destination = qualifiedDestinationName(effectiveName)
                return "RENAME TABLE \(qualified) TO \(destination);"
            case .trigger:
                return "RENAME TRIGGER \(qualified) TO \(quotedNewName);"
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
            }
            
        case .sqlite:
            switch object.type {
            case .table:
                return "ALTER TABLE \(qualified) RENAME TO \(quotedNewName);"
            case .view:
                return """
            -- SQLite cannot rename views directly.
            -- Drop and recreate the view with the desired name.
            """
            case .trigger, .function, .procedure, .materializedView:
                return "-- Renaming is not supported for this object in SQLite."
            }
            
        case .microsoftSQL:
            let escaped = effectiveName.replacingOccurrences(of: "'", with: "''")
            return "EXEC sp_rename '\(qualifiedForStoredProcedures())', '\(escaped)';"
        }
    }
    
    internal func dropStatement(includeIfExists: Bool) -> String {
        let keyword = objectTypeKeyword()
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let ifExists = includeIfExists ? dropIfExistsClause() : ""
        
        switch connection.databaseType {
        case .postgresql:
            switch object.type {
            case .trigger:
                return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(quoteIdentifier(object.name)) ON \(triggerTargetName());"
            case .function, .procedure:
                return "DROP FUNCTION \(includeIfExists ? "IF EXISTS " : "")\(qualified)(/* arg_types */);"
            default:
                return "DROP \(keyword) \(ifExists)\(qualified);"
            }
        case .mysql:
            switch object.type {
            case .trigger:
                return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(qualified);"
            default:
                return "DROP \(keyword) \(includeIfExists ? "IF EXISTS " : "")\(qualified);"
            }
        case .sqlite:
            return "DROP \(keyword) \(ifExists)\(qualified);"
        case .microsoftSQL:
            switch object.type {
            case .trigger:
                return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(qualified) ON \(triggerTargetName());"
            default:
                return "DROP \(keyword) \(ifExists)\(qualified);"
            }
        }
    }
    
    private func dropIfExistsClause() -> String {
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL, .sqlite:
            return "IF EXISTS "
        }
    }
    
    private func qualifiedDestinationName(_ newName: String) -> String {
        let schema = object.schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let quotedNewName = quoteIdentifier(newName)
        guard !schema.isEmpty, connection.databaseType != .sqlite else {
            return quotedNewName
        }
        return "\(quoteIdentifier(schema)).\(quotedNewName)"
    }
    
    internal func objectTypeKeyword() -> String {
        switch object.type {
        case .table:
            return "TABLE"
        case .view:
            return "VIEW"
        case .materializedView:
            return "MATERIALIZED VIEW"
        case .function:
            return "FUNCTION"
        case .procedure:
            return "PROCEDURE"
        case .trigger:
            return "TRIGGER"
        }
    }

    internal func objectTypeDisplayName() -> String {
        switch object.type {
        case .table:
            return "Table"
        case .view:
            return "View"
        case .materializedView:
            return "Materialized View"
        case .function:
            return "Function"
        case .procedure:
            return "Procedure"
        case .trigger:
            return "Trigger"
        }
    }
    
    internal func qualifiedName(schema: String, name: String) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSchema.isEmpty || connection.databaseType == .sqlite {
            return quoteIdentifier(name)
        }
        return "\(quoteIdentifier(trimmedSchema)).\(quoteIdentifier(name))"
    }
    
    private func qualifiedForStoredProcedures() -> String {
        let trimmedSchema = object.schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSchema.isEmpty || connection.databaseType == .sqlite {
            return object.name
        }
        return "\(trimmedSchema).\(object.name)"
    }
    
    internal func quoteIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        switch connection.databaseType {
        case .mysql:
            let escaped = trimmed.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = trimmed.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        default:
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
    }
    
    internal func triggerTargetName() -> String {
        guard let triggerTable = object.triggerTable, !triggerTable.isEmpty else {
            return qualifiedName(schema: object.schema, name: "<table_name>")
        }
        if triggerTable.contains(".") {
            let parts = triggerTable.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                return qualifiedName(schema: String(parts[0]), name: String(parts[1]))
            }
        }
        return qualifiedName(schema: object.schema, name: triggerTable)
    }
}
