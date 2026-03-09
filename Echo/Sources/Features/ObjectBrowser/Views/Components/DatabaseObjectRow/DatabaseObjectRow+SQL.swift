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
}
