import Foundation

extension EnvironmentState {
    // MARK: - Session Management

    func connect(to connection: SavedConnection) async {
        await connectToNewSession(to: connection)
    }

    func disconnectSession(withID id: UUID) async {
        let displayName: String
        if let session = sessionCoordinator.activeSessions.first(where: { $0.id == id }) {
            let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            displayName = name.isEmpty ? session.connection.host : name
        } else {
            displayName = "server"
        }
        sessionCoordinator.removeSession(withID: id)
        toastCoordinator.show(icon: "bolt.horizontal.circle", message: "Disconnected from \(displayName)", style: .info)
    }

    func reconnectSession(_ session: ConnectionSession, to databaseName: String) async {
        session.selectedDatabaseName = databaseName
        await schemaDiscoveryCoordinator.refreshStructure(for: session, scope: .selectedDatabase)
    }

    // MARK: - Database Metadata

    func startStructureLoadTask(for session: ConnectionSession) {
        schemaDiscoveryCoordinator.startStructureLoadTask(for: session)
    }

    func refreshDatabaseStructure(for sessionID: UUID, scope: StructureRefreshScope = .selectedDatabase, databaseOverride: String? = nil) async {
        guard let session = sessionCoordinator.activeSessions.first(where: { $0.id == sessionID }) else { return }
        if let databaseOverride {
            session.selectedDatabaseName = databaseOverride
        }
        await schemaDiscoveryCoordinator.refreshStructure(for: session, scope: scope)
    }

    func loadSchemaForDatabase(_ databaseName: String, connectionSession: ConnectionSession) async {
        connectionSession.selectedDatabaseName = databaseName
        await schemaDiscoveryCoordinator.loadDatabaseSchemaOnly(databaseName, for: connectionSession)
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
            let session = try await factory!.connect(
                host: connection.host,
                port: connection.port,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS,
                authentication: credentials,
                connectTimeoutSeconds: connectTimeoutSeconds
            )
            let duration = Date().timeIntervalSince(startTime)
            await session.close()
            return ConnectionTestResult(isSuccessful: true, message: "Success", responseTime: duration, serverVersion: nil)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let message = error.localizedDescription
            return ConnectionTestResult(isSuccessful: false, message: message, responseTime: duration, serverVersion: nil)
        }
    }

    func preloadStructure(for connection: SavedConnection, overridePassword: String? = nil) async {
        await schemaDiscoveryCoordinator.preloadStructure(for: connection, overridePassword: overridePassword)
    }

    // MARK: - Tab Management

    func registerTab(_ tab: WorkspaceTab) {
        tabStore.addTab(tab)
    }

    func openQueryTab(for session: ConnectionSession? = nil, presetQuery: String? = nil, autoExecute: Bool = false) {
        let targetSession = session ?? sessionCoordinator.activeSession ?? sessionCoordinator.activeSessions.first
        guard let targetSession else { return }
        let tab = targetSession.addQueryTab(withQuery: presetQuery ?? "")
        registerTab(tab)
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
        await diagramCoordinator.scheduleRelatedPrefetch(
            session: session,
            baseKey: DiagramTableKey(schema: session.connection.database, name: ""),
            relatedKeys: [],
            projectID: session.connection.projectID ?? projectStore.selectedProject?.id ?? UUID()
        )
    }
}
