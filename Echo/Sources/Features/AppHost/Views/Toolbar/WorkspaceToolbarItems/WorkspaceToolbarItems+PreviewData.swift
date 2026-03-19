import SwiftUI
import EchoSense

#if DEBUG
@MainActor
struct WorkspaceToolbarPreviewData {
    enum Mode {
        case idle
        case refreshing
        case completed
    }

    let environmentState: EnvironmentState
    let appState: AppState
    let appearanceStore: AppearanceStore
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore
    let tabStore: TabStore

    init(mode: Mode) {
        let previewCacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("EchoPreviewResultCache", isDirectory: true)
        let spoolManager = ResultSpooler(configuration: ResultSpoolConfiguration.defaultConfiguration(rootDirectory: previewCacheRoot))
        let diagramCacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("EchoPreviewDiagramCache", isDirectory: true)
        let diagramManager = DiagramCacheStore(configuration: DiagramCacheStore.Configuration(rootDirectory: diagramCacheRoot))
        let diagramKeyStore = DiagramEncryptionKeyStore()
        Task {
            await diagramManager.updateKeyProvider { projectID in
                try await MainActor.run {
                    try diagramKeyStore.symmetricKey(forProjectID: projectID)
                }
            }
        }
        let projectStore = ProjectStore(repository: ProjectRepository(diskStore: ProjectDiskStore()))
        let connectionStore = ConnectionStore(repository: ConnectionRepository(
            connectionStore: ConnectionDiskStore(),
            folderStore: FolderDiskStore(),
            identityStore: IdentityDiskStore()
        ))
        let navigationStore = NavigationStore()
        let tabStore = TabStore()

        let environmentState = EnvironmentState(
            projectStore: projectStore,
            connectionStore: connectionStore,
            navigationStore: navigationStore,
            tabStore: tabStore,
            clipboardHistory: ClipboardHistoryStore(),
            resultSpoolConfigCoordinator: ResultSpoolConfig(spoolManager: spoolManager),
            diagramBuilder: DiagramBuilder(cacheManager: diagramManager, keyStore: diagramKeyStore),
            identityRepository: IdentityRepository(connectionStore: connectionStore),
            schemaDiscoveryEngine: MetadataDiscoveryEngine(identityRepository: IdentityRepository(connectionStore: connectionStore), connectionStore: connectionStore),
            bookmarkRepository: BookmarkRepository(),
            historyRepository: HistoryRepository(),
            resultSpoolManager: spoolManager,
            diagramCacheStore: diagramManager,
            diagramKeyStore: diagramKeyStore
        )
        let appState = AppState()
        let appearanceStore = AppearanceStore.shared
        appearanceStore.applyAppearanceMode(.light)

        let project = Project(name: "Preview Project", colorHex: "0A84FF", isDefault: true)
        projectStore.projects = [project]
        projectStore.selectedProject = project

        let connection = SavedConnection(
            connectionName: "Analytics",
            host: "db.preview.local",
            port: 5432,
            database: "analytics",
            username: "preview"
        )

        connectionStore.connections = [connection]
        connectionStore.selectedConnectionID = connection.id

        let previewSession = ConnectionSession(
            connection: connection,
            session: PreviewDatabaseSession(),
            defaultInitialBatchSize: 500,
            defaultBackgroundStreamingThreshold: 512,
            spoolManager: spoolManager
        )
        previewSession.databaseStructure = DatabaseStructure(
            serverVersion: "16.2",
            databases: [
                DatabaseInfo(
                    name: "analytics",
                    schemas: [
                        SchemaInfo(
                            name: "public",
                            objects: [
                                SchemaObjectInfo(name: "customers", schema: "public", type: .table),
                                SchemaObjectInfo(name: "orders", schema: "public", type: .table)
                            ]
                        )
                    ]
                )
            ]
        )

        environmentState.sessionGroup.addSession(previewSession)
        navigationStore.selectProject(project)
        navigationStore.navigationState.selectConnection(connection)
        navigationStore.navigationState.selectDatabase("analytics")

        switch mode {
        case .idle:
            previewSession.structureLoadingState = StructureLoadingState.idle
            previewSession.structureLoadingMessage = nil
        case .refreshing:
            previewSession.structureLoadingState = StructureLoadingState.loading(progress: 0.45)
            previewSession.structureLoadingMessage = "Updating tables\u{2026}"
        case .completed:
            previewSession.structureLoadingState = StructureLoadingState.ready
            previewSession.structureLoadingMessage = "Completed"
        }

        self.environmentState = environmentState
        self.appState = appState
        self.appearanceStore = appearanceStore
        self.projectStore = projectStore
        self.connectionStore = connectionStore
        self.navigationStore = navigationStore
        self.tabStore = tabStore
    }
}

final class PreviewDatabaseSession: DatabaseSession, @unchecked Sendable {
    func close() async {}

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        QueryResultSet(columns: [])
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        []
    }

    func listDatabases() async throws -> [String] {
        ["analytics"]
    }

    func listSchemas() async throws -> [String] {
        ["public"]
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        []
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        "-- preview definition"
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        0
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        TableStructureDetails()
    }
}
#endif
