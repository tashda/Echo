import Foundation
import OSLog
import SQLServerKit

extension EnvironmentState {
    // MARK: - Tab Management

    func registerTab(_ tab: WorkspaceTab) {
        tabStore.addTab(tab)
    }

    /// Opens a query tab with auto-formatted SQL. Resolves the connection session
    /// from `connectionID` and formats the SQL using the appropriate dialect.
    func openFormattedQueryTab(
        sql: String,
        database: String? = nil,
        connectionID: UUID,
        dialect: SQLFormatter.Dialect
    ) {
        Task {
            let formatted = (try? await SQLFormatter.shared.format(sql: sql, dialect: dialect)) ?? sql
            if let session = sessionGroup.sessionForConnection(connectionID) {
                openQueryTab(for: session, presetQuery: formatted, database: database)
            } else {
                openQueryTab(presetQuery: formatted, database: database)
            }
        }
    }

    func openQueryTab(for session: ConnectionSession? = nil, presetQuery: String? = nil, autoExecute: Bool = false, database: String? = nil) {
        let targetSession = session ?? sessionGroup.activeSession ?? sessionGroup.activeSessions.first
        guard let targetSession else { return }

        // Inherit the active tab's database when no explicit database is provided,
        // matching SSMS/pgAdmin4 behavior where Cmd+T opens a tab connected to the same database.
        let resolvedDatabase = database ?? tabStore.activeTab?.activeDatabaseName

        let connection = targetSession.connection
        let targetDatabase = resolvedDatabase
            ?? targetSession.sidebarFocusedDatabase
            ?? connection.database

        // MSSQL: show the tab immediately with the shared session, then upgrade
        // to a dedicated connection in the background. The shared session works for
        // queries (USE [db] prefix), and the upgrade provides transaction isolation.
        if connection.databaseType == .microsoftSQL,
           let metadataSession = targetSession.session as? SQLServerSessionAdapter {
            let queryText = presetQuery ?? ""
            let tab = targetSession.addQueryTab(
                withQuery: queryText,
                database: resolvedDatabase
            )
            tab.configureQueryLaunch(autoExecute: autoExecute)
            tab.markAwaitingDedicatedSession()
            tab.query?.isEstablishingConnection = true
            registerTab(tab)

            Task {
                let t0 = CFAbsoluteTimeGetCurrent()
                do {
                    let dedicatedSession = try await makeDedicatedQuerySession(
                        for: connection,
                        metadataSession: metadataSession,
                        database: targetDatabase
                    )
                    let elapsed = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0)
                    Logger.connection.info("[DedicatedSession] ready in \(elapsed)s for \(targetDatabase)")
                    tab.upgradeToDedicatedSession(dedicatedSession)
                    tab.query?.isEstablishingConnection = false
                } catch {
                    tab.markDedicatedSessionFailed(error.localizedDescription)
                    tab.query?.isEstablishingConnection = false
                    notificationEngine?.post(
                        category: .connectionFailed,
                        message: "Dedicated connection failed: \(error.localizedDescription)",
                        duration: 5.0
                    )
                }
            }
            return
        }

        // Other engines: create the tab immediately with the shared session.
        // A dedicated connection is established in the background for query isolation.
        let tab = targetSession.addQueryTab(
            withQuery: presetQuery ?? "",
            database: resolvedDatabase
        )
        tab.configureQueryLaunch(autoExecute: autoExecute)
        tab.markAwaitingDedicatedSession()
        tab.query?.isEstablishingConnection = true
        registerTab(tab)

        let gate = dedicatedConnectionGate

        Task {
            await gate.wait()
            do {
                let dedicatedSession = try await makeDedicatedQuerySession(
                    for: connection,
                    metadataSession: targetSession.session,
                    database: targetDatabase
                )
                await gate.signal()
                tab.upgradeToDedicatedSession(dedicatedSession)
                tab.query?.isEstablishingConnection = false
            } catch {
                await gate.signal()
                tab.markDedicatedSessionFailed(error.localizedDescription)
                tab.query?.isEstablishingConnection = false
                notificationEngine?.post(
                    category: .connectionFailed,
                    message: "Dedicated query connection failed: \(error.localizedDescription)",
                    duration: 5.0
                )
            }
        }
    }

    func retryDedicatedSession(for tab: WorkspaceTab) {
        guard let session = sessionGroup.sessionForConnection(tab.connection.id) else { return }

        tab.dedicatedSessionError = nil
        tab.markAwaitingDedicatedSession()
        tab.query?.isEstablishingConnection = true

        let connection = tab.connection
        let targetDatabase = tab.activeDatabaseName ?? connection.database

        Task {
            do {
                let dedicatedSession = try await makeDedicatedQuerySession(
                    for: connection,
                    metadataSession: session.session,
                    database: targetDatabase
                )
                tab.upgradeToDedicatedSession(dedicatedSession)
                tab.query?.isEstablishingConnection = false
            } catch {
                tab.markDedicatedSessionFailed(error.localizedDescription)
                tab.query?.isEstablishingConnection = false
                notificationEngine?.post(
                    category: .connectionFailed,
                    message: "Retry failed: \(error.localizedDescription)",
                    duration: 5.0
                )
            }
        }
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

    enum MaintenanceBackupAction {
        case backup
        case restore
    }

    func openMaintenanceBackups(connectionID: UUID, databaseName: String, action: MaintenanceBackupAction) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab: WorkspaceTab
        if session.connection.databaseType == .microsoftSQL {
            tab = session.addMSSQLMaintenanceTab(databaseName: databaseName)
            if let vm = tab.mssqlMaintenance {
                vm.selectedSection = .backups
                vm.backupsActiveForm = action == .backup ? .backup : .restore
            }
        } else {
            // PostgreSQL backup/restore is handled via sheets from the sidebar context menu
            return
        }
        if tabStore.getTab(id: tab.id) == nil {
            registerTab(tab)
        }
        tabStore.selectTab(tab)
    }

    func openActivityMonitorTab(connectionID: UUID, section: String? = nil) {
        // Reuse any existing activity monitor tab for this connection across all sessions
        if let existing = tabStore.tabs.first(where: { $0.kind == .activityMonitor && $0.connection.id == connectionID }) {
            if let section = section, let vm = existing.activityMonitor {
                vm.selectedSection = section
            }
            tabStore.selectTab(existing)
            return
        }
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        do {
            let tab = try session.addActivityMonitorTab()
            if let section = section, let vm = tab.activityMonitor {
                vm.selectedSection = section
            }
            registerTab(tab)
            tabStore.selectTab(tab)
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
        openMaintenanceTab(connectionID: connectionID, databaseName: databaseName)
        // Select the Query Store section after the maintenance tab opens
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        if let tab = session.queryTabs.first(where: { $0.mssqlMaintenance != nil }),
           let vm = tab.mssqlMaintenance {
            vm.selectedSection = .queryStore
        }
    }

    func openAdvancedObjectsTab(connectionID: UUID, section: PostgresAdvancedObjectsViewModel.Section? = nil) {
        // Reuse existing tab if already visible in the tab bar
        if let existing = tabStore.tabs.first(where: { $0.kind == .postgresAdvancedObjects && $0.connection.id == connectionID }) {
            if let section, let vm = existing.postgresAdvancedObjectsVM {
                vm.selectedSection = section
            }
            tabStore.selectTab(existing)
            return
        }
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addPostgresAdvancedObjectsTab()
        if let section, let vm = tab.postgresAdvancedObjectsVM {
            vm.selectedSection = section
        }
        registerTab(tab)
    }

    func openMSSQLAdvancedObjectsTab(connectionID: UUID, databaseName: String, section: MSSQLAdvancedObjectsViewModel.Section? = nil) {
        if let existing = tabStore.tabs.first(where: { $0.kind == .mssqlAdvancedObjects && $0.connection.id == connectionID }) {
            if let vm = existing.mssqlAdvancedObjectsVM {
                if vm.databaseName != databaseName {
                    vm.databaseName = databaseName
                    vm.isInitialized = false
                    Task { await vm.initialize() }
                }
                if let section { vm.selectedSection = section }
            }
            tabStore.selectTab(existing)
            return
        }
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addMSSQLAdvancedObjectsTab(databaseName: databaseName)
        if let section, let vm = tab.mssqlAdvancedObjectsVM {
            vm.selectedSection = section
        }
        registerTab(tab)
    }

    func openExtendedEventsTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        if let tab = session.addExtendedEventsTab() {
            registerTab(tab)
        }
    }

    func openProfilerTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        // Profiler requires a new tab kind
        let tab = session.addProfilerTab()
        registerTab(tab)
    }

    func openResourceGovernorTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addResourceGovernorTab()
        registerTab(tab)
    }

    func openTuningAdvisorTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addTuningAdvisorTab()
        registerTab(tab)
    }

    func openPolicyManagementTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addPolicyManagementTab()
        registerTab(tab)
    }

    func openServerPropertiesTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addServerPropertiesTab()
        registerTab(tab)
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
        let requestedDatabase = (database ?? targetSession.sidebarFocusedDatabase ?? targetSession.connection.database)
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

    /// Prepares a `JobQueueViewModel` for display in a detached window.
    /// Returns the connection session ID used as the window value.
    @discardableResult
    func prepareJobQueueWindow(for session: ConnectionSession, selectJobID: String? = nil) -> UUID {
        if let existing = detachedJobQueueViewModels[session.id] {
            if let jobID = selectJobID {
                existing.resolveAndSelect(jobIdentifier: jobID)
            }
            return session.id
        }
        let viewModel = JobQueueViewModel(session: session.session, connection: session.connection, initialSelectedJobID: selectJobID)
        detachedJobQueueViewModels[session.id] = viewModel
        return session.id
    }

    /// Moves a Job Queue tab's view model into a detached window.
    /// Closes the tab and returns the connection session ID for `openWindow`.
    func popOutJobQueueTab(_ tab: WorkspaceTab) -> UUID? {
        guard let viewModel = tab.jobQueue else { return nil }
        let sessionID = tab.connectionSessionID
        detachedJobQueueViewModels[sessionID] = viewModel
        tabStore.closeTab(id: tab.id)
        return sessionID
    }

    func openQueryBuilderTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addQueryBuilderTab()
        registerTab(tab)
    }

    func openTableDataTab(for session: ConnectionSession, schema: String, table: String, databaseName: String? = nil) {
        let tab = session.addTableDataTab(schema: schema, table: table, databaseName: databaseName)
        registerTab(tab)
    }

    func openStructureTab(for session: ConnectionSession, object: SchemaObjectInfo, focus: TableStructureSection? = nil, databaseName: String? = nil) {
        let tab = session.addStructureTab(for: object, focus: focus, databaseName: databaseName)
        registerTab(tab)
    }

    func openDiagramTab(for session: ConnectionSession, object: SchemaObjectInfo, activeDatabaseName: String? = nil) {
        let selectedProjectID = projectStore.selectedProject?.id
        let title = "\(object.schema).\(object.name)"
        let cacheKey = selectedProjectID.map {
            DiagramCacheKey(
                projectID: $0,
                connectionID: session.connection.id,
                schema: object.schema,
                table: object.name
            )
        }
        let context = SchemaDiagramContext(
            projectID: selectedProjectID,
            connectionID: session.connection.id,
            connectionSessionID: session.id,
            object: object,
            cacheKey: cacheKey
        )
        let databaseName = activeDatabaseName
            ?? (session.connection.databaseType == .mysql
                ? object.schema
                : (session.connection.database.isEmpty ? nil : session.connection.database))

        let placeholder = SchemaDiagramViewModel(
            nodes: [],
            edges: [],
            baseNodeID: "\(object.schema).\(object.name)",
            title: title,
            isLoading: true,
            statusMessage: "Loading \(title)…",
            context: context
        )

        let tab = session.addDiagramTab(
            for: object,
            viewModel: placeholder,
            databaseName: databaseName
        )
        if tabStore.getTab(id: tab.id) == nil {
            registerTab(tab)
        }
        tabStore.selectTab(tab)

        guard tab.diagram === placeholder else { return }

        placeholder.loadingTask = Task {
            do {
                let diagram = try await diagramBuilder.buildSchemaDiagram(
                    for: object,
                    session: session,
                    projectID: selectedProjectID ?? UUID(),
                    cacheKey: cacheKey,
                    databaseName: databaseName,
                    progress: { [weak placeholder] message in
                        Task { @MainActor in
                            placeholder?.statusMessage = message
                        }
                    },
                    isPrefetch: false
                )

                guard !Task.isCancelled else { return }

                // Yield to let any pending progress-callback Tasks complete
                // before we clear statusMessage, preventing a race where a
                // stale progress message overwrites our nil.
                await Task.yield()

                placeholder.nodes = diagram.nodes
                placeholder.edges = diagram.edges
                placeholder.layoutIdentifier = diagram.layoutIdentifier
                placeholder.cachedStructure = diagram.cachedStructure
                placeholder.cachedChecksum = diagram.cachedChecksum
                placeholder.loadSource = diagram.loadSource
                placeholder.statusMessage = nil
                placeholder.errorMessage = nil
                placeholder.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                placeholder.errorMessage = error.localizedDescription
                placeholder.isLoading = false
            }
        }
    }

    func duplicateTab(_ tab: WorkspaceTab) {
        // Implementation
    }

    // MARK: - Security Tabs

    func openDatabaseSecurityTab(connectionID: UUID, databaseName: String? = nil) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addDatabaseSecurityTab(databaseName: databaseName)
        if tabStore.getTab(id: tab.id) == nil {
            registerTab(tab)
        }
        tabStore.selectTab(tab)
    }

    func openErrorLogTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addErrorLogTab()
        if tabStore.getTab(id: tab.id) == nil {
            registerTab(tab)
        }
        tabStore.selectTab(tab)
    }

    func openServerSecurityTab(connectionID: UUID) {
        guard let session = sessionGroup.sessionForConnection(connectionID) else { return }
        let tab = session.addServerSecurityTab()
        if tabStore.getTab(id: tab.id) == nil {
            registerTab(tab)
        }
        tabStore.selectTab(tab)
    }
}
