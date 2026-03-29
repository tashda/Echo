import Foundation

enum SchemaDiagramDocumentationExporter {
    static func export(
        title: String,
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge],
        format: DiagramExportFormat
    ) -> String {
        let document = SchemaDiagramDocumentationDocument(
            title: title,
            tables: sortedTables(from: nodes),
            relationships: sortedRelationships(from: edges, nodes: nodes),
            generatedAt: Date()
        )

        switch format {
        case .htmlDocumentation:
            return renderHTML(document: document)
        case .markdownDocumentation:
            return renderMarkdown(document: document)
        case .textDocumentation:
            return renderText(document: document)
        case .sql:
            return SchemaDiagramForwardSQLExporter.export(title: title, nodes: nodes, edges: edges)
        case .png, .pdf:
            return ""
        }
    }

    private static func sortedTables(from nodes: [SchemaDiagramNodeModel]) -> [SchemaDiagramDocumentationTable] {
        nodes
            .map { node in
                SchemaDiagramDocumentationTable(
                    schema: node.schema,
                    name: node.name,
                    columns: node.columns.map {
                        SchemaDiagramDocumentationColumn(
                            name: $0.name,
                            dataType: $0.dataType,
                            isPrimaryKey: $0.isPrimaryKey,
                            isForeignKey: $0.isForeignKey
                        )
                    }
                )
            }
            .sorted {
                if $0.schema != $1.schema {
                    return $0.schema.localizedCaseInsensitiveCompare($1.schema) == .orderedAscending
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func sortedRelationships(
        from edges: [SchemaDiagramEdge],
        nodes: [SchemaDiagramNodeModel]
    ) -> [SchemaDiagramDocumentationRelationship] {
        let nodeNames = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, "\($0.schema).\($0.name)") })
        return edges
            .map {
                SchemaDiagramDocumentationRelationship(
                    fromTable: nodeNames[$0.fromNodeID] ?? $0.fromNodeID,
                    fromColumn: $0.fromColumn,
                    toTable: nodeNames[$0.toNodeID] ?? $0.toNodeID,
                    toColumn: $0.toColumn,
                    name: $0.relationshipName
                )
            }
            .sorted {
                if $0.fromTable != $1.fromTable {
                    return $0.fromTable.localizedCaseInsensitiveCompare($1.fromTable) == .orderedAscending
                }
                if $0.toTable != $1.toTable {
                    return $0.toTable.localizedCaseInsensitiveCompare($1.toTable) == .orderedAscending
                }
                return $0.fromColumn.localizedCaseInsensitiveCompare($1.fromColumn) == .orderedAscending
            }
    }

    private static func renderMarkdown(document: SchemaDiagramDocumentationDocument) -> String {
        let schemaCount = Set(document.tables.map(\.schema)).count
        var lines: [String] = [
            "# \(document.title)",
            "",
            "_Generated \(document.generatedAtString)_",
            "",
            "## Summary",
            "",
            "- Schemas: \(schemaCount)",
            "- Tables: \(document.tables.count)",
            "- Relationships: \(document.relationships.count)"
        ]

        if !document.relationships.isEmpty {
            lines += [
                "",
                "## Relationships",
                ""
            ]
            lines.append(contentsOf: document.relationships.map {
                "- \(escapeMarkdown($0.fromTable)).`\($0.fromColumn)` -> \(escapeMarkdown($0.toTable)).`\($0.toColumn)`" +
                ($0.name.map { " (\(escapeMarkdown($0)))" } ?? "")
            })
        }

        for table in document.tables {
            lines += [
                "",
                "## \(escapeMarkdown(table.schema)).\(escapeMarkdown(table.name))",
                "",
                "| Column | Type | Attributes |",
                "| --- | --- | --- |"
            ]
            lines.append(contentsOf: table.columns.map { column in
                "| \(escapeMarkdown(column.name)) | \(escapeMarkdown(column.dataType)) | \(escapeMarkdown(column.attributesText)) |"
            })
        }

        return lines.joined(separator: "\n")
    }

    private static func renderHTML(document: SchemaDiagramDocumentationDocument) -> String {
        let schemaCount = Set(document.tables.map(\.schema)).count
        var sections: [String] = [
            "<!DOCTYPE html>",
            "<html lang=\"en\">",
            "<head>",
            "<meta charset=\"utf-8\">",
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
            "<title>\(escapeHTML(document.title))</title>",
            "<style>",
            "body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',sans-serif;margin:32px;color:#1d1d1f;background:#fff;line-height:1.5}",
            "h1,h2{margin:0 0 12px}",
            "p,ul{margin:0 0 16px}",
            "table{border-collapse:collapse;width:100%;margin:0 0 24px}",
            "th,td{border:1px solid #d2d2d7;padding:8px 10px;text-align:left;vertical-align:top}",
            "th{background:#f5f5f7}",
            ".meta{color:#6e6e73}",
            ".badge{display:inline-block;padding:2px 6px;border-radius:999px;background:#f2f2f2;margin-right:6px;font-size:12px}",
            ".section{margin-top:28px}",
            "</style>",
            "</head>",
            "<body>",
            "<h1>\(escapeHTML(document.title))</h1>",
            "<p class=\"meta\">Generated \(escapeHTML(document.generatedAtString))</p>",
            "<div class=\"section\">",
            "<h2>Summary</h2>",
            "<ul>",
            "<li>Schemas: \(schemaCount)</li>",
            "<li>Tables: \(document.tables.count)</li>",
            "<li>Relationships: \(document.relationships.count)</li>",
            "</ul>",
            "</div>"
        ]

        if !document.relationships.isEmpty {
            sections += [
                "<div class=\"section\">",
                "<h2>Relationships</h2>",
                "<ul>"
            ]
            sections.append(contentsOf: document.relationships.map { relationship in
                let nameSuffix = relationship.name.map { " <span class=\"meta\">\(escapeHTML($0))</span>" } ?? ""
                return "<li><strong>\(escapeHTML(relationship.fromTable)).\(escapeHTML(relationship.fromColumn))</strong> &rarr; <strong>\(escapeHTML(relationship.toTable)).\(escapeHTML(relationship.toColumn))</strong>\(nameSuffix)</li>"
            })
            sections += [
                "</ul>",
                "</div>"
            ]
        }

        for table in document.tables {
            sections += [
                "<div class=\"section\">",
                "<h2>\(escapeHTML(table.schema)).\(escapeHTML(table.name))</h2>",
                "<table>",
                "<thead><tr><th>Column</th><th>Type</th><th>Attributes</th></tr></thead>",
                "<tbody>"
            ]
            sections.append(contentsOf: table.columns.map { column in
                "<tr><td>\(escapeHTML(column.name))</td><td>\(escapeHTML(column.dataType))</td><td>\(escapeHTML(column.attributesText))</td></tr>"
            })
            sections += [
                "</tbody>",
                "</table>",
                "</div>"
            ]
        }

        sections += [
            "</body>",
            "</html>"
        ]
        return sections.joined(separator: "\n")
    }

    private static func renderText(document: SchemaDiagramDocumentationDocument) -> String {
        let schemaCount = Set(document.tables.map(\.schema)).count
        var lines: [String] = [
            document.title,
            String(repeating: "=", count: document.title.count),
            "",
            "Generated \(document.generatedAtString)",
            "Schemas: \(schemaCount)",
            "Tables: \(document.tables.count)",
            "Relationships: \(document.relationships.count)"
        ]

        if !document.relationships.isEmpty {
            lines += [
                "",
                "Relationships",
                String(repeating: "-", count: "Relationships".count)
            ]
            lines.append(contentsOf: document.relationships.map {
                "\($0.fromTable).\($0.fromColumn) -> \($0.toTable).\($0.toColumn)" + ($0.name.map { " [\($0)]" } ?? "")
            })
        }

        for table in document.tables {
            lines += [
                "",
                "\(table.schema).\(table.name)",
                String(repeating: "-", count: table.schema.count + table.name.count + 1)
            ]
            lines.append(contentsOf: table.columns.map { column in
                "• \(column.name): \(column.dataType) (\(column.attributesText))"
            })
        }

        return lines.joined(separator: "\n")
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func escapeMarkdown(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "*", with: "\\*")
    }
}

private struct SchemaDiagramDocumentationDocument {
    let title: String
    let tables: [SchemaDiagramDocumentationTable]
    let relationships: [SchemaDiagramDocumentationRelationship]
    let generatedAt: Date

    var generatedAtString: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: generatedAt)
    }
}

private struct SchemaDiagramDocumentationTable {
    let schema: String
    let name: String
    let columns: [SchemaDiagramDocumentationColumn]
}

private struct SchemaDiagramDocumentationColumn {
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
    let isForeignKey: Bool

    var attributesText: String {
        var attributes: [String] = []
        if isPrimaryKey { attributes.append("Primary Key") }
        if isForeignKey { attributes.append("Foreign Key") }
        if attributes.isEmpty { attributes.append("Standard") }
        return attributes.joined(separator: ", ")
    }
}

private struct SchemaDiagramDocumentationRelationship {
    let fromTable: String
    let fromColumn: String
    let toTable: String
    let toColumn: String
    let name: String?
}
