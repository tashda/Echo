import Foundation

enum SchemaDiagramForwardEngineeringPlan {
    static func sql(
        title: String,
        nodes: [SchemaDiagramNodeModel],
        edges: [SchemaDiagramEdge]
    ) -> String {
        SchemaDiagramForwardSQLExporter.export(
            title: title,
            nodes: nodes,
            edges: edges
        )
    }

    static func targetDatabase(
        for databaseType: DatabaseType,
        context: SchemaDiagramContext?,
        fallbackDatabase: String?
    ) -> String? {
        switch databaseType {
        case .mysql:
            return normalized(context?.object.schema) ?? normalized(fallbackDatabase)
        case .postgresql, .sqlite:
            return normalized(fallbackDatabase)
        case .microsoftSQL:
            return nil
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
