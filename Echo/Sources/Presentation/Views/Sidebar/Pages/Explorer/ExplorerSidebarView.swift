import SwiftUI
import AppKit

struct ExplorerSidebarView: View {
    @Binding var selectedConnectionID: UUID?

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var selectedSchemaName: String?
    @State private var isSearchFieldFocused = false
    @State private var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType> = Set(SchemaObjectInfo.ObjectType.allCases)
    @State private var expandedServerIDs: Set<UUID> = []
    @State private var expandedObjectIDs: Set<String> = []
    @State private var expandedConnectedServerIDs: Set<UUID> = []
    @State private var isHoveringConnectedServers = false
    @State private var connectedServersHeight: CGFloat = 0
    @State private var knownSessionIDs: Set<UUID> = []

    // Control visibility of Connected Servers section
    // Set to false to hide the section (future: make this user-configurable)
    private let showConnectedServersSection = false

    private var sessions: [ConnectionSession] { appModel.sessionManager.sessions }

    private var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return appModel.sessionManager.sessionForConnection(id)
    }

    private var sessionAccentColor: Color {
        selectedSession?.connection.color ?? Color.accentColor
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if showConnectedServersSection,
                       let session = selectedSession,
                       session.selectedDatabaseName != nil,
                       !isHoveringConnectedServers {
                        stickyTopBar()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10, pinnedViews: .sectionHeaders) {
                            if showConnectedServersSection && (isHoveringConnectedServers || selectedSession?.selectedDatabaseName == nil) {
                                Section {
                                    Color.clear.frame(height: 0)
                                        .id(ExplorerSidebarConstants.connectedServersAnchor)

                                    connectedServersList
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.onAppear {
                                                    connectedServersHeight = geo.size.height
                                                }
                                            }
                                        )
                                } header: {
                                    ExplorerSectionHeader(title: "Connected Servers")
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            }

                            explorerContent(proxy: proxy)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, ExplorerSidebarConstants.scrollBottomPadding + ExplorerSidebarConstants.footerHeight)
                    }
                    .scrollIndicators(.hidden)
                    .contentShape(Rectangle())
                    .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
                    .overlay(alignment: .top) {
                        loadingOverlay
                    }
                    .onAppear(perform: syncSelectionWithSessions)
                    .onChange(of: sessions.map { $0.connection.id }) { _, _ in
                        syncSelectionWithSessions()
                    }
                    .onChange(of: selectedConnectionID) { _, newValue in
                        guard let id = newValue,
                              let session = appModel.sessionManager.sessionForConnection(id) else { return }
                        appModel.sessionManager.setActiveSession(session.id)
                        ensureServerExpanded(for: id)
                        resetFilters()
                        if !isHoveringConnectedServers {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: selectedSession?.selectedDatabaseName) { _, _ in
                        let hasDatabase = selectedSession?.selectedDatabaseName != nil
                        if !hasDatabase {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isHoveringConnectedServers = true
                            }
                        } else if !isHoveringConnectedServers {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                            }
                        }
                    }
                    .onChange(of: selectedSchemaName) { _, _ in
                        expandedObjectIDs.removeAll()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                        }
                    }
                    .onChange(of: searchText) { _, _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                        }
                    }
                }

                footerOverlay
            }
            .onAppear {
                if let focus = appModel.pendingExplorerFocus {
                    handleExplorerFocus(focus, proxy: proxy)
                }
            }
            .onChange(of: appModel.pendingExplorerFocus) { _, focus in
                guard let focus else { return }
                handleExplorerFocus(focus, proxy: proxy)
            }
        }
    }

    // MARK: - Connection Management

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        await MainActor.run {
            _ = withAnimation(.easeInOut(duration: 0.3)) {
                isHoveringConnectedServers = true
            }
        }

        await appModel.connect(to: connection)

        await MainActor.run {
            _ = withAnimation(.easeInOut(duration: 0.3)) {
                expandedConnectedServerIDs.insert(connection.id)
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

                    if !appModel.connections.isEmpty {
                        Divider()
                        Menu("Saved Connections") {
                            savedConnectionsMenuItems(parentID: nil)
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

                VStack(spacing: 12) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No connected servers")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sessions, id: \.connection.id) { session in
                    LiquidGlassServerCard(
                        session: session,
                        isSelected: session.connection.id == selectedConnectionID,
                        isExpanded: Binding(
                            get: { expandedConnectedServerIDs.contains(session.connection.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedConnectedServerIDs.insert(session.connection.id)
                                } else {
                                    expandedConnectedServerIDs.remove(session.connection.id)
                                }
                            }
                        ),
                        onSelectServer: {
                            let isExpandedNow = expandedConnectedServerIDs.contains(session.connection.id)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if isExpandedNow {
                                    isHoveringConnectedServers = true
                                } else if selectedSession?.selectedDatabaseName == nil {
                                    isHoveringConnectedServers = true
                                } else {
                                    isHoveringConnectedServers = false
                                }
                            }
                            if selectedConnectionID != session.connection.id {
                                selectSession(session)
                            }
                        },
                        onSelectDatabase: { database in
                            handleDatabaseSelection(database, in: session)
                        },
                        onRefresh: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isHoveringConnectedServers = true
                                expandedConnectedServerIDs.insert(session.connection.id)
                            }
                            Task {
                                await appModel.refreshDatabaseStructure(for: session.id, scope: .full)
                            }
                        },
                        onDisconnect: {
                            Task {
                                await appModel.disconnectSession(withID: session.id)
                            }
                        }
                    )
                    .environmentObject(appModel)
                }

                Menu {
                    Button("New Connection…") {
                        appState.showSheet(.connectionEditor)
                    }

                    if !appModel.connections.isEmpty {
                        Divider()
                        Menu("Saved Connections") {
                            savedConnectionsMenuItems(parentID: nil)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(sessionAccentColor)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(sessionAccentColor.opacity(0.18))
                            )
                        Text("Connect to Server")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(sessionAccentColor.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
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
                                searchText: $searchText,
                                selectedSchemaName: $selectedSchemaName,
                                expandedObjectGroups: $expandedObjectGroups,
                                expandedObjectIDs: $expandedObjectIDs,
                                scrollTo: { id, anchor in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(id, anchor: anchor)
                                    }
                                }
                            )
                            .environmentObject(appModel)
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
            if isHoveringConnectedServers {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isHoveringConnectedServers = false
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

    private var footerOverlay: some View {
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
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.clear)
            } else {
                EmptyView()
            }
        }
    }

    private func footerControls(
        session: ConnectionSession,
        database: DatabaseInfo
    ) -> some View {
        let accentColor = appModel.useServerColorAsAccent ? session.connection.color : Color.accentColor
        let controlBackground = Color.primary.opacity(0.04)
        let borderColor = Color.primary.opacity(0.08)
        let schemaDisplayName = selectedSchemaName ?? "All Schemas"
        let shouldShowSchemaPicker = database.schemas.count > 1 && !isSearchFieldFocused

        return HStack(spacing: 6) {
            NativeSearchField(
                text: $searchText,
                placeholder: "Search",
                isFocused: $isSearchFieldFocused
            )
            .frame(height: ExplorerSidebarConstants.bottomControlHeight)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .frame(maxWidth: .infinity)

            if shouldShowSchemaPicker {
                Menu {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSchemaName = nil
                        }
                    } label: {
                        if selectedSchemaName == nil {
                            Label("All Schemas", systemImage: "checkmark")
                        } else {
                            Text("All Schemas")
                        }
                    }

                    ForEach(database.schemas, id: \.name) { schema in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSchemaName = schema.name
                            }
                        } label: {
                            if selectedSchemaName == schema.name {
                                Label(schema.name, systemImage: "checkmark")
                            } else {
                                Text(schema.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("schema")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(selectedSchemaName == nil ? .secondary : accentColor)

                        Text(schemaDisplayName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(selectedSchemaName == nil ? Color.primary : accentColor)
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
        .animation(.easeInOut(duration: 0.2), value: shouldShowSchemaPicker)
        .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
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
        appModel.sessionManager.setActiveSession(session.id)
        ensureServerExpanded(for: session.connection.id)
    }

    private func handleDatabaseSelection(_ databaseName: String, in session: ConnectionSession) {
        Task { @MainActor in
            await appModel.loadSchemaForDatabase(databaseName, connectionSession: session)
            selectedConnectionID = session.connection.id
            ensureServerExpanded(for: session.connection.id)
            resetFilters()
            withAnimation(.easeInOut(duration: 0.3)) {
                isHoveringConnectedServers = false
                expandedConnectedServerIDs.removeAll()
            }
        }
    }

    private func ensureServerExpanded(for connectionID: UUID) {
        expandedServerIDs = expandedServerIDs.filter { id in
            sessions.contains { $0.connection.id == id }
        }
        expandedServerIDs.insert(connectionID)
    }

    private func resetFilters() {
        searchText = ""
        selectedSchemaName = nil
        expandedObjectGroups = Set(SchemaObjectInfo.ObjectType.allCases)
        expandedObjectIDs.removeAll()
    }

    private func syncSelectionWithSessions() {
        expandedServerIDs = expandedServerIDs.filter { id in
            sessions.contains { $0.connection.id == id }
        }

        let currentIDs = Set(sessions.map { $0.connection.id })
        if knownSessionIDs.isEmpty && !currentIDs.isEmpty {
            isHoveringConnectedServers = true
            expandedConnectedServerIDs.formUnion(currentIDs)
        }
        knownSessionIDs = currentIDs

        if selectedConnectionID == nil || !sessions.contains(where: { $0.connection.id == selectedConnectionID }) {
            selectedConnectionID = sessions.first?.connection.id
        }

        if let id = selectedConnectionID {
            ensureServerExpanded(for: id)
        }
    }

    private func expansionBinding(for connectionID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedServerIDs.contains(connectionID) },
            set: { newValue in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    if newValue {
                        expandedServerIDs.insert(connectionID)
                    } else {
                        expandedServerIDs.remove(connectionID)
                    }
                }
            }
        )
    }

    private func loadingPlaceholder(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
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
    }

    private func refreshSelectedSessionStructure() async {
        guard let session = selectedSession else { return }
        await appModel.refreshDatabaseStructure(for: session.id)
    }

    // MARK: - Sticky Top Bar

    @ViewBuilder
    private func stickyTopBar() -> some View {
        if let session = selectedSession, let databaseName = session.selectedDatabaseName {
            StickyTopBarContent(
                session: session,
                databaseName: databaseName,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let shouldOpen = !isHoveringConnectedServers
                        isHoveringConnectedServers = shouldOpen
                        if shouldOpen {
                            expandedConnectedServerIDs.insert(session.connection.id)
                        }
                    }
                },
                onRefresh: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHoveringConnectedServers = true
                        expandedConnectedServerIDs.insert(session.connection.id)
                    }
                    Task {
                        await appModel.refreshDatabaseStructure(
                            for: session.id,
                            scope: .selectedDatabase,
                            databaseOverride: session.selectedDatabaseName
                        )
                    }
                }
            )
            .environmentObject(appModel)
        }
    }
}

// MARK: - Sticky Top Bar Content

private struct StickyTopBarContent: View {
    @ObservedObject var session: ConnectionSession
    let databaseName: String
    let onTap: () -> Void
    let onRefresh: () -> Void

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var progressValue: Double? {
        if case .loading(let value) = session.structureLoadingState {
            return value
        }
        return nil
    }

    private var isUpdating: Bool {
        if case .loading = session.structureLoadingState {
            return true
        }
        return false
    }

    private var updateMessage: String {
        session.structureLoadingMessage ?? "Updating…"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: isUpdating ? 12 : 0) {
                HStack(spacing: 12) {
                    // Server logo/icon
                    if let logoData = session.connection.logo, let nsImage = NSImage(data: logoData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(session.connection.color.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(session.connection.databaseType.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 13, height: 13)
                                .foregroundStyle(session.connection.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.connection.connectionName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if let version = session.connection.serverVersion {
                                Text("•")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                Text(version)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }

                        Text("\(session.connection.username)@\(session.connection.host)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Refresh button (visible on hover)
                    if isHovered {
                        Button(action: {
                            onRefresh()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Database bubble with context menu
                    Text(databaseName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .background(.ultraThinMaterial, in: Capsule())
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(session.connection.color.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: session.connection.color.opacity(0.1), radius: 4, x: 0, y: 2)
                    .contextMenu {
                        if let structure = session.databaseStructure {
                            ForEach(structure.databases, id: \.name) { database in
                                Button {
                                    Task { @MainActor in
                                        await appModel.loadSchemaForDatabase(database.name, connectionSession: session)
                                    }
                                } label: {
                                    Label(database.name, systemImage: "database")
                                }
                            }
                        }
                    }
            }
                if isUpdating {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: min(max(progressValue ?? 0, 0), 1), total: 1)
                            .progressViewStyle(.linear)
                            .tint(session.connection.color)
                        Text(updateMessage)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isUpdating ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        appModel.useServerColorAsAccent ?
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(nsColor: .controlBackgroundColor).opacity(0.85),
                                session.connection.color.opacity(0.08)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(nsColor: .controlBackgroundColor).opacity(0.85),
                                Color(nsColor: .controlBackgroundColor).opacity(0.85)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        appModel.useServerColorAsAccent ?
                        session.connection.color.opacity(0.15) :
                        Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.2), value: isUpdating)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

private enum ExplorerSidebarConstants {
    static let scrollCoordinateSpace = "ExplorerSidebarScrollSpace"
    static let objectsTopAnchor = "ExplorerSidebarObjectsTop"
    static let connectedServersAnchor = "ExplorerSidebarConnectedServers"
    static let scrollBottomPadding: CGFloat = 32
    static let bottomControlHeight: CGFloat = 20
    static let footerHeight: CGFloat = 56
}

// MARK: - Section Header

private struct ExplorerSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Saved Connections Menu

extension ExplorerSidebarView {
    private func savedConnectionsMenuItems(parentID: UUID?) -> AnyView {
        let folders = appModel.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let connections = appModel.connections
            .filter { $0.folderID == parentID }
            .sorted { $0.connectionName.localizedCaseInsensitiveCompare($1.connectionName) == .orderedAscending }

        return AnyView(
            Group {
                ForEach(folders, id: \.id) { folder in
                    Menu(folder.name) {
                        savedConnectionsMenuItems(parentID: folder.id)
                    }
                }

                ForEach(connections, id: \.id) { connection in
                    Button(connection.connectionName.isEmpty ? connection.host : connection.connectionName) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHoveringConnectedServers = true
                        }
                        Task {
                            await connectToSavedConnection(connection)
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Explorer Focus Handling

extension ExplorerSidebarView {
    private func handleExplorerFocus(_ focus: ExplorerFocus, proxy: ScrollViewProxy) {
        Task {
            await processExplorerFocus(focus, proxy: proxy)
        }
    }

    private func processExplorerFocus(_ focus: ExplorerFocus, proxy: ScrollViewProxy) async {
        guard let session = await MainActor.run(body: {
            appModel.sessionManager.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run { appModel.pendingExplorerFocus = nil }
            return
        }

        await MainActor.run {
            searchText = ""
            if selectedConnectionID != focus.connectionID {
                selectedConnectionID = focus.connectionID
            }
            appModel.sessionManager.setActiveSession(session.id)
        }

        if session.selectedDatabaseName?.localizedCaseInsensitiveCompare(focus.databaseName) != .orderedSame {
            await appModel.reconnectSession(session, to: focus.databaseName)
        }

        await appModel.refreshDatabaseStructure(for: session.id, scope: .selectedDatabase, databaseOverride: focus.databaseName)

        guard let refreshedSession = await MainActor.run(body: {
            appModel.sessionManager.sessionForConnection(focus.connectionID)
        }) else {
            await MainActor.run { appModel.pendingExplorerFocus = nil }
            return
        }

        await MainActor.run {
            applyExplorerFocus(focus, session: refreshedSession, proxy: proxy)
            appModel.pendingExplorerFocus = nil
        }
    }

    private func applyExplorerFocus(_ focus: ExplorerFocus, session: ConnectionSession, proxy: ScrollViewProxy) {
        if selectedSchemaName?.caseInsensitiveCompare(focus.schemaName) != .orderedSame {
            selectedSchemaName = focus.schemaName
        }
        if !expandedObjectGroups.contains(focus.objectType) {
            expandedObjectGroups.insert(focus.objectType)
        }

        guard let structure = session.databaseStructure,
              let database = structure.databases.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.databaseName) == .orderedSame }),
              let schema = database.schemas.first(where: { $0.name.localizedCaseInsensitiveCompare(focus.schemaName) == .orderedSame }) else {
            return
        }

        if let object = schema.objects.first(where: { $0.type == focus.objectType && $0.name.localizedCaseInsensitiveCompare(focus.objectName) == .orderedSame }) {
            expandedObjectGroups.insert(object.type)
            let wasExpanded = expandedObjectIDs.contains(object.id)
            if !wasExpanded {
                DispatchQueue.main.async {
                    expandedObjectIDs.insert(object.id)
                }
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(object.id, anchor: .center)
            }
        }
    }
}

// MARK: - Auxiliary Controls

private struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = placeholder
        searchField.delegate = context.coordinator
        searchField.isBordered = false
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.focusRingType = .none
        searchField.controlSize = .small
        searchField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.cancelButtonCell = nil
            cell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor,
                    .font: NSFont.systemFont(ofSize: 12)
                ]
            )
            cell.controlSize = .small
        }
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        guard let cell = nsView.cell as? NSSearchFieldCell else { return }

        if cell.placeholderAttributedString?.string != placeholder {
            cell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor,
                    .font: NSFont.systemFont(ofSize: 12)
                ]
            )
        }

        if let searchButtonCell = cell.searchButtonCell {
            searchButtonCell.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
            searchButtonCell.imageScaling = .scaleProportionallyDown
            searchButtonCell.alignment = .center
        }

        if isFocused, nsView.window?.firstResponder != nsView.currentEditor() {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private var parent: NativeSearchField

        init(parent: NativeSearchField) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            updateFocusState(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            updateFocusState(false)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        private func updateFocusState(_ focused: Bool) {
            if parent.isFocused != focused {
                DispatchQueue.main.async {
                    self.parent.isFocused = focused
                }
            }
        }
    }
}

// MARK: - Liquid Glass Server Card

private struct LiquidGlassServerCard: View {
    let session: ConnectionSession
    let isSelected: Bool
    @Binding var isExpanded: Bool
    let onSelectServer: () -> Void
    let onSelectDatabase: (String) -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var availableDatabases: [DatabaseInfo] {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return []
    }

    private var progressValue: Double? {
        if case .loading(let value) = session.structureLoadingState {
            return value
        }
        return nil
    }

    private var isUpdating: Bool {
        if case .loading = session.structureLoadingState {
            return true
        }
        return false
    }

    private var shouldShowUpdateIndicator: Bool { isUpdating }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                let targetExpanded = !isExpanded
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded = targetExpanded
                }
                onSelectServer()
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .contextMenu {
                Button {
                    onRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    onDisconnect()
                } label: {
                    Label("Disconnect", systemImage: "bolt.slash")
                }
                Divider()
                if !availableDatabases.isEmpty {
                    ForEach(availableDatabases, id: \.name) { database in
                        Button {
                            onSelectDatabase(database.name)
                        } label: {
                            Label(database.name, systemImage: "database")
                        }
                    }
                }
            }

            // Expanded database list
            if isExpanded && !availableDatabases.isEmpty {
                databaseList
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .onChange(of: session.structureLoadingState) { _, newValue in
            if case .loading = newValue, isSelected, !isExpanded {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded = true
                }
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: shouldShowUpdateIndicator ? 12 : 0) {
            HStack(spacing: 12) {
                connectionIcon
                connectionInfo
                Spacer(minLength: 8)
                if isHovered || isUpdating {
                    refreshButton
                }
                databaseSelector
            }

            if shouldShowUpdateIndicator {
                updatingIndicator
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, shouldShowUpdateIndicator ? 16 : 12)
        .background(cardBackground)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.2), value: shouldShowUpdateIndicator)
    }

    @ViewBuilder
    private var updatingIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let progressValue {
                ProgressView(value: min(max(progressValue, 0), 1), total: 1)
                    .progressViewStyle(.linear)
                    .tint(session.connection.color)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(session.connection.color)
            }
            Text(session.structureLoadingMessage ?? "Updating…")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var connectionIcon: some View {
        if let logoData = session.connection.logo, let nsImage = NSImage(data: logoData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(session.connection.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(session.connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(session.connection.color)
            }
        }
    }

    @ViewBuilder
    private var connectionInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(session.connection.connectionName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let version = session.connection.serverVersion {
                    Text("•")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(version)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Text("\(session.connection.username)@\(session.connection.host)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var databaseSelector: some View {
        if availableDatabases.count == 1 {
            // Single database - show as selected bubble
            if let currentDB = session.selectedDatabaseName {
                selectedDatabaseBubble(currentDB)
            }
        } else if availableDatabases.count > 1 {
            // Multiple databases - show count badge
            Menu {
                ForEach(availableDatabases, id: \.name) { database in
                    Button(database.name) {
                        onSelectDatabase(database.name)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cylinder.fill")
                        .font(.system(size: 9, weight: .medium))
                    Text("\(availableDatabases.count)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .overlay(
                    Capsule()
                        .strokeBorder(session.connection.color.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: session.connection.color.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func selectedDatabaseBubble(_ databaseName: String) -> some View {
        Text(databaseName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule()
                    .strokeBorder(session.connection.color.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: session.connection.color.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(nsColor: .controlBackgroundColor).opacity(0.85),
                        Color(nsColor: .controlBackgroundColor).opacity(0.85)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private var databaseList: some View {
        VStack(spacing: 4) {
            ForEach(availableDatabases, id: \.name) { database in
                DatabaseBubble(
                    database: database,
                    isSelected: database.name == session.selectedDatabaseName,
                    serverColor: session.connection.color,
                    onSelect: { onSelectDatabase(database.name) },
                    onRefresh: {
                        Task {
                            await appModel.refreshDatabaseStructure(
                                for: session.id,
                                scope: .selectedDatabase,
                                databaseOverride: database.name
                            )
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func databaseStats(for database: DatabaseInfo) -> (tables: Int, views: Int, functions: Int, triggers: Int) {
        var tables = 0
        var views = 0
        var functions = 0
        var triggers = 0

        for schema in database.schemas {
            for object in schema.objects {
                switch object.type {
                case .table:
                    tables += 1
                case .view, .materializedView:
                    views += 1
                case .function:
                    functions += 1
                case .trigger:
                    triggers += 1
                }
            }
        }

        return (tables, views, functions, triggers)
    }
}

// MARK: - Database Bubble

private struct DatabaseBubble: View {
    let database: DatabaseInfo
    let isSelected: Bool
    let serverColor: Color
    let onSelect: () -> Void
    let onRefresh: () -> Void

    @State private var isHovered = false

    private var stats: (tables: Int, views: Int, functions: Int, triggers: Int) {
        var tables = 0
        var views = 0
        var functions = 0
        var triggers = 0

        for schema in database.schemas {
            for object in schema.objects {
                switch object.type {
                case .table:
                    tables += 1
                case .view, .materializedView:
                    views += 1
                case .function:
                    functions += 1
                case .trigger:
                    triggers += 1
                }
            }
        }

        return (tables, views, functions, triggers)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(serverColor)
                        .frame(width: 6, height: 6)
                    Text(database.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? serverColor : .primary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(serverColor)
                    }
                }

                // Stats row
                HStack(spacing: 10) {
                    StatBadge(icon: "tablecells", count: stats.tables, color: .blue)
                    StatBadge(icon: "eye", count: stats.views, color: .purple)
                    StatBadge(icon: "function", count: stats.functions, color: .orange)
                    StatBadge(icon: "bolt", count: stats.triggers, color: .yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? serverColor.opacity(0.16)
                            : (isHovered ? Color.primary.opacity(0.05) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onRefresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button {
                onSelect()
            } label: {
                Label("Connect", systemImage: "bolt.horizontal.circle")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Legacy Connected Server Card (keeping for reference)

private struct ConnectedServerCard: View {
    let session: ConnectionSession
    let isSelected: Bool
    @Binding var isExpanded: Bool
    let showCurrentDatabase: Bool
    let onSelectServer: () -> Void
    let onPickDatabase: (String) -> Void

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var availableDatabases: [DatabaseInfo] {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return []
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded, !availableDatabases.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                ScrollView {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                        ForEach(availableDatabases) { database in
                            CompactDatabaseCard(
                                database: database,
                                isSelected: database.name == session.selectedDatabaseName,
                                serverColor: session.connection.color,
                                onSelect: {
                                    onPickDatabase(database.name)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 160)
                .scrollIndicators(.hidden)
            }
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(isHovered || isExpanded ? 0.14 : 0.05), radius: isExpanded ? 12 : 6, x: 0, y: isExpanded ? 8 : 3)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isExpanded)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.connection.connectionName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(session.connection.username)@\(session.connection.host)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if showCurrentDatabase, let database = session.selectedDatabaseName {
                    Text(database)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(session.connection.color.opacity(0.18), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(session.connection.color.opacity(0.35), lineWidth: 0.6)
                        )
                        .shadow(color: session.connection.color.opacity(0.2), radius: 4, x: 0, y: 2)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }
            .onTapGesture(count: 2) {
                onSelectServer()
            }
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(session.connection.color.opacity(0.18))
                .frame(width: 32, height: 32)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(session.connection.color.opacity(0.35), lineWidth: 1)
            Image(session.connection.databaseType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
                .foregroundStyle(session.connection.color)
        }
        .shadow(color: session.connection.color.opacity(0.15), radius: 2, x: 0, y: 1)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected ? session.connection.color.opacity(0.18) : Color.primary.opacity(isHovered ? 0.07 : 0.04)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? session.connection.color.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 0.9)
    }
}

// MARK: - Database Card

private struct CompactDatabaseCard: View {
    let database: DatabaseInfo
    let isSelected: Bool
    let serverColor: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    private var schemaCountText: String {
        let count = database.schemas.isEmpty ? database.schemaCount : database.schemas.count
        return "\(count)"
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(serverColor)
                        .frame(width: 4, height: 4)
                    Text(database.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? serverColor : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(serverColor)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(schemaCountText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? serverColor.opacity(0.08) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? serverColor.opacity(0.3) : (isHovered ? Color.primary.opacity(0.05) : .clear),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Loading Overlay

private struct ExplorerLoadingOverlay: View {
    let progress: Double?
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
            } else {
                ProgressView()
                    .scaleEffect(0.85)
            }

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 12)
    }
}
