import Foundation

@MainActor
protocol DiagramCoordinatorProtocol: AnyObject, Sendable {
    func updateConfiguration(with settings: GlobalSettings) async
    func buildSchemaDiagram(for object: SchemaObjectInfo, projectID: UUID) async throws -> SchemaDiagramViewModel
    func hydrateCachedDiagram(from payload: DiagramCachePayload) -> SchemaDiagramViewModel
    func queueDiagramPrefetch(for object: SchemaObjectInfo, relatedKeys: [DiagramTableKey], projectID: UUID) async
    func handleDiagramSettingsChange(_ settings: GlobalSettings) async
    func persistDiagramLayout(for viewModel: SchemaDiagramViewModel) async
    func refreshDiagram(for viewModel: SchemaDiagramViewModel) async
}
