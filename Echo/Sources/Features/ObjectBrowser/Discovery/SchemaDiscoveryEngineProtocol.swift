import Foundation

@MainActor
protocol MetadataDiscoveryEngineProtocol: AnyObject, Sendable {
    func startStructureLoadTask(for session: ConnectionSession)
    func loadDatabaseStructureForSession(_ session: ConnectionSession) async throws -> DatabaseStructure
    func refreshStructure(for session: ConnectionSession, scope: EnvironmentState.StructureRefreshScope) async
    func preloadStructure(for connection: SavedConnection, overridePassword: String?) async
}
