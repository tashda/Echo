import SwiftUI

struct ObjectBrowserSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    var railBridge: ServerRailBridge?

    @Environment(ProjectStore.self) var projectStore
    @Environment(EnvironmentState.self) var environmentState
    @Environment(NavigationStore.self) var navigationStore
    @Environment(\.openWindow) var openWindow

    @State var viewModel = ObjectBrowserSidebarViewModel()
    @State var sheetState = SidebarSheetState()
    @State private var topVisibleContext = ObjectBrowserTopVisibleContext(isScrolledPastServerHeader: false)

    private var sessions: [ConnectionSession] {
        environmentState.sessionGroup.sessions
    }

    private var pendingConnections: [PendingConnection] {
        environmentState.pendingConnections
    }

    var body: some View {
        let connectionLayoutMode = ObjectBrowserConnectionLayoutMode(
            expandOneConnectionAtATime: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
        )
        let roots = ObjectBrowserSnapshotBuilder.buildRoots(
            pendingConnections: connectionLayoutMode.includesPendingConnectionsInOutline
                ? pendingConnections
                : [],
            sessions: sessions,
            settings: projectStore.globalSettings,
            viewModel: viewModel,
            selectedConnectionID: selectedConnectionID
        )

        let mainContent = Group {
            if sessions.isEmpty && pendingConnections.isEmpty {
                VStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "server.rack")
                        .font(TypographyTokens.hero.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text("No Connection")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.vertical, SpacingTokens.xl2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ObjectBrowserOutlineView(
                    roots: roots,
                    expandedNodeIDs: viewModel.expandedNodeIDs,
                    selectedNodeID: viewModel.selectedNodeID,
                    density: projectStore.globalSettings.sidebarDensity,
                    topScrollerInset: SpacingTokens.none,
                    rowContent: { node, isExpanded, outlineLevel, outlineOffset, onActivate in
                        AnyView(
                            ObjectBrowserRowView(
                                node: node,
                                isExpanded: isExpanded,
                                isSelected: viewModel.selectedNodeID == node.id,
                                outlineLevel: outlineLevel,
                                outlineOffset: outlineOffset,
                                isHighlighted: viewModel.highlightedNodeID == node.id,
                                highlightPulse: viewModel.highlightPulse,
                                contextMenuBuilder: { contextMenu(for: node) },
                                onActivate: onActivate
                            )
                            .environment(projectStore)
                            .environment(environmentState)
                            .environment(\.sidebarDensity, projectStore.globalSettings.sidebarDensity)
                        )
                    },
                    onExpansionChanged: { node, isExpanded in
                        handleExpansionChange(of: node, isExpanded: isExpanded)
                    },
                    onActivation: { node in
                        handleActivation(of: node)
                    },
                    onSelectionChanged: { node in
                        handleSelectionChange(node)
                    },
                    revealNodeID: viewModel.revealedNodeID,
                    revealRequestID: viewModel.revealRequestID,
                    onTopVisibleContextChanged: { context in
                        railBridge?.topVisibleConnectionID = context.connectionID
                        topVisibleContext = context
                    }
                )
                .background(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                .overlay(alignment: .top) {
                    pinnedPathBar
                }
                .animation(.easeInOut(duration: 0.22), value: pinnedPathConnectionID)
            }
        }
        .environment(sheetState)
        .environment(\.sidebarDensity, projectStore.globalSettings.sidebarDensity)
        .task(id: projectStore.selectedProject?.id) {
            restoreAndSynchronizeState()
        }
        .onAppear {
            schedulePendingNavigationConsumption()
            registerRailMenus()
        }
        .onChange(of: sessions.map(\.connection.id)) { _, _ in
            synchronizeDefaults()
        }
        .onChange(of: viewModel.expandedNodeIDs) { _, _ in
            guard !sessions.isEmpty else { return }
            viewModel.persistExpansionState(projectID: projectStore.selectedProject?.id)
        }
        .onChange(of: sessions.map(\.id)) { oldIDs, newIDs in
            let added = Set(newIDs).subtracting(oldIDs)
            guard let newSession = sessions.first(where: { added.contains($0.id) }) else { return }
            focusNewSession(newSession)
        }
        .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in
            guard let focus else { return }
            handleExplorerFocus(focus)
        }
        .onChange(of: navigationStore.pendingExplorerRevealRequestID) { _, _ in
            guard let connectionID = navigationStore.pendingExplorerRevealConnectionID else { return }
            revealConnection(connectionID)
        }

        let withSheets = applySheets(to: mainContent)
        let withAlerts = applyAlerts(to: withSheets)
        withAlerts
    }

    private func synchronizeDefaults() {
        viewModel.synchronizeDefaults(
            sessions: sessions,
            autoExpandSectionsForDatabaseType: { databaseType in
                projectStore.globalSettings.sidebarExpandSections(for: databaseType)
            },
            hideOfflineDefault: projectStore.globalSettings.sidebarHideOfflineDatabasesByDefault,
            activeConnectionID: selectedConnectionID ?? sessions.first?.connection.id,
            expandOneConnectionAtATime: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
        )
        if !sessions.isEmpty {
            viewModel.persistExpansionState(projectID: projectStore.selectedProject?.id)
        }

        for session in sessions {
            let securityNodeID = ObjectBrowserSidebarViewModel.serverFolderNodeID(
                connectionID: session.connection.id,
                kind: .security
            )
            if viewModel.isExpanded(securityNodeID) {
                loadServerSecurityIfNeeded(session: session)
            }
        }

        if selectedConnectionID == nil {
            selectedConnectionID = sessions.first?.connection.id
        }
    }

    private func restoreAndSynchronizeState() {
        viewModel.restoreExpansionState(projectID: projectStore.selectedProject?.id, sessions: sessions)
        synchronizeDefaults()
    }

    private func schedulePendingNavigationConsumption() {
        Task { @MainActor in
            await Task.yield()
            if let focus = navigationStore.pendingExplorerFocus {
                handleExplorerFocus(focus)
                return
            }
            if let connectionID = navigationStore.pendingExplorerRevealConnectionID {
                revealConnection(connectionID)
            }
        }
    }

    private func focusNewSession(_ session: ConnectionSession) {
        let visibleNodeID = visibleConnectionRootNodeID(for: session.connection.id)
        selectedConnectionID = session.connection.id
        environmentState.sessionGroup.setActiveSession(session.id)
        viewModel.selectedNodeID = visibleNodeID
        viewModel.setServerExpanded(
            true,
            connectionID: session.connection.id,
            sessions: sessions,
            collapseOthers: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
        )
        viewModel.setExpanded(true, nodeID: ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: session.connection.id))
        viewModel.revealAndPulse(nodeID: visibleNodeID)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if viewModel.highlightedNodeID == visibleNodeID {
                viewModel.highlightedNodeID = nil
            }
            if viewModel.revealedNodeID == visibleNodeID {
                viewModel.revealedNodeID = nil
            }
        }
    }

    private func revealConnection(_ connectionID: UUID) {
        let visibleNodeID = visibleConnectionRootNodeID(for: connectionID)
        selectedConnectionID = connectionID
        viewModel.selectedNodeID = visibleNodeID
        viewModel.setServerExpanded(
            true,
            connectionID: connectionID,
            sessions: sessions,
            collapseOthers: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
        )
        viewModel.revealAndPulse(nodeID: visibleNodeID)
        navigationStore.pendingExplorerRevealConnectionID = nil
    }

    // MARK: - Pinned path

    /// Connection whose path is pinned, or nil while the server's own header is on screen.
    private var pinnedPathConnectionID: UUID? {
        guard projectStore.globalSettings.sidebarShowsPinnedPath,
              topVisibleContext.isScrolledPastServerHeader
        else { return nil }
        return topVisibleContext.connectionID
    }

    @ViewBuilder
    private var pinnedPathBar: some View {
        if let connectionID = pinnedPathConnectionID,
           let session = sessions.first(where: { $0.connection.id == connectionID }) {
            ExplorerPinnedPathBar(
                serverName: displayName(for: session.connection),
                databaseName: topVisibleContext.databaseName,
                onScrollToServer: { reveal(nodeID: visibleConnectionRootNodeID(for: connectionID)) },
                onScrollToDatabase: {
                    guard let databaseName = topVisibleContext.databaseName else { return }
                    reveal(nodeID: ObjectBrowserSidebarViewModel.databaseNodeID(
                        connectionID: connectionID,
                        databaseName: databaseName
                    ))
                },
                onCollapseOtherDatabases: {
                    guard let databaseName = topVisibleContext.databaseName else { return }
                    collapseOtherDatabases(of: session, keeping: databaseName)
                }
            )
            .transition(.opacity.combined(with: .offset(y: -LayoutTokens.PinnedPath.height / 3)))
        }
    }

    private func displayName(for connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }

    private func reveal(nodeID: String) {
        viewModel.revealedNodeID = nodeID
        viewModel.revealRequestID &+= 1
    }

    /// Folds every other open database on the server and brings the kept one back into view.
    private func collapseOtherDatabases(of session: ConnectionSession, keeping databaseName: String) {
        let connectionID = session.connection.id
        let otherDatabaseIDs = (session.databaseStructure?.databases ?? [])
            .map(\.name)
            .filter { $0 != databaseName }
            .map { ObjectBrowserSidebarViewModel.databaseNodeID(connectionID: connectionID, databaseName: $0) }
        viewModel.expandedNodeIDs.subtract(otherDatabaseIDs)
        reveal(nodeID: ObjectBrowserSidebarViewModel.databaseNodeID(
            connectionID: connectionID,
            databaseName: databaseName
        ))
    }

    /// The rail's context menus are the same ones the server rows use, so they are built here
    /// where the sheets and view model they act on live.
    private func registerRailMenus() {
        railBridge?.sessionMenu = { session in connectionMenu(for: session) }
        railBridge?.pendingMenu = { pending in pendingConnectionMenu(for: pending) }
    }

    private func handleSelectionChange(_ node: ObjectBrowserNode?) {
        guard let node else { return }
        viewModel.selectedNodeID = node.id

        switch node.row {
        case .topSpacer:
            break
        case .pendingConnection:
            break
        case .server(let session),
             .databasesFolder(let session, _),
             .database(let session, _, _),
             .objectGroup(let session, _, _, _),
             .object(let session, _, _),
             .serverFolder(let session, _, _),
             .databaseFolder(let session, _, _, _, _),
             .databaseSubfolder(let session, _, _, _, _, _),
             .databaseNamedItem(let session, _, _, _, _, _),
             .securitySection(let session, _, _, _),
             .securityLogin(let session, _),
             .securityServerRole(let session, _),
             .securityCredential(let session, _),
             .agentJob(let session, _),
             .databaseSnapshot(let session, _),
             .linkedServer(let session, _),
             .ssisFolder(let session, _),
             .serverTrigger(let session, _),
             .action(let session, _, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        case .column:
            break
        case .infoLeaf(_, _, _, _), .loading(_, _), .message(_, _, _):
            break
        }
    }

    private func handleActivation(of node: ObjectBrowserNode) {
        viewModel.selectedNodeID = node.id

        switch node.row {
        case .topSpacer:
            return
        case .pendingConnection:
            return
        case .server(let session):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        case .databasesFolder(let session, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        case .database(let session, let database, _):
            guard database.isAccessible else { return }
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
            session.sidebarFocusedDatabase = database.name
        case .objectGroup(let session, let databaseName, _, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
            session.sidebarFocusedDatabase = databaseName
        case .object(let session, let databaseName, let object):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
            session.sidebarFocusedDatabase = databaseName
            viewModel.selectedNodeID = ExplorerSidebarIdentity.object(
                connectionID: session.connection.id,
                databaseName: databaseName,
                objectID: object.id
            )
        case .serverFolder(let session, _, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        case .databaseFolder(let session, let databaseName, _, _, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
            session.sidebarFocusedDatabase = databaseName
        case .databaseSubfolder(let session, let databaseName, _, _, _, _),
             .databaseNamedItem(let session, let databaseName, _, _, _, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
            session.sidebarFocusedDatabase = databaseName
        case .securitySection(let session, _, _, _),
             .securityLogin(let session, _),
             .securityServerRole(let session, _),
             .securityCredential(let session, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        case .agentJob(let session, _),
             .databaseSnapshot(let session, _),
             .linkedServer(let session, _),
             .ssisFolder(let session, _),
             .serverTrigger(let session, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
        case .action(let session, let action, _):
            selectedConnectionID = session.connection.id
            environmentState.sessionGroup.setActiveSession(session.id)
            perform(action: action, session: session)
        case .column:
            break
        case .infoLeaf(_, _, _, _), .loading(_, _), .message(_, _, _):
            break
        }
    }

    private func handleExpansionChange(of node: ObjectBrowserNode, isExpanded: Bool) {
        withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
            if case .server(let session) = node.row {
                viewModel.setServerExpanded(
                    isExpanded,
                    connectionID: session.connection.id,
                    sessions: sessions,
                    collapseOthers: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
                )
            } else {
                viewModel.setExpanded(isExpanded, nodeID: node.id)
            }
        }

        switch node.row {
        case .database(let session, let database, _):
            if isExpanded {
                loadSchemaIfNeeded(databaseName: database.name, session: session)
            }
        case .serverFolder(let session, let kind, _):
            guard isExpanded else { break }
            switch kind {
            case .agentJobs:
                if (viewModel.agentJobsBySession[session.connection.id] ?? []).isEmpty,
                   !(viewModel.agentJobsLoadingBySession[session.connection.id] ?? false) {
                    loadAgentJobs(session: session)
                }
            case .databaseSnapshots:
                if (viewModel.databaseSnapshotsBySession[session.connection.id] ?? []).isEmpty,
                   !(viewModel.databaseSnapshotsLoadingBySession[session.connection.id] ?? false) {
                    loadDatabaseSnapshots(session: session)
                }
            case .ssis:
                if (viewModel.ssisFoldersBySession[session.connection.id] ?? []).isEmpty,
                   !(viewModel.ssisLoadingBySession[session.connection.id] ?? false) {
                    Task { await loadSSISFoldersAsync(session: session) }
                }
            case .linkedServers:
                if (viewModel.linkedServersBySession[session.connection.id] ?? []).isEmpty,
                   !(viewModel.linkedServersLoadingBySession[session.connection.id] ?? false) {
                    loadLinkedServers(session: session)
                }
            case .serverTriggers:
                if (viewModel.serverTriggersBySession[session.connection.id] ?? []).isEmpty,
                   !(viewModel.serverTriggersLoadingBySession[session.connection.id] ?? false) {
                    loadServerTriggers(session: session)
                }
            case .security:
                if isExpanded {
                    loadServerSecurityIfNeeded(session: session)
                }
            case .management:
                break
            }
        case .databaseFolder(let session, let databaseName, let kind, _, _):
            guard isExpanded else { break }
            guard let database = session.databaseStructure?.databases.first(where: { $0.name == databaseName }) else { break }
            switch kind {
            case .security:
                loadDatabaseSecurityIfNeeded(database: database, session: session)
            case .databaseTriggers:
                if (viewModel.dbDDLTriggersByDB[viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: databaseName)] ?? []).isEmpty,
                   !(viewModel.dbDDLTriggersLoadingByDB[viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: databaseName)] ?? false) {
                    loadDatabaseDDLTriggers(database: database, session: session)
                }
            case .serviceBroker:
                if viewModel.serviceBrokerQueuesByDB[viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: databaseName)] == nil,
                   !(viewModel.serviceBrokerLoadingByDB[viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: databaseName)] ?? false) {
                    loadServiceBrokerData(database: database, session: session)
                }
            case .externalResources:
                if viewModel.externalDataSourcesByDB[viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: databaseName)] == nil,
                   !(viewModel.externalResourcesLoadingByDB[viewModel.databaseStorageKey(connectionID: session.connection.id, databaseName: databaseName)] ?? false) {
                    loadExternalResources(database: database, session: session)
                }
            }
        default:
            break
        }
    }

    private func perform(action: ObjectBrowserActionKind, session: ConnectionSession) {
        let connectionID = session.connection.id

        switch action {
        case .maintenance:
            environmentState.openMaintenanceTab(connectionID: connectionID)
        case .serverProperties:
            environmentState.openServerPropertiesTab(connectionID: connectionID)
        case .activityMonitor:
            environmentState.openActivityMonitorTab(connectionID: connectionID)
        case .extendedEvents:
            environmentState.openActivityMonitorTab(connectionID: connectionID, section: "XEvents")
        case .databaseMail:
            let value = environmentState.prepareDatabaseMailEditorWindow(connectionSessionID: connectionID)
            openWindow(id: DatabaseMailEditorWindow.sceneID, value: value)
        case .sqlProfiler:
            environmentState.openActivityMonitorTab(connectionID: connectionID, section: "Profiler")
        case .resourceGovernor:
            environmentState.openResourceGovernorTab(connectionID: connectionID)
        case .tuningAdvisor:
            environmentState.openTuningAdvisorTab(connectionID: connectionID)
        case .policyManagement:
            environmentState.openPolicyManagementTab(connectionID: connectionID)
        case .sqlServerLogs:
            environmentState.openErrorLogTab(connectionID: connectionID)
        case .openJobQueue:
            environmentState.openJobQueueTab(for: session)
        }
    }

    private func loadSchemaIfNeeded(databaseName: String, session: ConnectionSession) {
        let freshness = session.metadataFreshness(forDatabase: databaseName)
        switch freshness {
        case .cached, .listOnly:
            break
        case .refreshing, .live, .failed:
            return
        }
        guard session.beginSchemaLoad(forDatabase: databaseName) else { return }

        Task { @MainActor in
            session.markMetadataRefreshStarted(forDatabase: databaseName)
            defer { session.finishSchemaLoad(forDatabase: databaseName) }
            await environmentState.loadSchemaForDatabase(databaseName, connectionSession: session)
        }
    }

    private func visibleConnectionRootNodeID(for connectionID: UUID) -> String {
        let connectionLayoutMode = ObjectBrowserConnectionLayoutMode(
            expandOneConnectionAtATime: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
        )
        if connectionLayoutMode.showsServerNameInOutline {
            return ObjectBrowserSidebarViewModel.serverNodeID(connectionID: connectionID)
        }
        return ObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: connectionID)
    }
}
