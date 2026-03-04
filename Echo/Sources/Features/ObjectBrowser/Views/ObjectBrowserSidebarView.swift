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

    private var sessions: [ConnectionSession] { environmentState.sessionManager.sessions }

    private var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return environmentState.sessionManager.sessionForConnection(id)
    }

    private var sessionAccentColor: Color {
        selectedSession?.connection.color ?? Color.accentColor
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
                                    Color.clear.frame(height: 0)
                                        .id(ExplorerSidebarConstants.connectedServersAnchor)

                                    connectedServersList
                                } header: {
                                    SidebarSectionHeader(title: "Connected Servers")
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            }

                            explorerContent(proxy: proxy)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, ExplorerSidebarConstants.scrollBottomPadding)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded { _ in
                            if viewModel.isSearchFieldFocused {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.isSearchFieldFocused = false
                                }
                            }
                        }
                    )
                    .scrollIndicators(.hidden)
                    .contentShape(Rectangle())
                    .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
                    .overlay(alignment: .top) {
                        loadingOverlay
                    }
                    .onAppear {
                        syncSelectionWithSessions()
                        viewModel.setupSearchDebounce(proxy: proxy)
                    }
                    .onChange(of: sessions.map { $0.connection.id }) { _, _ in
                        syncSelectionWithSessions()
                    }
                    .onChange(of: selectedConnectionID) { _, newValue in
                        guard let id = newValue,
                              let session = environmentState.sessionManager.sessionForConnection(id) else { return }
                        environmentState.sessionManager.setActiveSession(session.id)
                        viewModel.ensureServerExpanded(for: id, sessions: sessions)
                        viewModel.resetFilters(for: session, selectedSession: selectedSession)
                        if !viewModel.isHoveringConnectedServers {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: selectedSession?.selectedDatabaseName) { _, _ in
                        let hasDatabase = selectedSession?.selectedDatabaseName != nil
                        if !hasDatabase {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.isHoveringConnectedServers = true
                            }
                        } else if !viewModel.isHoveringConnectedServers {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedSchemaName) { oldValue, newValue in
                        let hasMeaningfulChange: Bool
                        switch (oldValue, newValue) {
                        case (.none, .none):
                            hasMeaningfulChange = false
                        case let (.some(lhs), .some(rhs)):
                            hasMeaningfulChange = lhs.caseInsensitiveCompare(rhs) != .orderedSame
                        default:
                            hasMeaningfulChange = true
                        }
                        guard hasMeaningfulChange else { return }
                        if !viewModel.expandedObjectIDs.isEmpty {
                            viewModel.expandedObjectIDs.removeAll()
                        }
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }

                    footerView
                }
            }
            .onAppear {
                viewModel.debouncedSearchText = viewModel.searchText
                if let focus = navigationStore.pendingExplorerFocus {
                    handleExplorerFocus(focus, proxy: proxy)
                }
            }
            .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in
                guard let focus else { return }
                handleExplorerFocus(focus, proxy: proxy)
            }
            .onDisappear {
                viewModel.stopSearchDebounce()
            }
        }
        .background(
            ExplorerSidebarFocusResetter(isSearchFieldFocused: $viewModel.isSearchFieldFocused)
                .allowsHitTesting(false)
        )
    }

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        await MainActor.run {
            let _: Void = withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.isHoveringConnectedServers = true
            }
        }

        await environmentState.connect(to: connection)

        await MainActor.run {
            let _: Void = withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.expandedConnectedServerIDs.insert(connection.id)
            }
            selectedConnectionID = connection.id
        }
    }

    @ViewBuilder
    private var connectedServersList: some View {
        if sessions.isEmpty {
            VStack(spacing: 16) {
                Menu {
                    Button("New Connection…") {
                        appState.showSheet(.connectionEditor)
                    }

                    if !connectionStore.connections.isEmpty {
                        Divider()
                        Menu("Saved Connections") {
                            SavedConnectionsMenuItems(parentID: nil) { connection in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.isHoveringConnectedServers = true
                                }
                                Task {
                                    await connectToSavedConnection(connection)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Connect to Server")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .menuStyle(.borderlessButton)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sessions, id: \.connection.id) { session in
                    ConnectedServerCard(
                        session: session,
                        isSelected: session.connection.id == selectedConnectionID,
                        isExpanded: Binding(
                            get: { viewModel.expandedConnectedServerIDs.contains(session.connection.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    viewModel.expandedConnectedServerIDs.insert(session.connection.id)
                                } else {
                                    viewModel.expandedConnectedServerIDs.remove(session.connection.id)
                                }
                            }
                        ),
                        showCurrentDatabase: true,
                        onSelectServer: {
                            selectSession(session)
                        },
                        onPickDatabase: { database in
                            handleDatabaseSelection(database, in: session)
                        }
                    )
                    .environmentObject(environmentState)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func explorerContent(proxy: ScrollViewProxy) -> some View {
        Group {
            if let session = selectedSession {
                switch session.structureLoadingState {
                case .ready, .loading:
                    if let structure = session.databaseStructure,
                       let database = selectedDatabase(in: structure, for: session) {
                        VStack(spacing: 16) {
                            Color.clear.frame(height: 0)
                                .id(ExplorerSidebarConstants.objectsTopAnchor)

                            DatabaseObjectBrowserView(
                                database: database,
                                connection: session.connection,
                                searchText: $viewModel.debouncedSearchText,
                                selectedSchemaName: $viewModel.selectedSchemaName,
                                expandedObjectGroups: $viewModel.expandedObjectGroups,
                                expandedObjectIDs: $viewModel.expandedObjectIDs,
                                pinnedObjectIDs: viewModel.pinnedObjectsBinding(for: database, connectionID: session.connection.id),
                                isPinnedSectionExpanded: viewModel.pinnedSectionExpandedBinding(for: database, connectionID: session.connection.id),
                                scrollTo: { id, anchor in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(id, anchor: anchor)
                                    }
                                }
                            )
                            .environmentObject(environmentState)
                            .padding(.horizontal, 4)
                        }
                    } else if let structure = session.databaseStructure,
                              !structure.databases.isEmpty {
                        noDatabaseSelectedView
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    } else {
                        loadingPlaceholder("Preparing database structure…")
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                    }
                case .idle:
                    loadingPlaceholder("Waiting to load database structure…")
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                case .failed(let message):
                    failureView(message: message)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                }
            } else {
                emptyStateView
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let session = selectedSession, session.selectedDatabaseName != nil else { return }
            if viewModel.isHoveringConnectedServers {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.isHoveringConnectedServers = false
                }
            }
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if let session = selectedSession {
            switch session.structureLoadingState {
            case .loading(let progress):
                let hasObjects = (session.databaseStructure?.databases ?? []).contains { !$0.schemas.isEmpty }
                if !hasObjects {
                    ExplorerLoadingOverlay(progress: progress, message: "Loading database objects…")
                        .padding(.top, 120)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            case .failed(let message):
                ExplorerLoadingOverlay(progress: nil, message: message ?? "Unable to load database objects")
                    .padding(.top, 120)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            default:
                EmptyView()
            }
        }
    }

    private var footerView: some View {
        Group {
            if let session = selectedSession,
               let structure = session.databaseStructure,
               let database = selectedDatabase(in: structure, for: session) {
                let hasExplorerContent = database.schemas.contains { !$0.objects.isEmpty }

                VStack(spacing: 0) {
                    Divider()
                        .opacity(hasExplorerContent ? 1 : 0)
                    footerControls(session: session, database: database)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyView()
            }
        }
    }

    private func footerControls(
        session: ConnectionSession,
        database: DatabaseInfo
    ) -> some View {
        let accentColor = projectStore.globalSettings.useServerColorAsAccent ? session.connection.color : Color.accentColor
        let controlBackground = Color.primary.opacity(0.04)
        let borderColor = Color.primary.opacity(0.08)
        let availableSchemas = database.schemas.filter { !$0.objects.isEmpty }
        let schemaPresentation: (displayName: String, selectedName: String?) = {
            if let schemaName = viewModel.selectedSchemaName {
                return (schemaName, schemaName)
            }
            if availableSchemas.count == 1, let onlySchema = availableSchemas.first?.name {
                return (onlySchema, onlySchema)
            }
            return ("All Schemas", nil)
        }()
        let schemaDisplayName = schemaPresentation.displayName
        let currentSchemaSelection = schemaPresentation.selectedName

        let shouldShowSchemaPicker = !availableSchemas.isEmpty && !viewModel.isSearchFieldFocused
        let creationOptions = creationOptions(for: session.connection.databaseType)
        let shouldShowAddButton = !viewModel.isSearchFieldFocused && !creationOptions.isEmpty

        return HStack(spacing: 6) {
            ExplorerFooterSearchField(
                text: $viewModel.searchText,
                isFocused: $viewModel.isSearchFieldFocused,
                placeholder: "Search",
                controlBackground: controlBackground,
                borderColor: borderColor,
                height: ExplorerSidebarConstants.bottomControlHeight
            )
            .frame(maxWidth: .infinity)

            if shouldShowAddButton {
                Menu {
                    ForEach(creationOptions, id: \.title) { item in
                        Button(action: {}) {
                            Label {
                                Text(item.title)
                            } icon: {
                                item.iconView(accentColor: accentColor)
                            }
                        }
                    }
                } label: {
                    ExplorerFooterActionButton(accentColor: accentColor)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .menuIndicator(.hidden)
                .transition(
                    .scale(scale: 0.95, anchor: .trailing)
                        .combined(with: .opacity)
                )
            }

            if shouldShowSchemaPicker {
                Menu {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedSchemaName = nil
                        }
                    } label: {
                        if currentSchemaSelection == nil {
                            Label("All Schemas", systemImage: "checkmark")
                        } else {
                            Text("All Schemas")
                        }
                    }

                    ForEach(availableSchemas, id: \.name) { schema in
                        let objectCount = schema.objects.count
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedSchemaName = schema.name
                            }
                        } label: {
                            if currentSchemaSelection == schema.name {
                                Label {
                                    Text("\(schema.name) (\(objectCount))")
                                } icon: {
                                    Image(systemName: "checkmark")
                                }
                            } else {
                                Text("\(schema.name) (\(objectCount))")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("schema")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(viewModel.selectedSchemaName == nil ? .secondary : accentColor)

                        Text(schemaDisplayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(viewModel.selectedSchemaName == nil ? Color.primary : accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minWidth: 132, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(controlBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(borderColor, lineWidth: 0.5)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func creationOptions(for databaseType: DatabaseType) -> [ExplorerCreationMenuItem] {
        switch databaseType {
        case .postgresql:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Materialized View", icon: .system("eye.fill")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt")),
                .init(title: "New Schema", icon: .asset("schema"))
            ]
        case .mysql:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt"))
            ]
        case .microsoftSQL:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye")),
                .init(title: "New Procedure", icon: .system("gearshape")),
                .init(title: "New Function", icon: .system("function")),
                .init(title: "New Trigger", icon: .system("bolt"))
            ]
        case .sqlite:
            return [
                .init(title: "New Table", icon: .system("tablecells")),
                .init(title: "New View", icon: .system("eye"))
            ]
        }
    }

    private func selectedDatabase(in structure: DatabaseStructure, for session: ConnectionSession) -> DatabaseInfo? {
        if let selectedName = session.selectedDatabaseName,
           let match = structure.databases.first(where: { $0.name == selectedName }) {
            return match
        }

        if !session.connection.database.isEmpty,
           let match = structure.databases.first(where: { $0.name == session.connection.database }) {
            return match
        }
        return nil
    }

    private func selectSession(_ session: ConnectionSession) {
        selectedConnectionID = session.connection.id
        environmentState.sessionManager.setActiveSession(session.id)
        viewModel.ensureServerExpanded(for: session.connection.id, sessions: sessions)
    }

    private func handleDatabaseSelection(_ databaseName: String, in session: ConnectionSession) {
        Task { @MainActor in
            await environmentState.loadSchemaForDatabase(databaseName, connectionSession: session)
            selectedConnectionID = session.connection.id
            viewModel.ensureServerExpanded(for: session.connection.id, sessions: sessions)
            viewModel.resetFilters(for: session, selectedSession: selectedSession)
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.isHoveringConnectedServers = false
                viewModel.expandedConnectedServerIDs.removeAll()
            }
        }
    }

    private func syncSelectionWithSessions() {
        viewModel.expandedServerIDs = viewModel.expandedServerIDs.filter { id in
            sessions.contains { $0.connection.id == id }
        }

        let currentIDs = Set(sessions.map { $0.connection.id })
        if viewModel.knownSessionIDs.isEmpty && !currentIDs.isEmpty {
            viewModel.isHoveringConnectedServers = true
            viewModel.expandedConnectedServerIDs.formUnion(currentIDs)
        }
        viewModel.knownSessionIDs = currentIDs

        if selectedConnectionID == nil || !sessions.contains(where: { $0.connection.id == selectedConnectionID }) {
            selectedConnectionID = sessions.first?.connection.id
        }

        if let id = selectedConnectionID {
            viewModel.ensureServerExpanded(for: id, sessions: sessions)
        }
    }

    private func loadingPlaceholder(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func failureView(message: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
            Text(message ?? "Failed to load database structure")
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await refreshSelectedSessionStructure() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var noDatabaseSelectedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Select a Database")
                .font(.system(size: 15, weight: .semibold))
            Text("Choose a database from the Currently Connected Servers list to browse schemas and objects.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Database Connected")
                .font(.system(size: 18, weight: .semibold))
            Text("Connect to a server to explore its schemas, tables, and functions.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func refreshSelectedSessionStructure() async {
        guard let session = selectedSession else { return }
        await environmentState.refreshDatabaseStructure(for: session.id)
    }

    @ViewBuilder
    private func stickyTopBar() -> some View {
        if let session = selectedSession, let databaseName = session.selectedDatabaseName {
            StickyTopBarContent(
                session: session,
                databaseName: databaseName,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let shouldOpen = !viewModel.isHoveringConnectedServers
                        viewModel.isHoveringConnectedServers = shouldOpen
                        if shouldOpen {
                            viewModel.expandedConnectedServerIDs.insert(session.connection.id)
                        }
                    }
                },
                onRefresh: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.isHoveringConnectedServers = true
                        viewModel.expandedConnectedServerIDs.insert(session.connection.id)
                    }
                    Task {
                        await environmentState.refreshDatabaseStructure(
                            for: session.id,
                            scope: .selectedDatabase,
                            databaseOverride: session.selectedDatabaseName
                        )
                    }
                }
            )
            .environmentObject(environmentState)
        }
    }
}
