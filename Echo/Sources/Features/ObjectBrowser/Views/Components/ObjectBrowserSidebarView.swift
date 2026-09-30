import SwiftUI

struct ObjectBrowserSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    var railBridge: ServerRailBridge?

    @Environment(ProjectStore.self) var projectStore
    @Environment(EnvironmentState.self) var environmentState
    @Environment(NavigationStore.self) var navigationStore
    @Environment(\.openWindow) var openWindow
    @Environment(\.workspaceCardCornerRadius) private var cardCornerRadius

    @State var viewModel = ObjectBrowserSidebarViewModel()
    @State var sheetState = SidebarSheetState()

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
        let builtRoots = ObjectBrowserSnapshotBuilder.buildRoots(
            pendingConnections: connectionLayoutMode.includesPendingConnectionsInOutline
                ? pendingConnections
                : [],
            sessions: sessions,
            settings: projectStore.globalSettings,
            viewModel: viewModel,
            selectedConnectionID: selectedConnectionID
        )
        // TC1: each server shows its dock and the chosen section.
        let roots = ExplorerDock.apply(to: builtRoots, selections: viewModel.dockSelections(for: sessions.map(\.connection.id)))

        let mainContent = Group {
            if sessions.isEmpty && pendingConnections.isEmpty {
                VStack(spacing: SpacingTokens.xs) {
                    Image(systemName: "server.rack")
                        .font(TypographyTokens.hero.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    VStack(spacing: SpacingTokens.xxxs) {
                        Text("No Servers Connected")
                            .font(TypographyTokens.standard.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Text("Connect with the + button in the rail.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.vertical, SpacingTokens.xl2)
                .padding(.horizontal, SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ObjectBrowserOutlineView(
                    roots: roots,
                    expandedNodeIDs: viewModel.expandedNodeIDs,
                    selectedNodeID: viewModel.selectedNodeID,
                    density: projectStore.globalSettings.sidebarDensity,
                    topScrollerInset: SpacingTokens.none,
                    cornerRadius: cardCornerRadius,
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
                            // Cells are recycled while scrolling; a new identity per node keeps a
                            // recycled row from inheriting the previous row's hover or animating
                            // its selection fading away.
                            .id(node.id)
                            .environment(projectStore)
                            .environment(environmentState)
                            .environment(\.sidebarDensity, projectStore.globalSettings.sidebarDensity)
                            .environment(\.sidebarUsesDuotoneIcons, projectStore.globalSettings.sidebarIconColorMode == .colorful)
                            .environment(\.selectExplorerDockSection) { connectionID, itemID in
                                selectDockSection(itemID, connectionID: connectionID, builtRoots: builtRoots)
                            }
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
                    onTopRowChanged: { rowID, connectionID in
                        viewModel.topVisibleRow = rowID.map { ($0, connectionID) }
                    },
                    onTopVisibleContextChanged: { context in
                        if railBridge?.topVisibleConnectionID != context.connectionID {
                            railBridge?.topVisibleConnectionID = context.connectionID
                        }
                        railBridge?.topVisibleContext = context
                    },
                    showsScrollBar: projectStore.globalSettings.sidebarShowsScrollBar
                )
                .background(Color.clear)
                // Not clipped: the server cards' shadows reach past the tree's edges. The scroll
                // view clips the rows to the cards' rounded corners itself.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

        loadSourcesOfOpenFolders(in: ObjectBrowserSnapshotBuilder.buildRoots(
            pendingConnections: [],
            sessions: sessions,
            settings: projectStore.globalSettings,
            viewModel: viewModel,
            selectedConnectionID: selectedConnectionID
        ))

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

    func reveal(nodeID: String) {
        viewModel.revealedNodeID = nodeID
        viewModel.revealRequestID &+= 1
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
        guard let session = node.row.session else { return }
        selectedConnectionID = session.connection.id
        environmentState.sessionGroup.setActiveSession(session.id)
    }

    private func handleActivation(of node: ObjectBrowserNode) {
        viewModel.selectedNodeID = node.id
        if case .database(_, let database, _) = node.row, !database.isAccessible { return }
        guard let session = node.row.session else { return }

        selectedConnectionID = session.connection.id
        environmentState.sessionGroup.setActiveSession(session.id)
        if let databaseName = node.row.databaseName {
            session.sidebarFocusedDatabase = databaseName
        }
        switch node.row {
        case .object(_, let databaseName, let object):
            viewModel.selectedNodeID = ExplorerSidebarIdentity.object(
                connectionID: session.connection.id,
                databaseName: databaseName,
                objectID: object.id
            )
        case .action(_, let kind):
            perform(action: kind, session: session)
        default:
            break
        }
    }

    func handleExpansionChange(of node: ObjectBrowserNode, isExpanded: Bool) {
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

        guard isExpanded else { return }
        switch node.row {
        case .database(let session, let database, _):
            loadSchemaIfNeeded(databaseName: database.name, session: session)
        case .section(let folder), .folder(let folder):
            loadIfNeeded(folder)
        default:
            break
        }
    }

    private func perform(action: ExplorerNodeKind, session: ConnectionSession) {
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
        case .jobQueue:
            environmentState.openJobQueueTab(for: session)
        default:
            break
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
