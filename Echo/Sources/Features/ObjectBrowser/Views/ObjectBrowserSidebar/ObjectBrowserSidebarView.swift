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

    internal var sessions: [ConnectionSession] { environmentState.sessionCoordinator.sessions }

    internal var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return environmentState.sessionCoordinator.sessionForConnection(id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if sessions.isEmpty {
                                emptyStateView
                                    .padding(.horizontal, SpacingTokens.md)
                                    .padding(.top, SpacingTokens.xl)
                            } else {
                                ForEach(sessions, id: \.connection.id) { session in
                                    serverSection(session: session, proxy: proxy)
                                }
                            }
                        }
                        .padding(.top, SpacingTokens.xs)
                        .padding(.bottom, ExplorerSidebarConstants.scrollBottomPadding)
                    }
                    .simultaneousGesture(TapGesture().onEnded { _ in if viewModel.isSearchFieldFocused { withAnimation(.easeInOut(duration: 0.2)) { viewModel.isSearchFieldFocused = false } } })
                    .scrollIndicators(.hidden)
                    .contentShape(Rectangle())
                    .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
                    .task {
                        syncSelectionWithSessions()
                        viewModel.setupSearchDebounce(proxy: proxy)
                    }
                    .onChange(of: sessions.map { $0.connection.id }) { _, _ in syncSelectionWithSessions() }
                    .onChange(of: selectedConnectionID) { _, newValue in
                        guard let id = newValue, let session = environmentState.sessionCoordinator.sessionForConnection(id) else { return }
                        environmentState.sessionCoordinator.setActiveSession(session.id)
                        viewModel.ensureServerExpanded(for: id, sessions: sessions)
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

    // MARK: - Per-Server Section

    @ViewBuilder
    private func serverSection(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.expandedServerIDs.contains(connID)
        let isSelected = connID == selectedConnectionID

        VStack(alignment: .leading, spacing: 0) {
            // Compact server header
            serverHeaderRow(session: session, isExpanded: isExpanded, isSelected: isSelected)

            // Object tree when expanded
            if isExpanded {
                serverContent(session: session, proxy: proxy)
                    .padding(.leading, SpacingTokens.xs)
            }
        }
        .task { viewModel.initializeSessionState(for: session) }
    }

    private func serverHeaderRow(session: ConnectionSession, isExpanded: Bool, isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    viewModel.expandedServerIDs.remove(session.connection.id)
                } else {
                    viewModel.expandedServerIDs.insert(session.connection.id)
                }
            }
            selectedConnectionID = session.connection.id
            environmentState.sessionCoordinator.setActiveSession(session.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                Image(session.connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)

                Text(serverDisplayName(session))
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let dbName = session.selectedDatabaseName {
                    Text("·")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.tertiary)
                    Text(dbName)
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Disconnect") {
                Task { await environmentState.disconnectSession(withID: session.id) }
            }
            Divider()
            if let structure = session.databaseStructure {
                Menu("Switch Database") {
                    ForEach(structure.databases, id: \.name) { db in
                        Button {
                            Task { await environmentState.loadSchemaForDatabase(db.name, connectionSession: session) }
                        } label: {
                            HStack {
                                Text(db.name)
                                if db.name == session.selectedDatabaseName {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func serverContent(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id

        switch session.structureLoadingState {
        case .ready, .loading:
            if let structure = session.databaseStructure,
               let database = selectedDatabase(in: structure, for: session) {
                VStack(spacing: 2) {
                    Color.clear.frame(height: 0)
                        .id("\(connID)-objects-top")

                    DatabaseObjectBrowserView(
                        database: database,
                        connection: session.connection,
                        searchText: $viewModel.debouncedSearchText,
                        selectedSchemaName: viewModel.selectedSchemaNameBinding(for: connID),
                        expandedObjectGroups: viewModel.expandedObjectGroupsBinding(for: connID),
                        expandedObjectIDs: viewModel.expandedObjectIDsBinding(for: connID),
                        pinnedObjectIDs: viewModel.pinnedObjectsBinding(for: database, connectionID: connID),
                        isPinnedSectionExpanded: viewModel.pinnedSectionExpandedBinding(for: database, connectionID: connID),
                        scrollTo: { id, anchor in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: anchor)
                            }
                        }
                    )
                    .environmentObject(environmentState)
                    .padding(.horizontal, SpacingTokens.xxs)
                }
            } else if session.databaseStructure != nil {
                noDatabaseHint(session: session)
            } else {
                loadingHint()
            }
        case .idle:
            loadingHint()
        case .failed(let message):
            failureHint(message: message, session: session)
        }
    }

    // MARK: - Compact Inline States

    private func noDatabaseHint(session: ConnectionSession) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "cylinder.split.1x2")
                .font(TypographyTokens.label)
                .foregroundStyle(.tertiary)
            Text("Select a database")
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func loadingHint() -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Loading…")
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func failureHint(message: String?, session: ConnectionSession) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.label)
                .foregroundStyle(.orange)
            Text(message ?? "Failed to load")
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Button("Retry") {
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            }
            .buttonStyle(.plain)
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Helpers

    private func serverDisplayName(_ session: ConnectionSession) -> String {
        let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? session.connection.host : name
    }

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        await environmentState.connect(to: connection)
        await MainActor.run {
            viewModel.expandedServerIDs.insert(connection.id)
            selectedConnectionID = connection.id
        }
    }
}
