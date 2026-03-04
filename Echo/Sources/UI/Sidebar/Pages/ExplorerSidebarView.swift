import SwiftUI
import AppKit

@MainActor
private final class ExplorerDebugLogState {
    static let shared = ExplorerDebugLogState()
    var lastDatabaseBySession: [UUID: String] = [:]
}

struct ExplorerSidebarView: View {
    @Binding var selectedConnectionID: UUID?

    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedSchemaName: String?
    @State private var isSearchFieldFocused = false
    @State private var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType> = Set(SchemaObjectInfo.ObjectType.allCases)
    @State private var expandedServerIDs: Set<UUID> = []
    @State private var expandedObjectIDs: Set<String> = []
    @State private var expandedConnectedServerIDs: Set<UUID> = []
    @State private var isHoveringConnectedServers = false
    @State private var connectedServersHeight: CGFloat = 0
    @State private var knownSessionIDs: Set<UUID> = []
    @State private var pinnedObjectIDsByDatabase: [String: Set<String>] = [:]
    @State private var pinnedSectionExpandedByDatabase: [String: Bool] = [:]
    @State private var searchDebounceTask: Task<Void, Never>?
    
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
            VStack(spacing: 0) {
                if showConnectedServersSection,
                   let session = selectedSession,
                   session.selectedDatabaseName != nil,
                   !isHoveringConnectedServers {
                    stickyTopBar()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10, pinnedViews: .sectionHeaders) {
                            if showConnectedServersSection && (isHoveringConnectedServers || selectedSession?.selectedDatabaseName == nil) {
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
                            if isSearchFieldFocused {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSearchFieldFocused = false
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
                    .onAppear(perform: syncSelectionWithSessions)
                    .onChange(of: sessions.map { $0.connection.id }) { _, _ in
                        syncSelectionWithSessions()
                    }
                    .onChange(of: selectedConnectionID) { _, newValue in
                        guard let id = newValue,
                              let session = appModel.sessionManager.sessionForConnection(id) else { return }
                        appModel.sessionManager.setActiveSession(session.id)
                        ensureServerExpanded(for: id)
                        resetFilters(for: session)
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
                    .onChange(of: selectedSchemaName) { oldValue, newValue in
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
                        if !expandedObjectIDs.isEmpty {
                            expandedObjectIDs.removeAll()
                        }
                        proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        let trimmedOld = oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNew = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedOld != trimmedNew else { return }

                        searchDebounceTask?.cancel()
                        if trimmedNew.isEmpty {
                            searchDebounceTask = Task { @MainActor in
                                debouncedSearchText = ""
                                await Task.yield()
                                guard !Task.isCancelled else { return }
                                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                            }
                        } else {
                            let pendingText = newValue
                            searchDebounceTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                guard !Task.isCancelled else { return }
                                debouncedSearchText = pendingText
                                await Task.yield()
                                guard !Task.isCancelled else { return }
                                proxy.scrollTo(ExplorerSidebarConstants.objectsTopAnchor, anchor: .top)
                            }
                        }
                    }

                    footerView
                }
            }
            .onAppear {
                debouncedSearchText = searchText
                if let focus = navigationStore.pendingExplorerFocus {
                    handleExplorerFocus(focus, proxy: proxy)
                }
            }
            .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in
                guard let focus else { return }
                handleExplorerFocus(focus, proxy: proxy)
            }
            .onDisappear {
                searchDebounceTask?.cancel()
                searchDebounceTask = nil
            }
        }
        .background(
            ExplorerSidebarFocusResetter(isSearchFieldFocused: $isSearchFieldFocused)
                .allowsHitTesting(false)
        )
    }

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        await MainActor.run {
            let _: Void = withAnimation(.easeInOut(duration: 0.3)) {
                isHoveringConnectedServers = true
            }
        }

        await appModel.connect(to: connection)

        await MainActor.run {
            let _: Void = withAnimation(.easeInOut(duration: 0.3)) {
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

                    if !connectionStore.connections.isEmpty {
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
                            get: { expandedConnectedServerIDs.contains(session.connection.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedConnectedServerIDs.insert(session.connection.id)
                                } else {
                                    expandedConnectedServerIDs.remove(session.connection.id)
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
                    .environmentObject(appModel)
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
                                searchText: $debouncedSearchText,
                                selectedSchemaName: $selectedSchemaName,
                                expandedObjectGroups: $expandedObjectGroups,
                                expandedObjectIDs: $expandedObjectIDs,
                                pinnedObjectIDs: pinnedObjectsBinding(for: database, connectionID: session.connection.id),
                                isPinnedSectionExpanded: pinnedSectionExpandedBinding(for: database, connectionID: session.connection.id),
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
            if let selectedSchemaName {
                return (selectedSchemaName, selectedSchemaName)
            }
            if availableSchemas.count == 1, let onlySchema = availableSchemas.first?.name {
                return (onlySchema, onlySchema)
            }
            return ("All Schemas", nil)
        }()
        let schemaDisplayName = schemaPresentation.displayName
        let currentSchemaSelection = schemaPresentation.selectedName

        let shouldShowSchemaPicker = !availableSchemas.isEmpty && !isSearchFieldFocused
        let creationOptions = creationOptions(for: session.connection.databaseType)
        let shouldShowAddButton = !isSearchFieldFocused && !creationOptions.isEmpty

        return HStack(spacing: 6) {
            ExplorerFooterSearchField(
                text: $searchText,
                isFocused: $isSearchFieldFocused,
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
                            selectedSchemaName = nil
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
                                selectedSchemaName = schema.name
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
        appModel.sessionManager.setActiveSession(session.id)
        ensureServerExpanded(for: session.connection.id)
    }

    private func handleDatabaseSelection(_ databaseName: String, in session: ConnectionSession) {
        Task { @MainActor in
            await appModel.loadSchemaForDatabase(databaseName, connectionSession: session)
            selectedConnectionID = session.connection.id
            ensureServerExpanded(for: session.connection.id)
            resetFilters(for: session)
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

    private func resetFilters(for session: ConnectionSession? = nil) {
        if !searchText.isEmpty {
            searchText = ""
            debouncedSearchText = ""
            searchDebounceTask?.cancel()
        }
        if selectedSchemaName != nil {
            selectedSchemaName = nil
        }
        if !expandedObjectIDs.isEmpty {
            expandedObjectIDs.removeAll()
        }
        let targetSession = session ?? selectedSession
        let supportedSet = Set(supportedObjectTypes(for: targetSession))
        if supportedSet.isEmpty {
            if !expandedObjectGroups.isEmpty {
                expandedObjectGroups.removeAll()
            }
        } else if expandedObjectGroups != supportedSet {
            expandedObjectGroups = supportedSet
        }
    }

    private func pinnedStorageKey(connectionID: UUID, databaseName: String) -> String {
        "\(connectionID.uuidString)#\(databaseName)"
    }

    private func supportedObjectTypes(for session: ConnectionSession?) -> [SchemaObjectInfo.ObjectType] {
        guard let session else { return SchemaObjectInfo.ObjectType.allCases }
        return SchemaObjectInfo.ObjectType.supported(for: session.connection.databaseType)
    }

    private func pinnedObjectsBinding(for database: DatabaseInfo, connectionID: UUID) -> Binding<Set<String>> {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: database.name)
        return Binding(
            get: { pinnedObjectIDsByDatabase[key] ?? [] },
            set: { newValue in
                if newValue.isEmpty {
                    pinnedObjectIDsByDatabase.removeValue(forKey: key)
                } else {
                    pinnedObjectIDsByDatabase[key] = newValue
                }
            }
        )
    }

    private func pinnedSectionExpandedBinding(for database: DatabaseInfo, connectionID: UUID) -> Binding<Bool> {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: database.name)
        return Binding(
            get: { pinnedSectionExpandedByDatabase[key] ?? true },
            set: { newValue in
                pinnedSectionExpandedByDatabase[key] = newValue
            }
        )
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
        await appModel.refreshDatabaseStructure(for: session.id)
    }

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

private struct StickyTopBarContent: View {
    @ObservedObject var session: ConnectionSession
    let databaseName: String
    let onTap: () -> Void
    let onRefresh: () -> Void

    @Environment(ProjectStore.self) private var projectStore
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
                        projectStore.globalSettings.useServerColorAsAccent ?
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
                        projectStore.globalSettings.useServerColorAsAccent ?
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
}

extension ExplorerSidebarView {
    private func savedConnectionsMenuItems(parentID: UUID?) -> AnyView {
        let folders = connectionStore.folders
            .filter { $0.kind == .connections && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let connections = connectionStore.connections
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
            await MainActor.run { navigationStore.pendingExplorerFocus = nil }
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
            await MainActor.run { navigationStore.pendingExplorerFocus = nil }
            return
        }

        await MainActor.run {
            applyExplorerFocus(focus, session: refreshedSession, proxy: proxy)
            navigationStore.pendingExplorerFocus = nil
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

private struct ExplorerFooterSearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let controlBackground: Color
    let borderColor: Color
    let height: CGFloat

    @FocusState private var internalFocus: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 1)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($internalFocus)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(borderColor, lineWidth: 0.5)
        )
        .onChange(of: internalFocus) { _, newValue in
            guard newValue != isFocused else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = newValue
            }
        }
        .onChange(of: isFocused) { _, newValue in
            guard newValue != internalFocus else { return }
            internalFocus = newValue
        }
    }
}

private struct ExplorerCreationMenuItem: Hashable {
    enum Icon: Hashable {
        case system(String)
        case asset(String)
    }

    let title: String
    let icon: Icon

    @ViewBuilder
    func iconView(accentColor: Color) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(accentColor)
        }
    }
}

private struct ExplorerFooterActionButton: View {
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            accentColor.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 0.6)
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accentColor)
        }
        .frame(width: 26, height: 26)
        .shadow(color: accentColor.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

#if os(macOS)
private struct ExplorerSidebarFocusResetter: NSViewRepresentable {
    @Binding var isSearchFieldFocused: Bool

    func makeNSView(context: Context) -> FocusResetView {
        FocusResetView()
    }

    func updateNSView(_ nsView: FocusResetView, context: Context) {
        nsView.onDismiss = { [binding = $isSearchFieldFocused] in
            DispatchQueue.main.async {
                guard binding.wrappedValue else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    binding.wrappedValue = false
                }
            }
        }
        nsView.isSearchFieldFocused = isSearchFieldFocused
    }

    @MainActor
    final class FocusResetView: NSView {
        var onDismiss: (() -> Void)?
        var isSearchFieldFocused: Bool = false {
            didSet { updateMonitor() }
        }

        private var monitor: Any?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                removeMonitor()
            }
            super.viewWillMove(toWindow: newWindow)
        }

        @MainActor deinit {
            removeMonitor()
        }

        private func updateMonitor() {
            guard window != nil else {
                removeMonitor()
                return
            }

            if isSearchFieldFocused {
                installMonitorIfNeeded()
            } else {
                removeMonitor()
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self else { return event }
                guard let window = self.window else {
                    self.onDismiss?()
                    return event
                }

                if event.window !== window {
                    self.onDismiss?()
                    return event
                }

                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)
                if !self.bounds.contains(locationInView) {
                    self.onDismiss?()
                }

                return event
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}
#else
private struct ExplorerSidebarFocusResetter: View {
    @Binding var isSearchFieldFocused: Bool
    var body: some View {
        EmptyView()
    }
}
#endif

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
