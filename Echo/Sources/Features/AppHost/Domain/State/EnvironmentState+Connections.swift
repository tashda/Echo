import Foundation

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
        sessionGroup.removeSession(withID: id)
        notificationEngine?.post(category: .connectionDisconnected, message: "Disconnected from \(displayName)")
    }

    func reconnectSession(_ session: ConnectionSession, to databaseName: String) async {
        session.selectedDatabaseName = databaseName
        await schemaDiscoveryEngine.refreshStructure(for: session, scope: .selectedDatabase)
    }

    // MARK: - Database Metadata

    func startStructureLoadTask(for session: ConnectionSession) {
        schemaDiscoveryEngine.startStructureLoadTask(for: session)
    }

    func refreshDatabaseStructure(for sessionID: UUID, scope: StructureRefreshScope = .selectedDatabase, databaseOverride: String? = nil) async {
        guard let session = sessionGroup.activeSessions.first(where: { $0.id == sessionID }) else { return }
        if let databaseOverride {
            session.selectedDatabaseName = databaseOverride
        }
        await schemaDiscoveryEngine.refreshStructure(for: session, scope: scope)
    }

    func loadSchemaForDatabase(_ databaseName: String, connectionSession: ConnectionSession) async {
        connectionSession.selectedDatabaseName = databaseName
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

    func testConnection(_ connection: SavedConnection, passwordOverride: String? = nil, connectTimeoutSeconds: Int = 10) async -> ConnectionTestResult {
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
                connectTimeoutSeconds: connectTimeoutSeconds
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

    // MARK: - Tab Management

    func registerTab(_ tab: WorkspaceTab) {
        tabStore.addTab(tab)
    }

    func openQueryTab(for session: ConnectionSession? = nil, presetQuery: String? = nil, autoExecute: Bool = false, database: String? = nil) {
        let targetSession = session ?? sessionGroup.activeSession ?? sessionGroup.activeSessions.first
        guard let targetSession else { return }
        let tab = targetSession.addQueryTab(withQuery: presetQuery ?? "", database: database)
        registerTab(tab)
    }

    func openMaintenanceTab(connectionID: UUID, databaseName: String? = nil) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab: WorkspaceTab
        if session.connection.databaseType == .microsoftSQL {
            tab = session.addMSSQLMaintenanceTab(databaseName: databaseName)
        } else {
            tab = session.addMaintenanceTab(databaseName: databaseName)
        }
        if tabStore.getTab(id: tab.id) == nil {
            registerTab(tab)
        }
        tabStore.selectTab(tab)
    }

    func openActivityMonitorTab(connectionID: UUID) {
        // Reuse any existing activity monitor tab for this connection across all sessions
        if let existing = tabStore.tabs.first(where: { $0.kind == .activityMonitor && $0.connection.id == connectionID }) {
            tabStore.selectTab(existing)
            return
        }
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        do {
            let tab = try session.addActivityMonitorTab()
            registerTab(tab)
        } catch let error as DatabaseError {
            self.lastError = error
        } catch {
            self.lastError = .queryError(error.localizedDescription)
        }
    }

    func openExtensionsManagerTab(connectionID: UUID, databaseName: String) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addExtensionsManagerTab(databaseName: databaseName)
        registerTab(tab)
    }

    func openQueryStoreTab(connectionID: UUID, databaseName: String) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        // Check for existing tab first — activate it without creating a new one
        if let existing = session.queryTabs.first(where: { $0.queryStoreVM?.databaseName == databaseName }) {
            session.activeQueryTabID = existing.id
            tabStore.selectTab(existing)
            return
        }
        if let tab = session.addQueryStoreTab(databaseName: databaseName) {
            registerTab(tab)
        }
    }

    func openExtendedEventsTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        if let tab = session.addExtendedEventsTab() {
            registerTab(tab)
        }
    }

    func openAvailabilityGroupsTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        if let tab = session.addAvailabilityGroupsTab() {
            registerTab(tab)
        }
    }

    func openPSQLTab(for session: ConnectionSession? = nil, database: String? = nil) {
        guard projectStore.globalSettings.managedPostgresConsoleEnabled else { return }
        let targetSession = session ?? sessionGroup.activeSession ?? sessionGroup.activeSessions.first
        guard let targetSession else { return }
        let requestedDatabase = (database ?? targetSession.selectedDatabaseName ?? targetSession.connection.database)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveDatabase = requestedDatabase.isEmpty ? "postgres" : requestedDatabase
        let connection = targetSession.connection

        Task {
            do {
                let dedicatedSession = try await makeDedicatedPostgresConsoleSession(
                    for: connection,
                    database: effectiveDatabase
                )

                let sessionFactory: @Sendable (String) async throws -> DatabaseSession = { [weak self] databaseName in
                    guard let self else {
                        throw DatabaseError.connectionFailed("The environment is no longer available.")
                    }
                    return try await self.makeDedicatedPostgresConsoleSession(
                        for: connection,
                        database: databaseName
                    )
                }

                await MainActor.run {
                    let tab = targetSession.addPSQLTab(
                        session: dedicatedSession,
                        database: effectiveDatabase,
                        sessionFactory: sessionFactory
                    )
                    registerTab(tab)
                }
            } catch {
                await MainActor.run {
                    notificationEngine?.post(category: .connectionFailed, message: "Postgres Console failed: \(error.localizedDescription)", duration: 5.0)
                }
            }
        }
    }

    private func makeDedicatedPostgresConsoleSession(
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

    func openJobQueueTab(for session: ConnectionSession, selectJobID: String? = nil) {
        // Reuse existing Jobs tab for this session if one exists
        if let existingTab = tabStore.tabs.first(where: { $0.kind == .jobQueue && $0.connectionSessionID == session.id }) {
            tabStore.selectTab(existingTab)
            if let jobID = selectJobID, let vm = existingTab.jobQueue {
                vm.resolveAndSelect(jobIdentifier: jobID)
            }
            return
        }
        let tab = session.addJobQueueTab(selectJobID: selectJobID)
        registerTab(tab)
    }

    func openStructureTab(for session: ConnectionSession, object: SchemaObjectInfo, focus: TableStructureSection? = nil, databaseName: String? = nil) {
        let tab = session.addStructureTab(for: object, focus: focus, databaseName: databaseName)
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

    // MARK: - Helpers

    func updateNavigation(for session: ConnectionSession?) {
        if let session {
            navigationStore.navigationState.selectConnection(session.connection)
            if let db = session.selectedDatabaseName {
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
}
