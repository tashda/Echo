import Foundation
import OSLog
import SQLServerKit

extension EnvironmentState {
    // MARK: - Session Management

    func connect(to connection: SavedConnection) {
        connectToNewSession(to: connection)
    }

    func cancelPendingConnection(for connectionID: UUID) {
        cancelAndRemovePending(for: connectionID)
        connectionStates[connectionID] = .disconnected
    }

    func retryPendingConnection(for connectionID: UUID) {
        guard let saved = connectionStore.connections.first(where: { $0.id == connectionID }) else { return }
        connectToNewSession(to: saved)
    }

    func removePendingConnection(for connectionID: UUID) {
        pendingConnections.removeAll { $0.id == connectionID }
        connectionStates.removeValue(forKey: connectionID)
    }

    func disconnectAllSessions() {
        for (_, vm) in detachedJobQueueViewModels {
            vm.stopActivityPolling()
        }
        detachedJobQueueViewModels.removeAll()
        let sessionIDs = sessionGroup.activeSessions.map(\.id)
        for id in sessionIDs {
            sessionGroup.removeSession(withID: id)
        }
        connectionStates.removeAll()
    }

    func disconnectSession(withID id: UUID) async {
        let displayName: String
        if let session = sessionGroup.activeSessions.first(where: { $0.id == id }) {
            let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            displayName = name.isEmpty ? session.connection.host : name
        } else {
            displayName = "server"
        }
        detachedJobQueueViewModels[id]?.stopActivityPolling()
        detachedJobQueueViewModels.removeValue(forKey: id)
        // Clean up editor windows for this connection
        let userEditorKeys = userEditorViewModels.keys.filter { $0.connectionSessionID == id }
        for key in userEditorKeys { userEditorViewModels.removeValue(forKey: key) }
        let loginEditorKeys = loginEditorViewModels.keys.filter { $0.connectionSessionID == id }
        for key in loginEditorKeys { loginEditorViewModels.removeValue(forKey: key) }
        let dbEditorKeys = databaseEditorViewModels.keys.filter { $0.connectionSessionID == id }
        for key in dbEditorKeys { databaseEditorViewModels.removeValue(forKey: key) }
        let serverEditorKeys = serverEditorViewModels.keys.filter { $0.connectionSessionID == id }
        for key in serverEditorKeys { serverEditorViewModels.removeValue(forKey: key) }
        let roleEditorKeys = roleEditorViewModels.keys.filter { $0.connectionSessionID == id }
        for key in roleEditorKeys { roleEditorViewModels.removeValue(forKey: key) }
        sessionGroup.removeSession(withID: id)
        notificationEngine?.post(category: .connectionDisconnected, message: "Disconnected from \(displayName)")
    }

    func reconnectSession(_ session: ConnectionSession, to databaseName: String) async {
        session.sidebarFocusedDatabase = databaseName
        await schemaDiscoveryEngine.refreshStructure(for: session, scope: .selectedDatabase)
    }

    // MARK: - Database Metadata

    func startStructureLoadTask(for session: ConnectionSession) {
        schemaDiscoveryEngine.startStructureLoadTask(for: session)
    }

    func refreshDatabaseStructure(for sessionID: UUID, scope: StructureRefreshScope = .selectedDatabase, databaseOverride: String? = nil) async {
        guard let session = sessionGroup.activeSessions.first(where: { $0.id == sessionID }) else { return }
        if let databaseOverride {
            session.sidebarFocusedDatabase = databaseOverride
        }
        Task { await session.refreshPermissions() }
        await schemaDiscoveryEngine.refreshStructure(for: session, scope: scope)
    }

    func loadSchemaForDatabase(_ databaseName: String, connectionSession: ConnectionSession) async {
        await schemaDiscoveryEngine.loadDatabaseSchemaOnly(databaseName, for: connectionSession)
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

    func testConnection(_ connection: SavedConnection, passwordOverride: String? = nil, connectTimeoutSeconds: Int? = nil) async -> ConnectionTestResult {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: passwordOverride) else {
            return ConnectionTestResult(isSuccessful: false, message: "Missing credentials", responseTime: nil, serverVersion: nil)
        }

        let startTime = Date()
        do {
            let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType)
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
                connectTimeoutSeconds: connectTimeoutSeconds ?? Int(connection.connectionTimeout)
            )
            let duration = Date().timeIntervalSince(startTime)
            // Close in the background — shutting down the event loop group can take
            // several seconds and should not block the test result.
            Task.detached { await session.close() }
            return ConnectionTestResult(isSuccessful: true, message: "Success", responseTime: duration, serverVersion: nil)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let message = error.localizedDescription
            return ConnectionTestResult(isSuccessful: false, message: message, responseTime: duration, serverVersion: nil)
        }
    }

    func preloadStructure(for connection: SavedConnection, overridePassword: String? = nil) async {
        await schemaDiscoveryEngine.preloadStructure(for: connection, overridePassword: overridePassword)
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

    // MARK: - Helpers

    func updateNavigation(for session: ConnectionSession?) {
        if let session {
            navigationStore.navigationState.selectConnection(session.connection)
            if let db = session.sidebarFocusedDatabase {
                navigationStore.navigationState.selectDatabase(db)
            }
        }
    }

    func persistConnections() async {
        try? await connectionStore.saveConnections()
    }

    func enqueuePrefetchForSessionIfNeeded(_ session: ConnectionSession) async {
        await diagramBuilder.scheduleRelatedPrefetch(
            session: session,
            baseKey: DiagramTableKey(schema: session.connection.database, name: ""),
            relatedKeys: [],
            projectID: session.connection.projectID ?? projectStore.selectedProject?.id ?? UUID()
        )
    }

    // MARK: - Dedicated Sessions

    func makeDedicatedPostgresConsoleSession(
        for connection: SavedConnection,
        database: String
    ) async throws -> DatabaseSession {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(
            for: connection,
            overridePassword: nil
        ) else {
            throw DatabaseError.connectionFailed("Missing credentials")
        }

        guard let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType) else {
            throw DatabaseError.connectionFailed("No database factory is available for PostgreSQL.")
        }

        return try await factory.connect(
            host: connection.host,
            port: connection.port,
            database: database,
            tls: connection.useTLS,
            trustServerCertificate: connection.trustServerCertificate,
            tlsMode: connection.tlsMode,
            sslRootCertPath: connection.sslRootCertPath,
            sslCertPath: connection.sslCertPath,
            sslKeyPath: connection.sslKeyPath,
            mssqlEncryptionMode: connection.mssqlEncryptionMode,
            readOnlyIntent: connection.readOnlyIntent,
            authentication: credentials,
            connectTimeoutSeconds: 10
        )
    }

    /// Creates a dedicated query session for any database type using the generic
    /// `DatabaseFactory`. Each query tab gets its own connection for transaction
    /// isolation, session state safety, and concurrent execution — matching SSMS
    /// and pgAdmin4 behavior.
    func makeDedicatedQuerySession(
        for connection: SavedConnection,
        metadataSession: DatabaseSession,
        database: String?
    ) async throws -> DatabaseSession {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(
            for: connection,
            overridePassword: nil
        ) else {
            throw DatabaseError.connectionFailed("Missing credentials")
        }

        // MSSQL: use the specialized factory that produces MSSQLDedicatedQuerySession
        // with reconnect support and metadata delegation.
        if connection.databaseType == .microsoftSQL,
           let mssqlMetadata = metadataSession as? SQLServerSessionAdapter {
            let t0 = CFAbsoluteTimeGetCurrent()
            let configuration = try MSSQLNIOFactory.makeConnectionConfiguration(
                host: connection.host,
                port: connection.port,
                database: database,
                tls: connection.useTLS,
                trustServerCertificate: connection.trustServerCertificate,
                sslRootCertPath: connection.sslRootCertPath,
                mssqlEncryptionMode: connection.mssqlEncryptionMode,
                readOnlyIntent: connection.readOnlyIntent,
                authentication: credentials,
                connectTimeoutSeconds: 10
            )
            let t1 = CFAbsoluteTimeGetCurrent()
            Logger.connection.info("[DedicatedSession] config built in \(String(format: "%.3f", t1 - t0))s")
            let dedicatedConnection = try await SQLServerConnection.connect(
                configuration: configuration
            )
            let t2 = CFAbsoluteTimeGetCurrent()
            Logger.connection.info("[DedicatedSession] SQLServerConnection.connect() took \(String(format: "%.3f", t2 - t1))s")
            return MSSQLDedicatedQuerySession(
                connection: dedicatedConnection,
                configuration: configuration,
                metadataSession: mssqlMetadata
            )
        }

        // All other engines: use the generic DatabaseFactory to create a fresh connection.
        guard let factory = DatabaseFactoryProvider.makeFactory(for: connection.databaseType) else {
            throw DatabaseError.connectionFailed("No factory for \(connection.databaseType)")
        }

        let connectDatabase: String?
        if let database, !database.isEmpty {
            connectDatabase = database
        } else if !connection.database.isEmpty {
            connectDatabase = connection.database
        } else {
            connectDatabase = nil
        }

        return try await factory.connect(
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
    }
}
