import SwiftUI

struct ExplorerSidebarView: View {
    @Binding var selectedConnectionID: UUID?

    @EnvironmentObject private var appModel: AppModel

    @State private var searchText = ""
    @State private var selectedSchemaName: String?
    @State private var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType> = Set(SchemaObjectInfo.ObjectType.allCases)
    @State private var expandedServerIDs: Set<UUID> = []
    @State private var expandedObjectIDs: Set<String> = []
    @State private var isHoveringConnectedServers = false
    @State private var connectedServersHeight: CGFloat = 0
    @State private var showingConnectionPicker = false

    private var sessions: [ConnectionSession] { appModel.sessionManager.sessions }

    private var selectedSession: ConnectionSession? {
        guard let id = selectedConnectionID else { return nil }
        return appModel.sessionManager.sessionForConnection(id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .center) {
                VStack(spacing: 0) {
                    // Sticky top bar when database is selected and not hovering
                    if let session = selectedSession, session.selectedDatabaseName != nil, !isHoveringConnectedServers {
                        stickyTopBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Main scroll content
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18, pinnedViews: .sectionHeaders) {
                            // Connected Servers section (shown when hovering or no database selected)
                            if isHoveringConnectedServers || selectedSession?.selectedDatabaseName == nil {
                                Section {
                                    connectedServersList
                                        .padding(.top, 12)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.onAppear {
                                                    connectedServersHeight = geo.size.height
                                                }
                                            }
                                        )
                                } header: {
                                    ExplorerSectionHeader(title: "Connected Servers")
                                        .padding(.horizontal, 16)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            }

                            explorerContent(proxy: proxy)
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
                    .onAppear(perform: syncSelectionWithSessions)
                    .onChange(of: sessions.map { $0.connection.id }) { _ in
                        syncSelectionWithSessions()
                    }
                    .onChange(of: selectedConnectionID) { newValue in
                        guard let id = newValue,
                              let session = appModel.sessionManager.sessionForConnection(id) else { return }
                        appModel.sessionManager.setActiveSession(session.id)
                        ensureServerExpanded(for: id)
                        resetFilters()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                        }
                    }
                    .onChange(of: selectedSession?.selectedDatabaseName ?? "") { _ in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                        }
                    }
                    .onChange(of: selectedSchemaName) { _ in
                        expandedObjectIDs.removeAll()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                        }
                    }
                    .onChange(of: searchText) { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                        }
                    }
                    // Hover detection for connected servers
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let shouldHover = location.y < connectedServersHeight + 60 // Adding some buffer
                            if shouldHover != isHoveringConnectedServers {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isHoveringConnectedServers = shouldHover
                                }
                            }
                        case .ended:
                            if isHoveringConnectedServers {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isHoveringConnectedServers = false
                                }
                            }
                        }
                    }
                }

                loadingOverlay
            }
            .safeAreaInset(edge: .bottom) {
                bottomControls
            }
            .sheet(isPresented: $showingConnectionPicker) {
                // TODO: Connection picker sheet
                Text("Connection Picker Coming Soon")
                    .padding()
            }
        }
    }

    // MARK: - Connection Management

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        // This would integrate with the existing connection logic
        // For now, we'll show that the intent is there
        print("Connecting to: \(connection.connectionName)")
    }

    @ViewBuilder
    private var connectedServersList: some View {
        if sessions.isEmpty {
            VStack(spacing: 16) {
                Button("Connect to Server") {
                    showingConnectionPicker = true
                }
                .buttonStyle(.borderedProminent)

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
            VStack(spacing: 12) {
                ForEach(sessions, id: \.connection.id) { session in
                    LiquidGlassServerCard(
                        session: session,
                        isSelected: session.connection.id == selectedConnectionID,
                        onSelectServer: { selectSession(session) },
                        onSelectDatabase: { handleDatabaseSelection($0, in: session) }
                    )
                    .environmentObject(appModel)
                }

                // Add new server connection button
                Menu {
                    // Recent connections from saved connections
                    if !appModel.connections.isEmpty {
                        Section("Saved Connections") {
                            ForEach(appModel.connections.prefix(5), id: \.id) { connection in
                                Button {
                                    Task {
                                        await connectToSavedConnection(connection)
                                    }
                                } label: {
                                    Label(connection.connectionName, systemImage: connection.databaseType.iconName)
                                }
                            }
                        }
                        Divider()
                    }

                    Button("New Connection...") {
                        showingConnectionPicker = true
                    }

                    Button("Browse Saved Connections...") {
                        // TODO: Switch to connections tab
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Connect to Server")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func explorerContent(proxy: ScrollViewProxy) -> some View {
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
                            coordinateSpaceName: ExplorerSidebarConstants.scrollCoordinateSpace,
                            scrollTo: { id, anchor in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(id, anchor: anchor)
                                }
                            }
                        )
                        .environmentObject(appModel)
                        .padding(.horizontal, 12)
                    }
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

    @ViewBuilder
    private var bottomControls: some View {
        if let session = selectedSession,
           let structure = session.databaseStructure,
           let database = selectedDatabase(in: structure, for: session) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    SearchField(text: $searchText)
                    if database.schemas.count > 1 {
                        SchemaPicker(selection: $selectedSchemaName, database: database)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.40))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
    }

    private func selectedDatabase(in structure: DatabaseStructure, for session: ConnectionSession) -> DatabaseInfo? {
        if let selectedName = session.selectedDatabaseName,
           let match = structure.databases.first(where: { $0.name == selectedName }) {
            return match
        }
        return structure.databases.first
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
    private var stickyTopBar: some View {
        if let session = selectedSession, let databaseName = session.selectedDatabaseName {
            HStack(spacing: 12) {
                // Server icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(session.connection.color.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: session.connection.databaseType.iconName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(session.connection.color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.connection.connectionName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(databaseName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHoveringConnectedServers = true
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Rectangle())
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(.quaternary),
                alignment: .bottom
            )
        }
    }
}

private enum ExplorerSidebarConstants {
    static let scrollCoordinateSpace = "ExplorerSidebarScrollSpace"
    static let objectsTopAnchor = "ExplorerSidebarObjectsTop"
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
        .padding(.bottom, 4)
        .background(Color.clear)
    }
}

// MARK: - Bottom Controls Helpers

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search objects", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .frame(maxWidth: .infinity)
    }
}

private struct SchemaPicker: View {
    @Binding var selection: String?
    let database: DatabaseInfo

    var body: some View {
        Picker("", selection: $selection) {
            Text("All Schemas")
                .tag(nil as String?)
            ForEach(database.schemas, id: \.name) { schema in
                Text("\(schema.name) (\(schema.objects.count))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .tag(schema.name as String?)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - Liquid Glass Server Card

private struct LiquidGlassServerCard: View {
    let session: ConnectionSession
    let isSelected: Bool
    let onSelectServer: () -> Void
    let onSelectDatabase: (String) -> Void

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false
    @State private var showingDatabasePicker = false

    private var availableDatabases: [DatabaseInfo] {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return []
    }

    var body: some View {
        Button {
            onSelectServer()
        } label: {
            HStack(spacing: 12) {
                // Connection icon with Liquid Glass styling
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(session.connection.color.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(session.connection.color.opacity(0.2), lineWidth: 1)
                        )

                    Image(systemName: session.connection.databaseType.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(session.connection.color)
                }
                .shadow(color: session.connection.color.opacity(0.2), radius: 4, x: 0, y: 2)

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

                // Database selector
                if let currentDB = session.selectedDatabaseName {
                    // Currently selected database with context menu
                    Button {
                        // This will be handled by context menu
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(session.connection.color)
                                .frame(width: 6, height: 6)
                            Text(currentDB)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(session.connection.color.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                        .shadow(color: session.connection.color.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !availableDatabases.isEmpty {
                            ForEach(availableDatabases, id: \.name) { database in
                                Button(database.name) {
                                    onSelectDatabase(database.name)
                                }
                            }
                        }
                    }
                } else {
                    // No database selected - show database picker icon
                    Button {
                        // Show database picker
                    } label: {
                        Image(systemName: "cylinder")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.quaternary, lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !availableDatabases.isEmpty {
                            ForEach(availableDatabases, id: \.name) { database in
                                Button(database.name) {
                                    onSelectDatabase(database.name)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? session.connection.color.opacity(0.08) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? session.connection.color.opacity(0.3) : .quaternary,
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.1 : 0.03),
                radius: isHovered ? 8 : 3,
                x: 0,
                y: isHovered ? 4 : 1
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
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
            Image(systemName: session.connection.databaseType.iconName)
                .font(.system(size: 15, weight: .medium))
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
                        isSelected ? serverColor.opacity(0.3) : (isHovered ? .quaternary : .clear),
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
