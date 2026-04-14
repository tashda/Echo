import Foundation

enum SchemaDiagramModelExporter {
    static func export(
        title: String,
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge],
        layout: DiagramLayoutSnapshot
    ) -> String {
        let document = SchemaDiagramModelDocument(
            title: title,
            generatedAt: Date(),
            nodes: nodes
                .map { node in
                    SchemaDiagramModelNode(
                        schema: node.schema,
                        name: node.name,
                        columns: node.columns.map {
                            SchemaDiagramModelColumn(
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
                },
            edges: edges
                .map {
                    SchemaDiagramModelEdge(
                        fromNodeID: $0.fromNodeID,
                        fromColumn: $0.fromColumn,
                        toNodeID: $0.toNodeID,
                        toColumn: $0.toColumn,
                        relationshipName: $0.relationshipName
                    )
                }
                .sorted {
                    if $0.fromNodeID != $1.fromNodeID {
                        return $0.fromNodeID.localizedCaseInsensitiveCompare($1.fromNodeID) == .orderedAscending
                    }
                    if $0.toNodeID != $1.toNodeID {
                        return $0.toNodeID.localizedCaseInsensitiveCompare($1.toNodeID) == .orderedAscending
                    }
                    return $0.fromColumn.localizedCaseInsensitiveCompare($1.fromColumn) == .orderedAscending
                },
            layout: layout
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = (try? encoder.encode(document)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct SchemaDiagramModelDocument: Codable, Sendable {
    let title: String
    let generatedAt: Date
    let nodes: [SchemaDiagramModelNode]
    let edges: [SchemaDiagramModelEdge]
    let layout: DiagramLayoutSnapshot
}

private struct SchemaDiagramModelNode: Codable, Sendable {
    let schema: String
    let name: String
    let columns: [SchemaDiagramModelColumn]
}

private struct SchemaDiagramModelColumn: Codable, Sendable {
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
    let isForeignKey: Bool
}

private struct SchemaDiagramModelEdge: Codable, Sendable {
    let fromNodeID: String
    let fromColumn: String
    let toNodeID: String
    let toColumn: String
    let relationshipName: String?
}
