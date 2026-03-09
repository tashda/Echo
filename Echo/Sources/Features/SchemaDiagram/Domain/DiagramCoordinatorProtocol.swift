import Foundation

struct DiagramTableKey: Hashable, Sendable {
    let schema: String
    let name: String
    
    var identifier: String {
        "\(schema).\(name)".lowercased()
    }
}

protocol DiagramSchemaProvider: Sendable {
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails
    var connectionID: UUID { get }
}

@MainActor
protocol DiagramCoordinatorProtocol {
    func buildSchemaDiagram(for object: SchemaObjectInfo, projectID: UUID) async throws -> SchemaDiagramViewModel
    func buildSchemaDiagram(for object: SchemaObjectInfo, session: any DiagramSchemaProvider, projectID: UUID, cacheKey: DiagramCacheKey?, progress: (@Sendable (String) -> Void)?, isPrefetch: Bool) async throws -> SchemaDiagramViewModel
    func hydrateCachedDiagram(from payload: DiagramCachePayload) -> SchemaDiagramViewModel
    func queueDiagramPrefetch(for object: SchemaObjectInfo, relatedKeys: [DiagramTableKey], projectID: UUID) async
    func persistDiagramLayout(for viewModel: SchemaDiagramViewModel) async
    func refreshDiagram(for viewModel: SchemaDiagramViewModel) async
}
