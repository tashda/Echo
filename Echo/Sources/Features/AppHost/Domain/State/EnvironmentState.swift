//
//  EnvironmentState.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Combine
import SQLServerKit

@MainActor
final class EnvironmentState: ObservableObject {

    enum StructureRefreshScope {
        case selectedDatabase
        case full
    }

    // MARK: - Published State
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var sessionCoordinator = ActiveSessionCoordinator()
    @Published var pinnedObjectIDs: [String] = []
    @Published var recentConnections: [RecentConnectionRecord] = []
    @Published var searchSidebarCaches: [SearchSidebarContextKey: SearchSidebarCache] = [:]
    @Published var dataInspectorContent: DataInspectorContent?
    @Published private(set) var expandedConnectionFolderIDs: Set<UUID> = []
    @Published var lastError: DatabaseError?
    let toastCoordinator = StatusToastCoordinator()

    // MARK: - Dependencies
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let resultSpoolConfigCoordinator: ResultSpoolConfigCoordinator
    let diagramCoordinator: DiagramCoordinator
    let identityRepository: IdentityRepository
    let schemaDiscoveryCoordinator: MetadataDiscoveryCoordinator
    let bookmarkRepository: BookmarkRepository
    let historyRepository: HistoryRepository
    private let clipboardHistory: ClipboardHistoryStore
    let resultSpoolManager: ResultSpoolCoordinator
    let diagramCacheStore: DiagramCacheStore
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
        resultSpoolConfigCoordinator: ResultSpoolConfigCoordinator,
        diagramCoordinator: DiagramCoordinator,
        identityRepository: IdentityRepository,
        schemaDiscoveryCoordinator: MetadataDiscoveryCoordinator,
        bookmarkRepository: BookmarkRepository,
        historyRepository: HistoryRepository,
        resultSpoolManager: ResultSpoolCoordinator,
        diagramCacheStore: DiagramCacheStore,
        diagramKeyStore: DiagramEncryptionKeyStore
    ) {
        self.projectStore = projectStore
        self.connectionStore = connectionStore
        self.navigationStore = navigationStore
        self.tabStore = tabStore
        self.clipboardHistory = clipboardHistory
        self.resultSpoolConfigCoordinator = resultSpoolConfigCoordinator
        self.diagramCoordinator = diagramCoordinator
        self.identityRepository = identityRepository
        self.schemaDiscoveryCoordinator = schemaDiscoveryCoordinator
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
        toastCoordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        sessionCoordinator.$activeSessionID
            .sink { [weak self] id in
                guard let self else { return }
                if let id, let session = self.sessionCoordinator.activeSessions.first(where: { $0.id == id }) {
                    self.updateNavigation(for: session)
                } else {
                    self.updateNavigation(for: nil)
                }
            }
            .store(in: &cancellables)

        sessionCoordinator.$activeSessions
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

        _ = withObservationTracking {
            projectStore.selectedProject
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
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

    internal func connectToNewSession(to connection: SavedConnection) async {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil) else {
            lastError = .connectionFailed("Missing credentials")
            return
        }

        connectionStates[connection.id] = .connecting
        let displayName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? connection.host
            : connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType)
            let session = try await factory!.connect(
                host: connection.host,
                port: connection.port,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS,
                authentication: credentials,
                connectTimeoutSeconds: 10
            )

            let connectionSession = ConnectionSession(
                connection: connection,
                session: session,
                spoolManager: resultSpoolManager
            )

            sessionCoordinator.addSession(connectionSession)
            connectionStates[connection.id] = .connected
            recordRecentConnection(for: connection, databaseName: connectionSession.selectedDatabaseName)
            startStructureLoadTask(for: connectionSession)
            toastCoordinator.show(icon: "checkmark.circle.fill", message: "Connected to \(displayName)", style: .success)
        } catch {
            connectionStates[connection.id] = .disconnected
            lastError = DatabaseError.from(error)
            toastCoordinator.show(icon: "exclamationmark.triangle.fill", message: "Connection failed: \(displayName)", style: .error, duration: 5.0)
        }
    }

    // MARK: - Recent Connections

    internal func loadRecentConnections() {
        recentConnections = historyRepository.loadRecentConnections()
    }

    private func saveRecentConnections() {
        historyRepository.saveRecentConnections(recentConnections)
    }

    internal func recordRecentConnection(for connection: SavedConnection, databaseName: String?) {
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

    internal func removeRecentConnections(for connectionID: UUID) {
        recentConnections.removeAll { $0.id == connectionID }
        saveRecentConnections()
    }

    private func synchronizeRecentConnectionsWithConnections() {
        let existingIDs = Set(connectionStore.connections.map { $0.id })
        recentConnections.removeAll { !existingIDs.contains($0.id) }
        saveRecentConnections()
    }

    // MARK: - Private Helpers

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
}

// MARK: - TabStoreDelegate
extension EnvironmentState: TabStoreDelegate {
    func tabStore(_ store: TabStore, didAdd tab: WorkspaceTab) {
        if let session = sessionCoordinator.activeSessions.first(where: { $0.id == tab.connectionSessionID }) {
            if !session.queryTabs.contains(where: { $0.id == tab.id }) {
                session.queryTabs.append(tab)
            }
        }
    }

    func tabStore(_ store: TabStore, shouldClose tab: WorkspaceTab) async -> Bool {
        return true
    }

    func tabStore(_ store: TabStore, didRemoveTabID tabID: UUID) {
        for session in sessionCoordinator.activeSessions {
            if let index = session.queryTabs.firstIndex(where: { $0.id == tabID }) {
                session.queryTabs.remove(at: index)
            }
        }
    }

    func tabStore(_ store: TabStore, didSetActiveTabID tabID: UUID?) {
        guard let tabID, let tab = store.getTab(id: tabID) else { return }
        if sessionCoordinator.activeSessionID != tab.connectionSessionID {
            sessionCoordinator.setActiveSession(tab.connectionSessionID)
        }
    }

    func tabStoreDidReorderTabs(_ store: TabStore) {
        // No-op
    }
}
