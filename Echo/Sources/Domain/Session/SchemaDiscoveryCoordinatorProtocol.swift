import Foundation

@MainActor
protocol SchemaDiscoveryCoordinatorProtocol: AnyObject, Sendable {
    func startStructureLoadTask(for session: ConnectionSession)
    func loadDatabaseStructureForSession(_ session: ConnectionSession) async throws -> DatabaseStructure
    func refreshStructure(for session: ConnectionSession, scope: WorkspaceSessionStore.StructureRefreshScope) async
    func preloadStructure(for connection: SavedConnection, overridePassword: String?) async
}
