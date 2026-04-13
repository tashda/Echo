import SwiftUI

struct ExperimentalObjectBrowserSidebarView: View {
    @Binding var selectedConnectionID: UUID?

    @Environment(ProjectStore.self) var projectStore
    @Environment(EnvironmentState.self) var environmentState
    @Environment(NavigationStore.self) var navigationStore
    @Environment(\.openWindow) var openWindow

    @State var viewModel = ExperimentalObjectBrowserSidebarViewModel()
    @State var sheetState = SidebarSheetState()

    private var sessions: [ConnectionSession] {
        environmentState.sessionGroup.sessions
    }

    private var pendingConnections: [PendingConnection] {
        environmentState.pendingConnections
    }

    var body: some View {
        let roots = ExperimentalObjectBrowserSnapshotBuilder.buildRoots(
            pendingConnections: pendingConnections,
            sessions: sessions,
            settings: projectStore.globalSettings,
            viewModel: viewModel
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
                ExperimentalObjectBrowserOutlineView(
                    roots: roots,
                    expandedNodeIDs: viewModel.expandedNodeIDs,
                    selectedNodeID: viewModel.selectedNodeID,
                    rowContent: { node, isExpanded, outlineLevel, outlineOffset, onActivate in
                        AnyView(
                            ExperimentalObjectBrowserRowView(
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
                    revealRequestID: viewModel.revealRequestID
                )
                .background(Color.clear)
            }
        }
        .environment(sheetState)
        .environment(\.sidebarDensity, projectStore.globalSettings.sidebarDensity)
        .task(id: projectStore.selectedProject?.id) {
            restoreAndSynchronizeState()
        }
        .onAppear {
            schedulePendingNavigationConsumption()
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
        viewModel.synchronizeDefaults(sessions: sessions) { databaseType in
            projectStore.globalSettings.sidebarExpandSections(for: databaseType)
        }
        if !sessions.isEmpty {
            viewModel.persistExpansionState(projectID: projectStore.selectedProject?.id)
        }

        for session in sessions {
            let securityNodeID = ExperimentalObjectBrowserSidebarViewModel.serverFolderNodeID(
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
        let serverNodeID = ExperimentalObjectBrowserSidebarViewModel.serverNodeID(connectionID: session.connection.id)
        selectedConnectionID = session.connection.id
        environmentState.sessionGroup.setActiveSession(session.id)
        viewModel.selectedNodeID = serverNodeID
        viewModel.setExpanded(true, nodeID: serverNodeID)
        viewModel.setExpanded(true, nodeID: ExperimentalObjectBrowserSidebarViewModel.databasesFolderNodeID(connectionID: session.connection.id))
        viewModel.revealAndPulse(nodeID: serverNodeID)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if viewModel.highlightedNodeID == serverNodeID {
                viewModel.highlightedNodeID = nil
            }
            if viewModel.revealedNodeID == serverNodeID {
                viewModel.revealedNodeID = nil
            }
        }
    }

    private func revealConnection(_ connectionID: UUID) {
        let serverNodeID = ExperimentalObjectBrowserSidebarViewModel.serverNodeID(connectionID: connectionID)
        selectedConnectionID = connectionID
        viewModel.selectedNodeID = serverNodeID
        viewModel.setExpanded(true, nodeID: serverNodeID)
        viewModel.revealAndPulse(nodeID: serverNodeID)
        navigationStore.pendingExplorerRevealConnectionID = nil
    }

    private func handleSelectionChange(_ node: ExperimentalObjectBrowserNode?) {
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
        case .infoLeaf(_, _, _, _), .loading(_, _), .message(_, _, _):
            break
        }
    }

    private func handleActivation(of node: ExperimentalObjectBrowserNode) {
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
        case .infoLeaf(_, _, _, _), .loading(_, _), .message(_, _, _):
            break
        }
    }

    private func handleExpansionChange(of node: ExperimentalObjectBrowserNode, isExpanded: Bool) {
        withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
            viewModel.setExpanded(isExpanded, nodeID: node.id)
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

    private func perform(action: ExperimentalObjectBrowserActionKind, session: ConnectionSession) {
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
}
