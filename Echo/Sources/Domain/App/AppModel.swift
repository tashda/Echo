//
//  AppModel.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Combine
import SQLServerKit

@MainActor
final class AppModel: ObservableObject {

    enum StructureRefreshScope {
        case selectedDatabase
        case full
    }

    // MARK: - Published State
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var sessionManager = ConnectionSessionManager()
    @Published var pinnedObjectIDs: [String] = []
    @Published var recentConnections: [RecentConnectionRecord] = []
    @Published var searchSidebarCaches: [SearchSidebarContextKey: SearchSidebarCache] = [:]
    @Published var dataInspectorContent: DataInspectorContent?
    @Published private(set) var expandedConnectionFolderIDs: Set<UUID> = []
    @Published var lastError: DatabaseError?

    // MARK: - Dependencies
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let resultSpoolCoordinator: ResultSpoolCoordinator
    let diagramCoordinator: DiagramCoordinator
    let identityRepository: IdentityRepository
    let schemaDiscoveryCoordinator: SchemaDiscoveryCoordinator
    let bookmarkRepository: BookmarkRepository
    let historyRepository: HistoryRepository
    private let clipboardHistory: ClipboardHistoryStore
    let resultSpoolManager: ResultSpoolManager
    let diagramCacheManager: DiagramCacheManager
    let diagramKeyStore: DiagramEncryptionKeyStore
    
    private var diagramRefreshTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var sessionDatabaseCancellables: [UUID: AnyCancellable] = [:]
    private static let expandedConnectionFoldersKey = "expandedConnectionFoldersByProject"

    // MARK: - Initialization
    init(
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore,
        clipboardHistory: ClipboardHistoryStore,
        resultSpoolCoordinator: ResultSpoolCoordinator,
        diagramCoordinator: DiagramCoordinator,
        identityRepository: IdentityRepository,
        schemaDiscoveryCoordinator: SchemaDiscoveryCoordinator,
        bookmarkRepository: BookmarkRepository,
        historyRepository: HistoryRepository,
        resultSpoolManager: ResultSpoolManager,
        diagramCacheManager: DiagramCacheManager,
        diagramKeyStore: DiagramEncryptionKeyStore
    ) {
        self.projectStore = projectStore
        self.connectionStore = connectionStore
        self.navigationStore = navigationStore
        self.tabStore = tabStore
        self.clipboardHistory = clipboardHistory
        self.resultSpoolCoordinator = resultSpoolCoordinator
        self.diagramCoordinator = diagramCoordinator
        self.identityRepository = identityRepository
        self.schemaDiscoveryCoordinator = schemaDiscoveryCoordinator
        self.bookmarkRepository = bookmarkRepository
        self.historyRepository = historyRepository
        self.resultSpoolManager = resultSpoolManager
        self.diagramCacheManager = diagramCacheManager
        self.diagramKeyStore = diagramKeyStore
        
        self.tabStore.delegate = self
        setupBindings()
        loadRecentConnections()
    }

    private func setupBindings() {
        sessionManager.$activeSessionID
            .sink { [weak self] id in
                guard let self else { return }
                if let id, let session = self.sessionManager.activeSessions.first(where: { $0.id == id }) {
                    self.updateNavigation(for: session)
                } else {
                    self.updateNavigation(for: nil)
                }
            }
            .store(in: &cancellables)

        sessionManager.$activeSessions
            .sink { [weak self] sessions in
                guard let self else { return }
                let validIDs = sessions.map { $0.id }
                self.pruneSessionCancellables(validIDs: validIDs)

                for session in sessions where self.sessionDatabaseCancellables[session.id] == nil {
                    self.observeSession(session)
                    Task { await self.enqueuePrefetchForSessionIfNeeded(session) }
                }
            }
            .store(in: &cancellables)

        // Observation bridges for legacy compatibility during migration
        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
                self?.loadExpandedConnectionFolders(for: self?.projectStore.selectedProject?.id)
                self?.setupBindings() // Retrack
            }
        }
    }

    // MARK: - Lifecycle
    func load() async {
        await ensureDefaultProjectExists()
        await migrateToProjects()
        loadRecentConnections()
        loadExpandedConnectionFolders(for: projectStore.selectedProject?.id)
    }

    // MARK: - Session Management
    func connect(to connection: SavedConnection) async {
        await connectToNewSession(to: connection)
    }

    func disconnectSession(withID id: UUID) async {
        sessionManager.removeSession(withID: id)
    }

    private func connectToNewSession(to connection: SavedConnection) async {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil) else {
            lastError = .connectionFailed("Missing credentials")
            return
        }

        connectionStates[connection.id] = .connecting
        do {
            let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType)
            let session = try await factory!.connect(
                host: connection.host,
                port: connection.port,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS,
                authentication: credentials
            )

            let connectionSession = ConnectionSession(
                connection: connection,
                session: session,
                spoolManager: resultSpoolManager
            )
            
            sessionManager.addSession(connectionSession)
            connectionStates[connection.id] = .connected
            recordRecentConnection(for: connection, databaseName: connectionSession.selectedDatabaseName)
            startStructureLoadTask(for: connectionSession)
        } catch {
            connectionStates[connection.id] = .disconnected
            lastError = DatabaseError.from(error)
        }
    }

    func reconnectSession(_ session: ConnectionSession, to databaseName: String) async {
        // Implementation for database switching
    }

    // MARK: - Database Metadata
    func startStructureLoadTask(for session: ConnectionSession) {
        schemaDiscoveryCoordinator.startStructureLoadTask(for: session)
    }

    func refreshDatabaseStructure(for sessionID: UUID, scope: StructureRefreshScope = .selectedDatabase, databaseOverride: String? = nil) async {
        guard let session = sessionManager.activeSessions.first(where: { $0.id == sessionID }) else { return }
        await schemaDiscoveryCoordinator.refreshStructure(for: session, scope: scope)
    }

    func loadSchemaForDatabase(_ databaseName: String, connectionSession: ConnectionSession) async {
        await reconnectSession(connectionSession, to: databaseName)
    }

    // MARK: - Connection Management
    func upsertConnection(_ connection: SavedConnection, password: String?) async {
        var updated = connection
        if let password, !password.isEmpty {
            try? identityRepository.setPassword(password, for: &updated)
        }
        try? await connectionStore.updateConnection(updated)
        await preloadStructure(for: updated, overridePassword: password)
    }

    func deleteConnection(_ connection: SavedConnection) async {
        identityRepository.deletePassword(for: connection)
        try? await connectionStore.deleteConnection(connection)
        removeRecentConnections(for: connection.id)
    }

    func testConnection(_ connection: SavedConnection, passwordOverride: String? = nil) async -> ConnectionTestResult {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: passwordOverride) else {
            return ConnectionTestResult(isSuccessful: false, message: "Missing credentials", responseTime: nil, serverVersion: nil)
        }
        
        let startTime = Date()
        do {
            let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType)
            let session = try await factory!.connect(
                host: connection.host,
                port: connection.port,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS,
                authentication: credentials
            )
            let duration = Date().timeIntervalSince(startTime)
            try await session.close()
            return ConnectionTestResult(isSuccessful: true, message: "Success", responseTime: duration, serverVersion: nil)
        } catch {
            return ConnectionTestResult(isSuccessful: false, message: error.localizedDescription, responseTime: nil, serverVersion: nil)
        }
    }

    // MARK: - Tab Management
    func registerTab(_ tab: WorkspaceTab) {
        tabStore.addTab(tab)
    }

    func openQueryTab(for session: ConnectionSession? = nil, presetQuery: String? = nil, autoExecute: Bool = false) {
        let targetSession = session ?? sessionManager.activeSession ?? sessionManager.activeSessions.first
        guard let targetSession else { return }
        let tab = targetSession.addQueryTab(withQuery: presetQuery ?? "")
        registerTab(tab)
    }

    func openJobManagementTab(for session: ConnectionSession, selectJobID: String? = nil) {
        let tab = session.addJobManagementTab(selectJobID: selectJobID)
        registerTab(tab)
    }

    func openStructureTab(for session: ConnectionSession, object: SchemaObjectInfo, focus: TableStructureSection? = nil) {
        let tab = session.addStructureTab(for: object, focus: focus)
        registerTab(tab)
    }

    func openDiagramTab(for session: ConnectionSession, object: SchemaObjectInfo) {
        // Implementation
    }

    func duplicateTab(_ tab: WorkspaceTab) {
        // Implementation
    }

    // MARK: - Bookmarks
    func bookmarks(for connectionID: UUID) -> [Bookmark] {
        guard let project = projectStore.projects.first(where: { p in 
            p.id == (connectionStore.connections.first(where: { $0.id == connectionID })?.projectID ?? projectStore.selectedProject?.id)
        }) else { return [] }
        return bookmarkRepository.bookmarks(for: connectionID, in: project)
    }

    func addBookmark(for connection: SavedConnection, databaseName: String?, title: String?, query: String, source: Bookmark.Source) async {
        guard var project = projectStore.projects.first(where: { $0.id == (connection.projectID ?? projectStore.selectedProject?.id) }) else { return }
        let bookmark = Bookmark(connectionID: connection.id, databaseName: databaseName, title: title, query: query, source: source)
        bookmarkRepository.addBookmark(bookmark, to: &project)
        await projectStore.saveProject(project)
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        guard var project = projectStore.projects.first(where: { $0.id == (bookmark.connectionID) }) else { return }
        bookmarkRepository.removeBookmark(bookmark.id, from: &project)
        await projectStore.saveProject(project)
    }

    func renameBookmark(_ bookmark: Bookmark, to title: String?) async {
        guard var project = projectStore.projects.first(where: { $0.id == (bookmark.connectionID) }) else { return }
        bookmarkRepository.updateBookmark(bookmark.id, in: &project) { b in b.title = title }
        await projectStore.saveProject(project)
    }

    func copyBookmark(_ bookmark: Bookmark) {
        PlatformClipboard.copy(bookmark.query)
    }

    // MARK: - Recent Connections
    private func loadRecentConnections() {
        recentConnections = historyRepository.loadRecentConnections()
    }

    private func saveRecentConnections() {
        historyRepository.saveRecentConnections(recentConnections)
    }

    private func recordRecentConnection(for connection: SavedConnection, databaseName: String?) {
        let record = RecentConnectionRecord(
            id: connection.id,
            connectionName: connection.connectionName,
            host: connection.host,
            databaseName: databaseName,
            databaseType: connection.databaseType,
            colorHex: connection.colorHex,
            lastUsedAt: Date()
        )
        recentConnections.removeAll { $0.id == record.id }
        recentConnections.insert(record, at: 0)
        saveRecentConnections()
    }

    private func removeRecentConnections(for connectionID: UUID) {
        recentConnections.removeAll { $0.id == connectionID }
        saveRecentConnections()
    }

    private func synchronizeRecentConnectionsWithConnections() {
        let existingIDs = Set(connectionStore.connections.map { $0.id })
        recentConnections.removeAll { !existingIDs.contains($0.id) }
        saveRecentConnections()
    }

    // MARK: - Helpers
    func updateNavigation(for session: ConnectionSession?) {
        if let session {
            navigationStore.navigationState.selectConnection(session.connection)
            if let db = session.selectedDatabaseName {
                navigationStore.navigationState.selectDatabase(db)
            }
        } else {
            // navigationStore.navigationState.selectedConnection = nil // Use a proper method if selectConnection doesn't handle nil
        }
    }

    func persistConnections() async {
        try? await connectionStore.saveConnections()
    }

    func enqueuePrefetchForSessionIfNeeded(_ session: ConnectionSession) async {
        await diagramCoordinator.scheduleRelatedPrefetch(
            session: session,
            baseKey: DiagramTableKey(schema: session.connection.database, name: ""), // Needs better logic
            relatedKeys: [],
            projectID: session.connection.projectID ?? projectStore.selectedProject?.id ?? UUID()
        )
    }

    private func pruneSessionCancellables(validIDs: [UUID]) {
        for (id, cancellable) in sessionDatabaseCancellables where !validIDs.contains(id) {
            cancellable.cancel()
            sessionDatabaseCancellables.removeValue(forKey: id)
        }
    }

    private func observeSession(_ session: ConnectionSession) {
        let cancellable = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        sessionDatabaseCancellables[session.id] = cancellable
    }

    private func ensureDefaultProjectExists() async {
        if projectStore.projects.isEmpty {
            _ = try? await projectStore.createProject(name: "Default Project", colorHex: "007AFF", iconName: "folder.fill")
        }
    }

    private func migrateToProjects() async {
        // Migration logic
    }

    private func loadExpandedConnectionFolders(for projectID: UUID?) {
        let storage = UserDefaults.standard.dictionary(forKey: Self.expandedConnectionFoldersKey) as? [String: [String]] ?? [:]
        let key = projectID?.uuidString ?? "global"
        let ids = storage[key]?.compactMap(UUID.init) ?? []
        expandedConnectionFolderIDs = Set(ids)
    }

    func preloadStructure(for connection: SavedConnection, overridePassword: String? = nil) async {
        await schemaDiscoveryCoordinator.preloadStructure(for: connection, overridePassword: overridePassword)
    }
}

// MARK: - TabStoreDelegate
extension AppModel: TabStoreDelegate {
    func tabStore(_ store: TabStore, didAdd tab: WorkspaceTab) {
        if let session = sessionManager.activeSessions.first(where: { $0.id == tab.connectionSessionID }) {
            if !session.queryTabs.contains(where: { $0.id == tab.id }) {
                session.queryTabs.append(tab)
            }
        }
    }
    
    func tabStore(_ store: TabStore, shouldClose tab: WorkspaceTab) async -> Bool {
        return true
    }
    
    func tabStore(_ store: TabStore, didRemoveTabID tabID: UUID) {
        for session in sessionManager.activeSessions {
            if let index = session.queryTabs.firstIndex(where: { $0.id == tabID }) {
                session.queryTabs.remove(at: index)
            }
        }
    }
    
    func tabStore(_ store: TabStore, didSetActiveTabID tabID: UUID?) {
        guard let tabID, let tab = store.getTab(id: tabID) else { return }
        if sessionManager.activeSessionID != tab.connectionSessionID {
            sessionManager.setActiveSession(tab.connectionSessionID)
        }
    }
    
    func tabStoreDidReorderTabs(_ store: TabStore) {
        // No-op
    }
}
