import SwiftUI
import AppKit
import EchoSense

struct ObjectBrowserSidebarView: View {
    @Binding var selectedConnectionID: UUID?

    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    
    @EnvironmentObject internal var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    
    @StateObject internal var viewModel = ObjectBrowserSidebarViewModel()

    internal var searchText: String {
        get { viewModel.searchText }
        set { viewModel.searchText = newValue }
    }
    
    internal var selectedSchemaName: String? {
        get { viewModel.selectedSchemaName }
        set { viewModel.selectedSchemaName = newValue }
    }
    
    internal var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType> {
        get { viewModel.expandedObjectGroups }
        set { viewModel.expandedObjectGroups = newValue }
    }
    
    internal var expandedObjectIDs: Set<String> {
        get { viewModel.expandedObjectIDs }
        set { viewModel.expandedObjectIDs = newValue }
    }

    private let showConnectedServersSection = false

    internal var sessions: [ConnectionSession] { environmentState.sessionCoordinator.sessions }

    internal var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return environmentState.sessionCoordinator.sessionForConnection(id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if showConnectedServersSection,
                   let session = selectedSession,
                   session.selectedDatabaseName != nil,
                   !viewModel.isHoveringConnectedServers {
                    stickyTopBar()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10, pinnedViews: .sectionHeaders) {
                            if showConnectedServersSection && (viewModel.isHoveringConnectedServers || selectedSession?.selectedDatabaseName == nil) {
                                Section {
                                    Color.clear.frame(height: 0).id(ExplorerSidebarConstants.connectedServersAnchor)
                                    connectedServersList
                                } header: {
                                    SidebarSectionHeader(title: "Connected Servers")
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            }
                            explorerContent(proxy: proxy)
                        }
                        .padding(.top, SpacingTokens.sm)
                        .padding(.bottom, ExplorerSidebarConstants.scrollBottomPadding)
                    }
                    .simultaneousGesture(TapGesture().onEnded { _ in if viewModel.isSearchFieldFocused { withAnimation(.easeInOut(duration: 0.2)) { viewModel.isSearchFieldFocused = false } } })
                    .scrollIndicators(.hidden)
                    .contentShape(Rectangle())
                    .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
                    .overlay(alignment: .top) { loadingOverlay }
                    .onAppear {
                        syncSelectionWithSessions()
                        viewModel.setupSearchDebounce(proxy: proxy)
                    }
                    .onChange(of: sessions.map { $0.connection.id }) { _, _ in syncSelectionWithSessions() }
                    .onChange(of: selectedConnectionID) { _, newValue in
                        guard let id = newValue, let session = environmentState.sessionCoordinator.sessionForConnection(id) else { return }
                        environmentState.sessionCoordinator.setActiveSession(session.id)
                        viewModel.ensureServerExpanded(for: id, sessions: sessions)
                        viewModel.resetFilters(for: session, selectedSession: selectedSession)
                        if !viewModel.isHoveringConnectedServers { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top) } }
                    }
                    .onChange(of: selectedSession?.selectedDatabaseName) { _, _ in
                        if selectedSession?.selectedDatabaseName == nil { withAnimation(.easeInOut(duration: 0.3)) { viewModel.isHoveringConnectedServers = true } }
                        else if !viewModel.isHoveringConnectedServers { withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top) } }
                    }
                    .onChange(of: viewModel.selectedSchemaName) { _, _ in
                        viewModel.expandedObjectIDs.removeAll()
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }
                    footerView
                }
            }
            .onAppear {
                viewModel.debouncedSearchText = viewModel.searchText
                if let focus = navigationStore.pendingExplorerFocus { handleExplorerFocus(focus, proxy: proxy) }
            }
            .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in if let focus { handleExplorerFocus(focus, proxy: proxy) } }
            .onDisappear { viewModel.stopSearchDebounce() }
        }
        .accessibilityIdentifier("object-browser-sidebar")
        .background(ExplorerSidebarFocusResetter(isSearchFieldFocused: $viewModel.isSearchFieldFocused).allowsHitTesting(false))
    }

    @ViewBuilder
    private var connectedServersList: some View {
        if sessions.isEmpty {
            VStack(spacing: 16) {
                Menu {
                    Button("New Connection…") { appState.showSheet(.connectionEditor) }
                    if !connectionStore.connections.isEmpty {
                        Divider()
                        Menu("Saved Connections") {
                            SavedConnectionsMenuItems(parentID: nil) { connection in
                                withAnimation(.easeInOut(duration: 0.3)) { viewModel.isHoveringConnectedServers = true }
                                Task { await connectToSavedConnection(connection) }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack").font(TypographyTokens.display.weight(.semibold))
                        Text("Connect to Server").font(TypographyTokens.prominent.weight(.semibold))
                    }
                    .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs2)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.2), lineWidth: 1)))
                }.menuStyle(.borderlessButton)
            }.frame(maxWidth: .infinity, alignment: .center).padding(.vertical, SpacingTokens.xl)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sessions, id: \.connection.id) { session in
                    ConnectedServerCard(session: session, isSelected: session.connection.id == selectedConnectionID, isExpanded: Binding(get: { viewModel.expandedConnectedServerIDs.contains(session.connection.id) }, set: { if $0 { viewModel.expandedConnectedServerIDs.insert(session.connection.id) } else { viewModel.expandedConnectedServerIDs.remove(session.connection.id) } }), showCurrentDatabase: true, onSelectServer: { selectSession(session) }, onPickDatabase: { handleDatabaseSelection($0, in: session) }).environmentObject(environmentState)
                }
            }.padding(.horizontal, SpacingTokens.sm)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if let session = selectedSession {
            switch session.structureLoadingState {
            case .loading(let progress):
                if !(session.databaseStructure?.databases ?? []).contains(where: { !$0.schemas.isEmpty }) {
                    ExplorerLoadingOverlay(progress: progress, message: "Loading database objects…").padding(.top, 120).transition(.opacity).allowsHitTesting(false)
                }
            case .failed(let message):
                ExplorerLoadingOverlay(progress: nil, message: message ?? "Unable to load database objects").padding(.top, 120).transition(.opacity).allowsHitTesting(false)
            default: EmptyView()
            }
        }
    }

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        await MainActor.run { withAnimation(.easeInOut(duration: 0.3)) { viewModel.isHoveringConnectedServers = true } }
        await environmentState.connect(to: connection)
        await MainActor.run {
            viewModel.expandedConnectedServerIDs.insert(connection.id)
            selectedConnectionID = connection.id
        }
    }

}
