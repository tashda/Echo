//
//  EnvironmentState.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Observation
import SQLServerKit

@Observable @MainActor
final class EnvironmentState {

    enum StructureRefreshScope {
        case selectedDatabase
        case full
    }

    // MARK: - State
    var connectionStates: [UUID: ConnectionState] = [:]
    var pendingConnections: [PendingConnection] = []
    var sessionGroup = ActiveSessionGroup()
    var pinnedObjectIDs: [String] = []
    var recentConnections: [RecentConnectionRecord] = []
    var searchSidebarCaches: [SearchSidebarContextKey: SearchSidebarCache] = [:]
    var detachedJobQueueViewModels: [UUID: JobQueueViewModel] = [:]
    var dataInspectorContent: DataInspectorContent?
    @ObservationIgnored private var lastPushedInspectorTitle: String?
    private(set) var expandedConnectionFolderIDs: Set<UUID> = []

    func toggleDataInspector(content: DataInspectorContent, title: String, appState: AppState) {
        if appState.showInfoSidebar && lastPushedInspectorTitle == title {
            appState.showInfoSidebar = false
            dataInspectorContent = nil
            lastPushedInspectorTitle = nil
        } else {
            dataInspectorContent = content
            lastPushedInspectorTitle = title
            appState.showInfoSidebar = true
        }
    }
    var lastError: DatabaseError?
    var pendingProjectSwitch: Project?
    @ObservationIgnored let toastPresenter = StatusToastPresenter()
    @ObservationIgnored var notificationEngine: NotificationEngine?

    // MARK: - Dependencies
    @ObservationIgnored let projectStore: ProjectStore
    @ObservationIgnored let connectionStore: ConnectionStore
    @ObservationIgnored let navigationStore: NavigationStore
    @ObservationIgnored let tabStore: TabStore
    @ObservationIgnored let resultSpoolConfigCoordinator: ResultSpoolConfig
    @ObservationIgnored let diagramBuilder: DiagramBuilder
    @ObservationIgnored let identityRepository: IdentityRepository
    @ObservationIgnored let schemaDiscoveryEngine: MetadataDiscoveryEngine
    @ObservationIgnored let bookmarkRepository: BookmarkRepository
    @ObservationIgnored let historyRepository: HistoryRepository
    @ObservationIgnored private let clipboardHistory: ClipboardHistoryStore
    @ObservationIgnored let resultSpoolManager: ResultSpooler
    @ObservationIgnored let diagramCacheStore: DiagramCacheStore
    @ObservationIgnored let diagramKeyStore: DiagramEncryptionKeyStore

    @ObservationIgnored private var diagramRefreshTask: Task<Void, Never>?
    @ObservationIgnored internal var observedSessionIDs: Set<UUID> = []
    @ObservationIgnored private static let expandedConnectionFoldersKey = "expandedConnectionFoldersByProject"

    // MARK: - Initialization
    init(
        projectStore: ProjectStore,
        connectionStore: ConnectionStore,
        navigationStore: NavigationStore,
        tabStore: TabStore,
        clipboardHistory: ClipboardHistoryStore,
        resultSpoolConfigCoordinator: ResultSpoolConfig,
        diagramBuilder: DiagramBuilder,
        identityRepository: IdentityRepository,
        schemaDiscoveryEngine: MetadataDiscoveryEngine,
        bookmarkRepository: BookmarkRepository,
        historyRepository: HistoryRepository,
        resultSpoolManager: ResultSpooler,
        diagramCacheStore: DiagramCacheStore,
        diagramKeyStore: DiagramEncryptionKeyStore
    ) {
        self.projectStore = projectStore
        self.connectionStore = connectionStore
        self.navigationStore = navigationStore
        self.tabStore = tabStore
        self.clipboardHistory = clipboardHistory
        self.resultSpoolConfigCoordinator = resultSpoolConfigCoordinator
        self.diagramBuilder = diagramBuilder
        self.identityRepository = identityRepository
        self.schemaDiscoveryEngine = schemaDiscoveryEngine
        self.bookmarkRepository = bookmarkRepository
        self.historyRepository = historyRepository
        self.resultSpoolManager = resultSpoolManager
        self.diagramCacheStore = diagramCacheStore
        self.diagramKeyStore = diagramKeyStore

        self.tabStore.delegate = self
        setupBindings()
        loadRecentConnections()
    }

    private func setupBindings() {
        observeActiveSessionID()
        observeActiveSessions()
        observeSelectedProject()
    }

    private func observeActiveSessionID() {
        _ = withObservationTracking {
            sessionGroup.activeSessionID
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if let id = self.sessionGroup.activeSessionID,
                   let session = self.sessionGroup.activeSessions.first(where: { $0.id == id }) {
                    self.updateNavigation(for: session)
                } else {
                    self.updateNavigation(for: nil)
                }
                self.observeActiveSessionID()
            }
        }
    }

    private func observeActiveSessions() {
        _ = withObservationTracking {
            sessionGroup.activeSessions
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let sessions = self.sessionGroup.activeSessions
                let validIDs = Set(sessions.map { $0.id })

                // Prune tracked IDs for removed sessions
                self.observedSessionIDs = self.observedSessionIDs.intersection(validIDs)

                for session in sessions where !self.observedSessionIDs.contains(session.id) {
                    self.observedSessionIDs.insert(session.id)
                    Task { await self.enqueuePrefetchForSessionIfNeeded(session) }
                }

                self.observeActiveSessions()
            }
        }
    }

    private func observeSelectedProject() {
        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.loadExpandedConnectionFolders(for: self?.projectStore.selectedProject?.id)
                self?.setupBindings()
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

    // MARK: - Internal Connection Helpers

    internal func connectToNewSession(to connection: SavedConnection) {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil) else {
            lastError = .connectionFailed("Missing credentials")
            return
        }

        // Cancel/remove any existing pending for the same connection
        cancelAndRemovePending(for: connection.id)

        let pending = PendingConnection(connection: connection)
        pendingConnections.append(pending)
        connectionStates[connection.id] = .connecting

        let displayName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? connection.host
            : connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)

        pending.connectTask = Task {
            do {
                let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType)
                // MSSQL connects without a database — the server uses the login's default.
                // Other engines may specify a database in the connection string.
                let connectDatabase: String? = connection.databaseType == .microsoftSQL
                    ? nil
                    : (connection.database.isEmpty ? nil : connection.database)

                let session = try await factory!.connect(
                    host: connection.host,
                    port: connection.port,
                    database: connectDatabase,
                    tls: connection.useTLS,
                    trustServerCertificate: connection.trustServerCertificate,
                    tlsMode: connection.tlsMode,
                    sslRootCertPath: connection.sslRootCertPath,
                    sslCertPath: connection.sslCertPath,
                    sslKeyPath: connection.sslKeyPath,
                    mssqlEncryptionMode: connection.mssqlEncryptionMode,
                    readOnlyIntent: connection.readOnlyIntent,
                    authentication: credentials,
                    connectTimeoutSeconds: Int(connection.connectionTimeout)
                )

                guard !Task.isCancelled else {
                    await session.close()
                    return
                }

                let connectionSession = ConnectionSession(
                    connection: connection,
                    session: session,
                    spoolManager: resultSpoolManager
                )

                // Transition: pending → active session
                pendingConnections.removeAll { $0.id == connection.id }
                sessionGroup.addSession(connectionSession)
                connectionStates[connection.id] = .connected
                recordRecentConnection(for: connection, databaseName: connectionSession.selectedDatabaseName)
                startStructureLoadTask(for: connectionSession)
                notificationEngine?.post(category: .connectionConnected, message: "Connected to \(displayName)")
            } catch {
                guard !Task.isCancelled else { return }
                connectionStates[connection.id] = .disconnected
                lastError = DatabaseError.from(error)
                pending.phase = .failed(message: error.localizedDescription)
                let reason = error.localizedDescription
                notificationEngine?.post(category: .connectionFailed, message: "\(displayName): \(reason)", duration: 5.0)
            }
        }
    }

    internal func cancelAndRemovePending(for connectionID: UUID) {
        if let existing = pendingConnections.first(where: { $0.id == connectionID }) {
            existing.connectTask?.cancel()
        }
        pendingConnections.removeAll { $0.id == connectionID }
    }

    // MARK: - Recent Connections

    internal func loadRecentConnections() {
        let raw: [RecentConnectionRecord]
        if let projectID = projectStore.selectedProject?.id {
            raw = historyRepository.loadRecentConnections(forProjectID: projectID)
        } else {
            raw = historyRepository.loadRecentConnections()
        }
        // Deduplicate by identifier (connection + database + username) preserving order
        var seen = Set<String>()
        recentConnections = raw.filter { seen.insert($0.identifier).inserted }
    }

    private func saveRecentConnections() {
        // Merge current project's records back into the full store
        let currentProjectID = projectStore.selectedProject?.id
        var allRecords = historyRepository.loadRecentConnections()
        // Remove existing records for the current project
        allRecords.removeAll { $0.projectID == currentProjectID }
        // Add back the current in-memory records (which are project-filtered)
        allRecords.append(contentsOf: recentConnections)
        historyRepository.saveRecentConnections(allRecords)
    }

    internal func recordRecentConnection(for connection: SavedConnection, databaseName: String?) {
        let record = RecentConnectionRecord(
            id: connection.id,
            connectionName: connection.connectionName,
            host: connection.host,
            databaseName: databaseName,
            username: connection.username,
            databaseType: connection.databaseType,
            colorHex: connection.colorHex,
            lastUsedAt: Date(),
            projectID: connection.projectID ?? projectStore.selectedProject?.id
        )
        recentConnections.removeAll { $0.identifier == record.identifier }
        recentConnections.insert(record, at: 0)
        saveRecentConnections()
    }

    internal func removeRecentConnections(for connectionID: UUID) {
        recentConnections.removeAll { $0.id == connectionID }
        saveRecentConnections()
    }

    private func synchronizeRecentConnectionsWithConnections() {
        let existingIDs = Set(connectionStore.connections.map { $0.id })
        recentConnections.removeAll { !existingIDs.contains($0.id) }
        saveRecentConnections()
    }

    // MARK: - Computed Properties

    var hasActiveConnections: Bool {
        !sessionGroup.activeSessions.isEmpty
    }

    // MARK: - Private Helpers

    private func ensureDefaultProjectExists() async {
        if projectStore.projects.isEmpty {
            _ = try? await projectStore.createProject(name: "Default Project", colorHex: "007AFF", iconName: "folder.fill")
        }
    }

    private func migrateToProjects() async {
        // Migration logic
    }

    internal func loadExpandedConnectionFolders(for projectID: UUID?) {
        let storage = UserDefaults.standard.dictionary(forKey: Self.expandedConnectionFoldersKey) as? [String: [String]] ?? [:]
        let key = projectID?.uuidString ?? "global"
        let ids = storage[key]?.compactMap(UUID.init) ?? []
        expandedConnectionFolderIDs = Set(ids)
    }
}

// MARK: - TabStoreDelegate
extension EnvironmentState: TabStoreDelegate {
    func tabStore(_ store: TabStore, didAdd tab: WorkspaceTab) {
        if let session = sessionGroup.activeSessions.first(where: { $0.id == tab.connectionSessionID }) {
            if !session.queryTabs.contains(where: { $0.id == tab.id }) {
                session.queryTabs.append(tab)
            }
        }
    }

    func tabStore(_ store: TabStore, shouldClose tab: WorkspaceTab) async -> Bool {
        return true
    }

    func tabStore(_ store: TabStore, didRemoveTabID tabID: UUID) {
        for session in sessionGroup.activeSessions {
            if let index = session.queryTabs.firstIndex(where: { $0.id == tabID }) {
                session.queryTabs.remove(at: index)
            }
        }
    }

    func tabStore(_ store: TabStore, didSetActiveTabID tabID: UUID?) {
        guard let tabID, let tab = store.getTab(id: tabID) else { return }
        if sessionGroup.activeSessionID != tab.connectionSessionID {
            sessionGroup.setActiveSession(tab.connectionSessionID)
        }
    }

    func tabStoreDidReorderTabs(_ store: TabStore) {
        // No-op
    }
}
