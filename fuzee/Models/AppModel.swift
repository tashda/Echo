//
//  AppModel.swift
//  fuzee
//
//  Created by Kenneth Berg on 15/09/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {

    // MARK: - Published State
    @Published var connections: [SavedConnection] = []
    @Published var selectedConnectionID: UUID?
    @Published var folders: [SavedFolder] = []
    @Published var identities: [SavedIdentity] = []
    @Published var selectedFolderID: UUID?
    @Published var selectedIdentityID: UUID?
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var sessionManager = ConnectionSessionManager()
    @Published var tabManager = TabManager()
    @Published var pinnedObjectIDs: [String] = []

    // MARK: - Dependencies
    private let store = ConnectionStore()
    private let folderStore = FolderStore()
    private let identityStore = IdentityStore()
    private let keychain = KeychainHelper()
    private let dbFactory = PostgresNIOFactory()
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Computed helpers
    var selectedConnection: SavedConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }

    // MARK: - Initialization
    init() {
        sessionManager.$activeSessionID
            .sink { [weak self] id in
                guard let self, let id else { return }
                if let session = self.sessionManager.activeSessions.first(where: { $0.id == id }) {
                    self.selectedConnectionID = session.connection.id
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence
    func load() async {
        do {
            async let connectionsTask = store.load()
            async let foldersTask = folderStore.load()
            async let identitiesTask = identityStore.load()

            let (loadedConnections, loadedFolders, loadedIdentities) = try await (
                connectionsTask,
                foldersTask,
                identitiesTask
            )

            connections = loadedConnections
            folders = loadedFolders
            identities = loadedIdentities

            if selectedConnectionID == nil {
                selectedConnectionID = connections.first?.id
            }
            if selectedFolderID == nil {
                selectedFolderID = folders.first(where: { $0.kind == .connections })?.id
            }
            if selectedIdentityID == nil {
                selectedIdentityID = identities.first?.id
            }
        } catch {
            print("Failed to load connections: \(error)")
        }
    }

    func upsertConnection(_ connection: SavedConnection, password: String?) async {
        var updated = connection
        let existing = connections.first(where: { $0.id == updated.id })

        switch updated.credentialSource {
        case .manual:
            if let password, !password.isEmpty {
                if updated.keychainIdentifier == nil {
                    updated.keychainIdentifier = "fuzee.\(updated.id.uuidString)"
                }
                if let identifier = updated.keychainIdentifier {
                    do {
                        try keychain.setPassword(password, account: identifier)
                    } catch {
                        print("Keychain set failed: \(error)")
                    }
                }
            } else if updated.keychainIdentifier == nil, let existingIdentifier = existing?.keychainIdentifier {
                updated.keychainIdentifier = existingIdentifier
            }

            updated.identityID = nil

        case .identity:
            updated.keychainIdentifier = nil
            if let identifier = existing?.keychainIdentifier, existing?.credentialSource == .manual {
                try? keychain.deletePassword(account: identifier)
            }

            if let identityID = updated.identityID,
               let identity = identities.first(where: { $0.id == identityID }) {
                updated.username = identity.username
            } else {
                updated.identityID = nil
            }

        case .inherit:
            updated.identityID = nil
            updated.keychainIdentifier = nil
            if let identifier = existing?.keychainIdentifier, existing?.credentialSource == .manual {
                try? keychain.deletePassword(account: identifier)
            }
        }

        if let index = connections.firstIndex(where: { $0.id == updated.id }) {
            if updated.cachedStructure == nil {
                updated.cachedStructure = connections[index].cachedStructure
                updated.cachedStructureUpdatedAt = connections[index].cachedStructureUpdatedAt
            }
            connections[index] = updated
        } else {
            connections.append(updated)
        }

        await persistConnections()
    }

    func deleteConnection(id: UUID) async {
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        await deleteConnection(connection)
    }

    func deleteConnection(_ connection: SavedConnection) async {
        if let identifier = connection.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }

        connections.removeAll { $0.id == connection.id }
        connectionStates.removeValue(forKey: connection.id)

        if let session = sessionManager.sessionForConnection(connection.id) {
            await session.session.close()
            sessionManager.removeSession(withID: session.id)
        }

        if selectedConnectionID == connection.id {
            selectedConnectionID = connections.first?.id
        }

        await persistConnections()
    }

    private func persistConnections() async {
        do {
            try await store.save(connections)
        } catch {
            print("Failed to persist connections: \(error)")
        }
    }

    private func persistFolders() async {
        do {
            try await folderStore.save(folders)
        } catch {
            print("Failed to persist folders: \(error)")
        }
    }

    private func persistIdentities() async {
        do {
            try await identityStore.save(identities)
        } catch {
            print("Failed to persist identities: \(error)")
        }
    }

    func upsertIdentity(_ identity: SavedIdentity, password: String?) async {
        var updated = identity

        if let password, !password.isEmpty {
            if updated.keychainIdentifier == nil {
                updated.keychainIdentifier = "fuzee.identity.\(updated.id.uuidString)"
            }
            if let identifier = updated.keychainIdentifier {
                do {
                    try keychain.setPassword(password, account: identifier)
                } catch {
                    print("Failed to save identity password: \(error)")
                }
            }
        }

        if let index = identities.firstIndex(where: { $0.id == updated.id }) {
            updated.createdAt = identities[index].createdAt
            updated.updatedAt = Date()
            identities[index] = updated
        } else {
            identities.append(updated)
        }

        if let folderID = updated.folderID,
           let folder = folders.first(where: { $0.id == folderID }),
           folder.kind != .identities {
            if let idx = identities.firstIndex(where: { $0.id == updated.id }) {
                identities[idx].folderID = nil
            }
        }

        await persistIdentities()
        await synchronizeConnections(forIdentityID: updated.id, using: updated)
    }

    func deleteIdentity(_ identity: SavedIdentity) async {
        if let identifier = identity.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }

        identities.removeAll { $0.id == identity.id }
        await persistIdentities()

        var connectionsChanged = false
        for index in connections.indices {
            if connections[index].credentialSource == .identity && connections[index].identityID == identity.id {
                connections[index].credentialSource = .manual
                connections[index].identityID = nil
                connections[index].username = ""
                connections[index].keychainIdentifier = nil
                connectionsChanged = true
            }
        }

        if connectionsChanged {
            await persistConnections()
        }

        var foldersChanged = false
        for index in folders.indices {
            if folders[index].credentialMode == .identity && folders[index].identityID == identity.id {
                folders[index].credentialMode = .none
                folders[index].identityID = nil
                foldersChanged = true
            }
        }

        if foldersChanged {
            await persistFolders()
        }

        if selectedIdentityID == identity.id {
            selectedIdentityID = identities.first?.id
        }
    }

    func upsertFolder(_ folder: SavedFolder) async {
        var updated = folder

        if updated.credentialMode == .identity && updated.identityID == nil {
            updated.credentialMode = .none
        }

        if updated.credentialMode == .inherit && updated.parentFolderID == nil {
            updated.credentialMode = .none
        }

        if updated.kind == .identities && updated.credentialMode == .inherit {
            updated.credentialMode = .none
        }

        if let parentID = updated.parentFolderID,
           let parent = folders.first(where: { $0.id == parentID }) {
            if parent.kind != updated.kind {
                updated.parentFolderID = nil
                if updated.credentialMode == .inherit {
                    updated.credentialMode = .none
                }
            }
        }

        if let index = folders.firstIndex(where: { $0.id == updated.id }) {
            updated.createdAt = folders[index].createdAt
            folders[index] = updated
        } else {
            folders.append(updated)
        }

        await persistFolders()
    }

    func deleteFolder(_ folder: SavedFolder) async {
        let allFolderIDs = descendantFolderIDs(of: folder.id) + [folder.id]

        if folder.kind == .connections {
            var connectionsChanged = false
            for index in connections.indices {
                if let folderID = connections[index].folderID, allFolderIDs.contains(folderID) {
                    connections[index].folderID = nil
                    if connections[index].credentialSource == .inherit {
                        connections[index].credentialSource = .manual
                        connections[index].username = ""
                        connections[index].keychainIdentifier = nil
                    }
                    connectionsChanged = true
                }
            }

            if connectionsChanged {
                await persistConnections()
            }
        }

        if folder.kind == .identities {
            var identitiesChanged = false
            for index in identities.indices {
                if let assignedFolderID = identities[index].folderID, allFolderIDs.contains(assignedFolderID) {
                    identities[index].folderID = nil
                    identitiesChanged = true
                }
            }

            if identitiesChanged {
                await persistIdentities()
            }
        }

        folders.removeAll { allFolderIDs.contains($0.id) }
        await persistFolders()

        if let selectedFolderID, allFolderIDs.contains(selectedFolderID) {
            self.selectedFolderID = folders.first(where: { $0.kind == .connections })?.id
        }
    }

    func moveConnection(_ connectionID: UUID, toFolder targetFolderID: UUID?) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else { return }

        if connections[index].folderID == targetFolderID { return }

        connections[index].folderID = targetFolderID

        if targetFolderID == nil, connections[index].credentialSource == .inherit {
            connections[index].credentialSource = .manual
            connections[index].identityID = nil
        }

        Task { await persistConnections() }
    }

    func moveFolder(_ folderID: UUID, toParent parentID: UUID?) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else { return }

        if folderID == parentID { return }

        if let parentID, descendantFolderIDs(of: folderID).contains(parentID) { return }

        if let parentID,
           let parent = folders.first(where: { $0.id == parentID }),
           parent.kind != folders[folderIndex].kind {
            return
        }

        folders[folderIndex].parentFolderID = parentID

        if parentID == nil, folders[folderIndex].credentialMode == .inherit {
            folders[folderIndex].credentialMode = .none
        }

        Task { await persistFolders() }
    }

    private func identity(withID id: UUID?) -> SavedIdentity? {
        guard let id else { return nil }
        return identities.first { $0.id == id }
    }

    private func folder(withID id: UUID?) -> SavedFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    private func resolvedIdentity(forFolderID folderID: UUID, visited: Set<UUID> = []) -> SavedIdentity? {
        guard !visited.contains(folderID), let folder = folder(withID: folderID) else {
            return nil
        }

        switch folder.credentialMode {
        case .none:
            return nil
        case .identity:
            return identity(withID: folder.identityID)
        case .inherit:
            guard let parentID = folder.parentFolderID else { return nil }
            var updatedVisited = visited
            updatedVisited.insert(folderID)
            return resolvedIdentity(forFolderID: parentID, visited: updatedVisited)
        }
    }

    private func resolvedCredentials(for connection: SavedConnection, overridePassword: String? = nil) -> (username: String, password: String?)? {
        switch connection.credentialSource {
        case .manual:
            return (
                connection.username,
                overridePassword ?? connection.keychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
            )
        case .identity:
            guard let identity = identity(withID: connection.identityID) else { return nil }
            let password = overridePassword ?? identity.keychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
            return (identity.username, password)
        case .inherit:
            guard let folderID = connection.folderID,
                  let identity = resolvedIdentity(forFolderID: folderID) else {
                return nil
            }
            let password = overridePassword ?? identity.keychainIdentifier.flatMap { try? keychain.getPassword(account: $0) }
            return (identity.username, password)
        }
    }

    func folderIdentity(for folderID: UUID) -> SavedIdentity? {
        resolvedIdentity(forFolderID: folderID)
    }

    private func synchronizeConnections(forIdentityID identityID: UUID, using identity: SavedIdentity) async {
        var connectionsChanged = false
        for index in connections.indices {
            if connections[index].credentialSource == .identity && connections[index].identityID == identityID {
                if connections[index].username != identity.username {
                    connections[index].username = identity.username
                    connectionsChanged = true
                }
            }
        }

        if connectionsChanged {
            await persistConnections()
        }
    }

    private func descendantFolderIDs(of folderID: UUID) -> [UUID] {
        guard let root = folders.first(where: { $0.id == folderID }) else { return [] }
        return descendantFolderIDs(of: folderID, kind: root.kind)
    }

    private func descendantFolderIDs(of folderID: UUID, kind: FolderKind) -> [UUID] {
        var ids: [UUID] = []
        for folder in folders where folder.parentFolderID == folderID && folder.kind == kind {
            ids.append(folder.id)
            ids.append(contentsOf: descendantFolderIDs(of: folder.id, kind: kind))
        }
        return ids
    }

    // MARK: - Session lifecycle
    func connect(to connection: SavedConnection) async {
        await connectToNewSession(to: connection)
    }

    func connectToNewSession(
        to connection: SavedConnection,
        forceReconnect: Bool = false,
        reuseSessionID: UUID? = nil,
        previousSession: ConnectionSession? = nil
    ) async {
        connectionStates[connection.id] = .connecting

        var priorSession: ConnectionSession?
        if let existing = sessionManager.sessionForConnection(connection.id) {
            if forceReconnect {
                priorSession = existing
                await existing.session.close()
                sessionManager.removeSession(withID: existing.id)
            } else {
                sessionManager.setActiveSession(existing.id)
                selectedConnectionID = existing.connection.id
                connectionStates[connection.id] = .connected
                return
            }
        }

        do {
            guard let credentials = resolvedCredentials(for: connection) else {
                throw DatabaseError.connectionFailed("Credentials not configured")
            }

            var resolvedConnection = connection
            resolvedConnection.username = credentials.username

            let databaseSession = try await dbFactory.connect(
                host: resolvedConnection.host,
                port: resolvedConnection.port,
                username: credentials.username,
                password: credentials.password,
                database: resolvedConnection.database.isEmpty ? nil : resolvedConnection.database,
                tls: resolvedConnection.useTLS
            )

            let session = ConnectionSession(
                id: reuseSessionID ?? UUID(),
                connection: resolvedConnection,
                session: databaseSession
            )

            session.selectedDatabaseName = resolvedConnection.database.isEmpty ? nil : resolvedConnection.database

            if let cached = resolvedConnection.cachedStructure {
                session.databaseStructure = cached
                session.structureLoadingState = .ready
            } else if let previousStructure = previousSession?.databaseStructure ?? priorSession?.databaseStructure {
                session.databaseStructure = previousStructure
                session.structureLoadingState = previousSession?.structureLoadingState ?? priorSession?.structureLoadingState ?? .idle
            } else {
                session.databaseStructure = DatabaseStructure(databases: [])
                session.structureLoadingState = .loading(progress: nil)
            }

            sessionManager.addSession(session)
            sessionManager.setActiveSession(session.id)
            selectedConnectionID = resolvedConnection.id
            connectionStates[resolvedConnection.id] = .connected

            Task {
                do {
                    let structure = try await loadDatabaseStructureForSession(session)
                    await MainActor.run {
                        session.databaseStructure = structure
                        session.structureLoadingState = .ready
                        cacheStructure(structure, for: session.connection.id)
                    }
                } catch {
                    await MainActor.run {
                        session.structureLoadingState = .failed(message: error.localizedDescription)
                    }
                    print("Failed to load database structure: \(error)")
                }
            }
        } catch {
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            print("Connection failed: \(error)")
        }
    }

    func reconnectSession(_ session: ConnectionSession, to databaseName: String) async {
        guard session.selectedDatabaseName != databaseName else { return }
        var baseConnection = session.connection
        baseConnection.database = databaseName
        await connectToNewSession(
            to: baseConnection,
            forceReconnect: true,
            reuseSessionID: session.id,
            previousSession: session
        )
        updateCachedConnection(id: baseConnection.id) { connection in
            connection.database = databaseName
        }
    }

    func disconnect() async {
        for session in sessionManager.activeSessions {
            await session.session.close()
            connectionStates[session.connection.id] = .disconnected
        }
        sessionManager.activeSessions.removeAll()
    }

    func disconnectSession(withID sessionID: UUID) async {
        guard let session = sessionManager.activeSessions.first(where: { $0.id == sessionID }) else { return }
        await session.session.close()
        sessionManager.removeSession(withID: sessionID)
        connectionStates[session.connection.id] = .disconnected
    }

    // MARK: - Queries
    func executeQuery(_ sql: String) async throws -> QueryResultSet {
        guard let session = sessionManager.activeSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        return try await session.session.simpleQuery(sql)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        guard let session = sessionManager.activeSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        return try await session.session.executeUpdate(sql)
    }

    func listTables() async throws -> [String] {
        guard let session = sessionManager.activeSession else {
            throw DatabaseError.connectionFailed("No active connection")
        }
        let objects = try await session.session.listTablesAndViews(schema: "public")
        return objects.map { $0.name }
    }

    // MARK: - Database Metadata
    func loadDatabaseStructureForSession(_ connectionSession: ConnectionSession) async throws -> DatabaseStructure {
        await MainActor.run {
            connectionSession.structureLoadingState = .loading(progress: nil)
        }

        do {
            var databaseInfos: [DatabaseInfo] = []
            var databases: [String] = []

            let explicit = connectionSession.connection.database
            if !explicit.isEmpty {
                databases = [explicit]
            } else {
                databases = try await connectionSession.session.listDatabases()
            }

            if databases.isEmpty {
                if !explicit.isEmpty {
                    databases = [explicit]
                }
            }

            let totalDatabases = max(databases.count, 1)
            let cachedStructure = connectionSession.connection.cachedStructure ?? connectionSession.databaseStructure

            for (databaseIndex, databaseName) in databases.enumerated() {
                let shouldLoadSchema = (databaseName == connectionSession.selectedDatabaseName) ||
                    (connectionSession.selectedDatabaseName == nil && databaseIndex == 0) ||
                    (databases.count == 1)

                if shouldLoadSchema {
                    await MainActor.run {
                        if connectionSession.selectedDatabaseName == nil {
                            connectionSession.selectedDatabaseName = databaseName
                        }
                    }

                    let schemaNames = try await connectionSession.session.listSchemas()
                    var schemas: [SchemaInfo] = []

                    for (schemaIndex, schemaName) in schemaNames.enumerated() {
                        let objects = try await connectionSession.session.listTablesAndViews(schema: schemaName)
                        if !objects.isEmpty {
                            schemas.append(SchemaInfo(name: schemaName, objects: objects))
                        }

                        let progress = structureLoadProgress(
                            databaseIndex: databaseIndex,
                            schemaIndex: schemaIndex + 1,
                            totalDatabases: totalDatabases,
                            totalSchemas: max(schemaNames.count, 1)
                        )
                        await MainActor.run {
                            connectionSession.structureLoadingState = .loading(progress: progress)
                        }
                    }

                    databaseInfos.append(DatabaseInfo(name: databaseName, schemas: schemas, schemaCount: schemas.count))
                } else {
                    let cachedCount = cachedStructure?.databases.first(where: { $0.name == databaseName })?.schemaCount ?? 0
                    databaseInfos.append(DatabaseInfo(name: databaseName, schemas: [], schemaCount: cachedCount))
                }

                let dbProgress = structureLoadProgress(
                    databaseIndex: databaseIndex + 1,
                    schemaIndex: 0,
                    totalDatabases: totalDatabases,
                    totalSchemas: 1
                )
                await MainActor.run {
                    connectionSession.structureLoadingState = .loading(progress: dbProgress)
                }
            }

            let structure = DatabaseStructure(serverVersion: nil, databases: databaseInfos)
            await MainActor.run {
                connectionSession.structureLoadingState = .ready
            }
            return structure
        } catch {
            await MainActor.run {
                connectionSession.structureLoadingState = .failed(message: error.localizedDescription)
            }
            throw error
        }
    }
    func testConnection(_ connection: SavedConnection, passwordOverride: String? = nil) async -> ConnectionTestResult {
        connectionStates[connection.id] = .testing
        let startTime = Date()

        do {
            guard let credentials = resolvedCredentials(for: connection, overridePassword: passwordOverride) else {
                let responseTime = Date().timeIntervalSince(startTime)
                let result = ConnectionTestResult(
                    isSuccessful: false,
                    message: "Missing credentials",
                    responseTime: responseTime,
                    serverVersion: nil
                )
                connectionStates[connection.id] = .error(.connectionFailed("Missing credentials"))
                return result
            }

            let session = try await dbFactory.connect(
                host: connection.host,
                port: connection.port,
                username: credentials.username,
                password: credentials.password,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS
            )

            defer { Task { await session.close() } }

            _ = try await session.simpleQuery("SELECT 1")
            connectionStates[connection.id] = .connected

            let responseTime = Date().timeIntervalSince(startTime)
            return ConnectionTestResult(
                isSuccessful: true,
                message: "Connection successful",
                responseTime: responseTime,
                serverVersion: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            let dbError = DatabaseError.from(error)
            connectionStates[connection.id] = .error(dbError)
            return ConnectionTestResult(
                isSuccessful: false,
                message: dbError.errorDescription ?? "Connection failed",
                responseTime: responseTime,
                serverVersion: nil
            )
        }
    }

    func loadSchemaForDatabase(_ databaseName: String, connectionSession: ConnectionSession) async {
        await reconnectSession(connectionSession, to: databaseName)
    }

    func refreshDatabaseStructure(for sessionID: UUID) async {
        guard let session = sessionManager.activeSessions.first(where: { $0.id == sessionID }) else { return }
        do {
            let structure = try await loadDatabaseStructureForSession(session)
            session.databaseStructure = structure
            cacheStructure(structure, for: session.connection.id)
        } catch {
            session.structureLoadingState = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Pin helpers
    func pinObject(withID id: String) {
        guard !pinnedObjectIDs.contains(id) else { return }
        pinnedObjectIDs.append(id)
    }

    func unpinObject(withID id: String) {
        pinnedObjectIDs.removeAll { $0 == id }
    }

    func isObjectPinned(withID id: String) -> Bool {
        pinnedObjectIDs.contains(id)
    }

    // MARK: - Private helpers
    private func updateCachedConnection(id: UUID, update: (inout SavedConnection) -> Void) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        update(&connections[index])
        Task { await persistConnections() }
    }

    private func cacheStructure(_ structure: DatabaseStructure, for connectionID: UUID) {
        updateCachedConnection(id: connectionID) { connection in
            connection.cachedStructure = structure
            connection.cachedStructureUpdatedAt = Date()
        }
    }

    private func structureLoadProgress(databaseIndex: Int, schemaIndex: Int, totalDatabases: Int, totalSchemas: Int) -> Double {
        guard totalDatabases > 0 else { return 0 }
        let clampedDatabaseIndex = min(max(databaseIndex, 0), totalDatabases)
        let safeTotalSchemas = max(totalSchemas, 1)
        let clampedSchemaIndex = min(max(schemaIndex, 0), safeTotalSchemas)
        let progress = (Double(clampedDatabaseIndex) + (Double(clampedSchemaIndex) / Double(safeTotalSchemas))) / Double(totalDatabases)
        return min(max(progress, 0), 1)
    }
}
