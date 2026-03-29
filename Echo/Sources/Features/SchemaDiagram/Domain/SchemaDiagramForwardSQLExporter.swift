import Foundation

enum SchemaDiagramForwardSQLExporter {
    static func export(
        title: String,
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge]
    ) -> String {
        var lines: [String] = [
            "-- \(title)",
            "-- Generated \(timestamp())",
            "",
        ]

        let sortedNodes = nodes.sorted {
            if $0.schema != $1.schema {
                return $0.schema.localizedCaseInsensitiveCompare($1.schema) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        for (index, node) in sortedNodes.enumerated() {
            lines.append(createTableStatement(for: node))
            if index < sortedNodes.count - 1 || !edges.isEmpty {
                lines.append("")
            }
        }

        let sortedEdges = edges.sorted {
            if $0.fromNodeID != $1.fromNodeID {
                return $0.fromNodeID.localizedCaseInsensitiveCompare($1.fromNodeID) == .orderedAscending
            }
            if $0.toNodeID != $1.toNodeID {
                return $0.toNodeID.localizedCaseInsensitiveCompare($1.toNodeID) == .orderedAscending
            }
            return $0.fromColumn.localizedCaseInsensitiveCompare($1.fromColumn) == .orderedAscending
        }

        for (index, edge) in sortedEdges.enumerated() {
            lines.append(foreignKeyStatement(for: edge, nodes: sortedNodes))
            if index < sortedEdges.count - 1 {
                lines.append("")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func createTableStatement(for node: SchemaDiagramNodeModel) -> String {
        var definitions = node.columns.map { column in
            "  \(quotedIdentifier(column.name)) \(column.dataType)"
        }

        let primaryKeyColumns = node.columns
            .filter(\.isPrimaryKey)
            .map(\.name)
        if !primaryKeyColumns.isEmpty {
            definitions.append("  PRIMARY KEY (\(primaryKeyColumns.map(quotedIdentifier).joined(separator: ", ")))")
        }

        return [
            "CREATE TABLE \(qualifiedTableName(schema: node.schema, table: node.name)) (",
            definitions.joined(separator: ",\n"),
            ");",
        ].joined(separator: "\n")
    }

    private static func foreignKeyStatement(
        for edge: SchemaDiagramEdge,
        nodes: [SchemaDiagramNodeModel]
    ) -> String {
        let fromNode = nodes.first(where: { $0.id == edge.fromNodeID })
        let toNode = nodes.first(where: { $0.id == edge.toNodeID })
        let fromTable = qualifiedTableName(
            schema: fromNode?.schema ?? splitQualifiedName(edge.fromNodeID).schema,
            table: fromNode?.name ?? splitQualifiedName(edge.fromNodeID).table
        )
        let toTable = qualifiedTableName(
            schema: toNode?.schema ?? splitQualifiedName(edge.toNodeID).schema,
            table: toNode?.name ?? splitQualifiedName(edge.toNodeID).table
        )

        return """
        ALTER TABLE \(fromTable)
          ADD CONSTRAINT \(quotedIdentifier(constraintName(for: edge)))
          FOREIGN KEY (\(quotedIdentifier(edge.fromColumn)))
          REFERENCES \(toTable) (\(quotedIdentifier(edge.toColumn)));
        """
    }

    private static func splitQualifiedName(_ name: String) -> (schema: String, table: String) {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return ("", name)
    }

    private static func constraintName(for edge: SchemaDiagramEdge) -> String {
        if let relationshipName = edge.relationshipName, !relationshipName.isEmpty {
            return relationshipName
        }

        let rawName = [
            "fk",
            edge.fromNodeID,
            edge.fromColumn,
            edge.toNodeID,
            edge.toColumn,
        ].joined(separator: "_")

        return rawName.replacingOccurrences(
            of: #"[^A-Za-z0-9_]+"#,
            with: "_",
            options: .regularExpression
        )
    }

    private static func qualifiedTableName(schema: String, table: String) -> String {
        if schema.isEmpty {
            return quotedIdentifier(table)
        }
        return "\(quotedIdentifier(schema)).\(quotedIdentifier(table))"
    }

    private static func quotedIdentifier(_ identifier: String) -> String {
        "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
