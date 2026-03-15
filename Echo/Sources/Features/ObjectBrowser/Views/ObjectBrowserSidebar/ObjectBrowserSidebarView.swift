import SwiftUI
import AppKit
import EchoSense
import PostgresKit
import SQLServerKit

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
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear
                        .frame(height: SpacingTokens.xxs2)
                        .id(ExplorerSidebarConstants.objectsTopAnchor)

                    if sessions.isEmpty {
                        emptyStateView
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.top, SpacingTokens.xl)
                    } else {
                        ForEach(sessions, id: \.connection.id) { session in
                            if sidebarSearchQuery == nil || serverMatchesSearch(session) {
                                serverSection(session: session, proxy: proxy)
                            }
                        }

                        Color.clear
                            .frame(height: ExplorerSidebarConstants.bottomControlHeight + ExplorerSidebarConstants.scrollBottomPadding + SpacingTokens.md2)
                    }
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .contentMargins(.zero, for: .scrollContent)
            .contentShape(Rectangle())
            .coordinateSpace(name: ExplorerSidebarConstants.scrollCoordinateSpace)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !sessions.isEmpty {
                    globalFooterView
                        .padding(.top, SpacingTokens.xxs2)
                        .padding(.bottom, SpacingTokens.xxs2)
                        .background(ColorTokens.Background.primary)
                }
            }
            .task {
                syncSelectionWithSessions(proxy: proxy)
                viewModel.setupSearchDebounce(proxy: proxy)
            }
            .onChange(of: sessions.map { $0.connection.id }) { _, _ in syncSelectionWithSessions(proxy: proxy) }
            .onChange(of: selectedConnectionID) { _, newValue in
                guard let id = newValue, let session = environmentState.sessionCoordinator.sessionForConnection(id) else { return }
                environmentState.sessionCoordinator.setActiveSession(session.id)
            }
            .onAppear {
                viewModel.debouncedSearchText = viewModel.searchText
                if let focus = navigationStore.pendingExplorerFocus { handleExplorerFocus(focus, proxy: proxy) }
            }
            .onChange(of: navigationStore.pendingExplorerFocus) { _, focus in if let focus { handleExplorerFocus(focus, proxy: proxy) } }
            .onDisappear { viewModel.stopSearchDebounce() }
        }
        .environmentObject(viewModel)
        .accessibilityIdentifier("object-browser-sidebar")
        .background(ExplorerSidebarFocusResetter(isSearchFieldFocused: $viewModel.isSearchFieldFocused).allowsHitTesting(false))
        .sheet(isPresented: $viewModel.showNewJobSheet) {
            if let connID = viewModel.newJobSessionID,
               let session = environmentState.sessionCoordinator.sessionForConnection(connID) {
                NewAgentJobSheet(session: session, environmentState: environmentState) {
                    viewModel.showNewJobSheet = false
                    loadAgentJobs(session: session)
                }
            }
        }
        .sheet(isPresented: $viewModel.showDatabaseProperties) {
            if let dbName = viewModel.propertiesDatabaseName,
               let connID = viewModel.propertiesConnectionID,
               let session = environmentState.sessionCoordinator.sessionForConnection(connID) {
                DatabasePropertiesSheet(
                    databaseName: dbName,
                    session: session,
                    environmentState: environmentState,
                    onDismiss: { viewModel.showDatabaseProperties = false }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSecurityLoginSheet) {
            if let connID = viewModel.securityLoginSheetSessionID,
               let session = environmentState.sessionCoordinator.sessionForConnection(connID) {
                SecurityLoginSheet(
                    session: session,
                    environmentState: environmentState,
                    existingLoginName: viewModel.securityLoginSheetEditName
                ) {
                    viewModel.showSecurityLoginSheet = false
                    loadServerSecurity(session: session)
                }
            }
        }
        .sheet(isPresented: $viewModel.showSecurityUserSheet) {
            if let connID = viewModel.securityUserSheetSessionID,
               let session = environmentState.sessionCoordinator.sessionForConnection(connID),
               let dbName = viewModel.securityUserSheetDatabaseName {
                SecurityUserSheet(
                    session: session,
                    environmentState: environmentState,
                    databaseName: dbName,
                    existingUserName: viewModel.securityUserSheetEditName
                ) {
                    viewModel.showSecurityUserSheet = false
                    // Reload database-level security
                    if let structure = session.databaseStructure,
                       let db = structure.databases.first(where: { $0.name == dbName }) {
                        loadDatabaseSecurity(database: db, session: session)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showSecurityPGRoleSheet) {
            if let connID = viewModel.securityPGRoleSheetSessionID,
               let session = environmentState.sessionCoordinator.sessionForConnection(connID) {
                SecurityPGRoleSheet(
                    session: session,
                    environmentState: environmentState,
                    existingRoleName: viewModel.securityPGRoleSheetEditName
                ) {
                    viewModel.showSecurityPGRoleSheet = false
                    loadServerSecurity(session: session)
                }
            }
        }
        .alert(
            "Drop \"\(viewModel.dropDatabaseTarget?.databaseName ?? "")\"?",
            isPresented: $viewModel.showDropDatabaseAlert
        ) {
            Button("Cancel", role: .cancel) {
                viewModel.dropDatabaseTarget = nil
            }
            Button("Drop", role: .destructive) {
                guard let target = viewModel.dropDatabaseTarget else { return }
                viewModel.dropDatabaseTarget = nil
                guard let session = environmentState.sessionCoordinator.sessionForConnection(target.connectionID) else { return }
                Task {
                    switch target.databaseType {
                    case .postgresql:
                        await dropPostgresDatabase(
                            session: session,
                            name: target.databaseName,
                            cascade: target.variant == .cascade,
                            force: target.variant == .force
                        )
                    default:
                        await runMSSQLTask(session: session, database: target.databaseName, task: .drop)
                    }
                }
            }
        } message: {
            if let target = viewModel.dropDatabaseTarget {
                switch target.variant {
                case .cascade:
                    Text("This will drop the database and all dependent objects. This action cannot be undone.")
                case .force:
                    Text("This will forcefully terminate all connections and drop the database. This action cannot be undone.")
                case .standard:
                    Text("This will permanently delete the database \"\(target.databaseName)\". This action cannot be undone.")
                }
            }
        }
        .alert(
            "Drop \(viewModel.dropSecurityPrincipalTarget?.kind.rawValue ?? "") \"\(viewModel.dropSecurityPrincipalTarget?.name ?? "")\"?",
            isPresented: $viewModel.showDropSecurityPrincipalAlert
        ) {
            Button("Cancel", role: .cancel) {
                viewModel.dropSecurityPrincipalTarget = nil
            }
            Button("Drop", role: .destructive) {
                guard let target = viewModel.dropSecurityPrincipalTarget else { return }
                viewModel.dropSecurityPrincipalTarget = nil
                guard let session = environmentState.sessionCoordinator.sessionForConnection(target.connectionID) else { return }
                Task {
                    await executeDropSecurityPrincipal(target, session: session)
                }
            }
        } message: {
            if let target = viewModel.dropSecurityPrincipalTarget {
                Text("This will permanently drop the \(target.kind.rawValue.lowercased()) \"\(target.name)\". This action cannot be undone.")
            }
        }
    }

    // MARK: - Sidebar Row Wrapper

    func sidebarListRow<Content: View>(id: AnyHashable? = nil, leading: CGFloat = 0, @ViewBuilder content: () -> Content) -> some View {
        let row = content()
            .padding(.leading, leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusEffectDisabled()

        if let id {
            return AnyView(row.id(id))
        }
        return AnyView(row)
    }

    @ViewBuilder
    private func serverSection(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.expandedServerIDs.contains(connID)
        let isSelected = connID == selectedConnectionID

        let isSearching = sidebarSearchQuery != nil
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            serverHeaderRow(session: session, isExpanded: isExpanded || isSearching, isSelected: isSelected)

            if isExpanded || isSearching {
                serverContent(session: session, proxy: proxy)
                    .padding(.leading, SidebarRowConstants.indentStep)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { viewModel.initializeSessionState(for: session, autoExpandSections: projectStore.globalSettings.sidebarExpandSections(for: session.connection.databaseType)) }
    }

    private func serverHeaderRow(session: ConnectionSession, isExpanded: Bool, isSelected: Bool) -> some View {
        let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : ColorTokens.accent

        return Button {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                if isExpanded {
                    viewModel.expandedServerIDs.remove(session.connection.id)
                } else {
                    viewModel.expandedServerIDs.insert(session.connection.id)
                }
            }
            selectedConnectionID = session.connection.id
            environmentState.sessionCoordinator.setActiveSession(session.id)
        } label: {
            ExplorerSidebarRowChrome(isSelected: false, accentColor: accentColor, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(session.connection.databaseType.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: SidebarRowConstants.iconFrame, height: SidebarRowConstants.iconFrame)

                    Text(serverDisplayName(session))
                        .font(isSelected ? TypographyTokens.standard.weight(.semibold) : TypographyTokens.standard)
                        .foregroundStyle(session.isConnected ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                        .lineLimit(1)

                    if let version = serverVersionLabel(session) {
                        Text(version)
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .padding(.horizontal, SpacingTokens.xxs)
                            .padding(.vertical, SpacingTokens.xxs2)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(ColorTokens.Text.primary.opacity(0.06))
                            )
                            .lineLimit(1)
                    }

                    Spacer(minLength: SpacingTokens.xxxs)
                }
                .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            serverContextMenu(session: session)
        }
    }

    // MARK: - Server Content (Folder Groups)

    @ViewBuilder
    private func serverContent(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        switch session.structureLoadingState {
        case .ready, .loading:
            if let structure = session.databaseStructure, !structure.databases.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    databasesFolderSection(session: session, structure: structure, proxy: proxy)

                    // Security folder — MSSQL and PostgreSQL
                    if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                        securityFolderSection(session: session)
                    }

                    if session.connection.databaseType == .microsoftSQL {
                        agentJobsSection(session: session)
                    }
                }
            } else if session.databaseStructure != nil {
                loadingHint()
            } else {
                loadingHint()
            }
        case .idle:
            loadingHint()
        case .failed(let message):
            failureHint(message: message, session: session)
        }
    }

    // MARK: - Databases Folder

    @ViewBuilder
    private func databasesFolderSection(session: ConnectionSession, structure: DatabaseStructure, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.databasesFolderExpandedBySession[connID] ?? true
        let isSearching = sidebarSearchQuery != nil

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            folderHeaderRow(
                title: "Databases",
                icon: "cylinder",
                count: structure.databases.count,
                isExpanded: isExpanded || isSearching
            ) {
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    viewModel.databasesFolderExpandedBySession[connID] = !isExpanded
                }
            }

            if isExpanded || isSearching {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    ForEach(structure.databases, id: \.name) { database in
                        if databaseMatchesSearch(database, session: session) {
                            databaseSection(database: database, session: session, proxy: proxy)
                        }
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Folder Header Row

    func folderHeaderRow(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ExplorerSidebarRowChrome(isSelected: false, accentColor: ColorTokens.accent, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: icon)
                        .font(SidebarRowConstants.iconFont)
                        .foregroundStyle(ExplorerSidebarPalette.folderIconColor(title: title, colored: projectStore.globalSettings.sidebarColoredIcons))
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text(title)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    Spacer(minLength: SpacingTokens.xxxs)

                    if let count {
                        Text("\(count)")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
                .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }

    // MARK: - Per-Database Section

    @ViewBuilder
    private func databaseSection(database: DatabaseInfo, session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name)
        let isSelected = database.name == session.selectedDatabaseName
        let hasSchemas = !database.schemas.isEmpty && database.schemas.contains(where: { !$0.objects.isEmpty })

        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            databaseHeaderRow(
                database: database,
                session: session,
                isExpanded: isExpanded,
                isSelected: isSelected
            )

            if isExpanded {
                databaseContent(database: database, session: session, hasSchemas: hasSchemas, proxy: proxy)
                    .padding(.leading, SidebarRowConstants.indentStep)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func databaseHeaderRow(database: DatabaseInfo, session: ConnectionSession, isExpanded: Bool, isSelected: Bool) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.isDatabaseLoading(connectionID: connID, databaseName: database.name)
        let accentColor = projectStore.globalSettings.accentColorSource == .connection ? session.connection.color : ColorTokens.accent

        return Button {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                viewModel.toggleDatabaseExpanded(connectionID: connID, databaseName: database.name)
            }
            // Update the session's selected database when expanding
            if viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name) {
                session.selectedDatabaseName = database.name
            }
        } label: {
            ExplorerSidebarRowChrome(isSelected: isSelected, accentColor: accentColor, style: .plain) {
                HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(SidebarRowConstants.chevronFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SidebarRowConstants.chevronWidth)

                    Image(systemName: isSelected ? "internaldrive.fill" : "internaldrive")
                        .font(SidebarRowConstants.iconFont)
                        .foregroundStyle(database.isOnline ? (isSelected ? accentColor : ExplorerSidebarPalette.database) : Color(nsColor: .quaternaryLabelColor))
                        .frame(width: SidebarRowConstants.iconFrame)

                    Text(database.name)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(database.isOnline ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                        .lineLimit(1)

                    Spacer(minLength: SpacingTokens.xxxs)

                    if !database.isOnline, let state = database.stateDescription {
                        Text(state.uppercased())
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.quaternary)
                            .lineLimit(1)
                    }

                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .opacity(database.isOnline ? 1 : 0.5)
                .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
                .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .contextMenu {
            databaseContextMenu(database: database, session: session)
        }
    }

    @ViewBuilder
    private func databaseContent(database: DatabaseInfo, session: ConnectionSession, hasSchemas: Bool, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.isDatabaseLoading(connectionID: connID, databaseName: database.name)
        let alreadyLoaded = viewModel.isDatabaseSchemaLoadedOnce(connectionID: connID, databaseName: database.name)
        let needsLoad = !hasSchemas && !isLoading && !alreadyLoaded

        Group {
            if hasSchemas {
                VStack(spacing: SpacingTokens.xxxs) {
                    Color.clear.frame(height: 0)
                        .id("\(connID)-\(database.name)-objects-top")

                    DatabaseObjectBrowserView(
                        database: database,
                        connection: session.connection,
                        searchText: $viewModel.debouncedSearchText,
                        selectedSchemaName: viewModel.selectedSchemaNameBinding(for: connID, database: database.name),
                        expandedObjectGroups: viewModel.expandedObjectGroupsBinding(for: connID, database: database.name),
                        expandedObjectIDs: viewModel.expandedObjectIDsBinding(for: connID, database: database.name),
                        pinnedObjectIDs: viewModel.pinnedObjectsBinding(for: database, connectionID: connID),
                        isPinnedSectionExpanded: viewModel.pinnedSectionExpandedBinding(for: database, connectionID: connID),
                        scrollTo: { id, anchor in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: anchor)
                            }
                        },
                        onNewExtension: {
                            environmentState.openExtensionsManagerTab(connectionID: connID, databaseName: database.name)
                        }
                    )
                    .environmentObject(environmentState)
                    .environmentObject(viewModel)
                    .padding(.horizontal, SpacingTokens.xxs)

                    // Database-level Security
                    if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                        databaseSecuritySection(database: database, session: session)
                            .environmentObject(viewModel)
                            .padding(.horizontal, SpacingTokens.xxs)
                    }
                }
            } else if alreadyLoaded {
                // Schema was fetched but the database has no user objects — don't re-fetch
                Text("No objects")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.xxs)
            } else {
                HStack(spacing: SpacingTokens.xxs2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xxs)
            }
        }
        .onAppear {
            guard needsLoad else { return }
            // Use an unstructured Task so SwiftUI view re-renders (caused by
            // setDatabaseLoading) cannot cancel the in-flight connection.
            Task { @MainActor in
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        }
    }

    // MARK: - Compact Inline States

    private func loadingHint() -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ProgressView()
                .controlSize(.small)
            Text("Loading…")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    private func failureHint(message: String?, session: ConnectionSession) -> some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(TypographyTokens.label)
                .foregroundStyle(ColorTokens.Status.warning)
            Text(message ?? "Failed to load")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(2)
            Button("Retry") {
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            }
            .buttonStyle(.plain)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.accent)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Global Search Filtering

    /// Normalized sidebar search query, nil when empty.
    var sidebarSearchQuery: String? {
        let trimmed = viewModel.debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    /// Returns true if a server or any of its children match the search.
    func serverMatchesSearch(_ session: ConnectionSession) -> Bool {
        guard let query = sidebarSearchQuery else { return true }
        // Server name match
        if serverDisplayName(session).lowercased().contains(query) { return true }
        // Check databases
        if let structure = session.databaseStructure {
            for db in structure.databases {
                if db.name.lowercased().contains(query) { return true }
                // Check objects in schemas
                for schema in db.schemas {
                    for obj in schema.objects {
                        if obj.name.lowercased().contains(query) || obj.fullName.lowercased().contains(query) { return true }
                    }
                }
            }
        }
        // Check security items
        let connID = session.connection.id
        if let logins = viewModel.securityLoginsBySession[connID] {
            if logins.contains(where: { $0.name.lowercased().contains(query) }) { return true }
        }
        return false
    }

    /// Returns true if a database or its objects match the search.
    func databaseMatchesSearch(_ database: DatabaseInfo, session: ConnectionSession) -> Bool {
        guard let query = sidebarSearchQuery else { return true }
        if database.name.lowercased().contains(query) { return true }
        for schema in database.schemas {
            for obj in schema.objects {
                if obj.name.lowercased().contains(query) || obj.fullName.lowercased().contains(query) { return true }
                if obj.columns.contains(where: { $0.name.lowercased().contains(query) }) { return true }
            }
        }
        return false
    }

    // MARK: - Helpers

    private func serverDisplayName(_ session: ConnectionSession) -> String {
        let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? session.connection.host : name
    }

    /// Extract a short version label from the stored server version string.
    /// e.g. "SQL Server 16.0.1000.5" → "16.0.1000.5", "PostgreSQL 16.2" → "16.2"
    private func serverVersionLabel(_ session: ConnectionSession) -> String? {
        let raw = session.databaseStructure?.serverVersion
            ?? session.connection.serverVersion
        guard let raw, !raw.isEmpty else { return nil }

        // Strip the engine name prefix to show just the version number
        let prefixes = ["SQL Server ", "PostgreSQL ", "Microsoft SQL Server "]
        for prefix in prefixes {
            if raw.hasPrefix(prefix) {
                let version = String(raw.dropFirst(prefix.count))
                return version.isEmpty ? nil : version
            }
        }
        // If no known prefix, return as-is (but skip if it's just a type name)
        if raw == "PostgreSQL" || raw == "Microsoft SQL Server" || raw == "SQL Server" {
            return nil
        }
        return raw
    }

    private func connectToSavedConnection(_ connection: SavedConnection) async {
        await environmentState.connect(to: connection)
        await MainActor.run {
            viewModel.expandedServerIDs.insert(connection.id)
            selectedConnectionID = connection.id
        }
    }

    // MARK: - Object Group Context Menu

    @ViewBuilder
    private func objectGroupContextMenu(type: SchemaObjectInfo.ObjectType, database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let creationTitle = objectGroupCreationTitle(for: type)
        if let title = creationTitle {
            let item = creationOptions(for: session.connection.databaseType).first { $0.title == title }
            if let item {
                Button {
                    handleCreationAction(item, session: session, database: database)
                } label: {
                    Label(title, systemImage: "plus")
                }
            } else {
                Button {} label: {
                    Label(title, systemImage: "plus")
                }
                .disabled(true)
            }
            Divider()
        }

        Button {
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    private func objectGroupCreationTitle(for type: SchemaObjectInfo.ObjectType) -> String? {
        switch type {
        case .table: "New Table"
        case .view: "New View"
        case .materializedView: "New Materialized View"
        case .function: "New Function"
        case .procedure: "New Procedure"
        case .trigger: "New Trigger"
        case .extension: "New Extension"
        }
    }

    // MARK: - Databases Folder Context Menu

    @ViewBuilder
    private func databasesFolderContextMenu(session: ConnectionSession) -> some View {
        Button {
            let sql: String
            switch session.connection.databaseType {
            case .postgresql:
                sql = """
                CREATE DATABASE new_database
                    OWNER = current_user
                    ENCODING = 'UTF8'
                    LC_COLLATE = 'en_US.UTF-8'
                    LC_CTYPE = 'en_US.UTF-8'
                    TEMPLATE = template0;
                """
            case .microsoftSQL:
                sql = """
                CREATE DATABASE [NewDatabase]
                GO
                """
            default:
                sql = "CREATE DATABASE new_database;"
            }
            environmentState.openQueryTab(for: session, presetQuery: sql)
        } label: {
            Label("New Database\u{2026}", systemImage: "plus")
        }

        Divider()

        Button {
            Task {
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    // MARK: - Server Context Menu

    @ViewBuilder
    private func serverContextMenu(session: ConnectionSession) -> some View {
        Button {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        } label: {
            Label("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent")
        }

        Divider()

        Button {
            environmentState.openQueryTab(for: session)
        } label: {
            Label("New Query", systemImage: "doc.badge.plus")
        }

        Divider()

        Button {
            Task {
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            }
        } label: {
            Label("Refresh All", systemImage: "arrow.clockwise")
        }

        Button {
            Task {
                await environmentState.disconnectSession(withID: session.id)
            }
        } label: {
            Label("Disconnect", systemImage: "xmark.circle")
        }
    }

    // MARK: - Database Context Menu

    @ViewBuilder
    private func databaseContextMenu(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id

        Button {
            viewModel.ensureDatabaseExpanded(connectionID: connID, databaseName: database.name)
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh Schema", systemImage: "arrow.clockwise")
        }

        Divider()

        // New Query in this database
        Button {
            environmentState.openQueryTab(for: session)
        } label: {
            Label("New Query", systemImage: "doc.badge.plus")
        }

        if session.connection.databaseType == .postgresql {
            if projectStore.globalSettings.managedPostgresConsoleEnabled {
                Button {
                    environmentState.openPSQLTab(for: session, database: database.name)
                } label: {
                    Label("Postgres Console", systemImage: "terminal")
                }
            }
            if projectStore.globalSettings.nativePsqlEnabled {
                Button {
                } label: {
                    Label("Native psql (Coming Soon)", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(true)
            }
        }

        Divider()

        // PostgreSQL-specific operations
        if session.connection.databaseType == .postgresql {
            Menu {
                Button("VACUUM") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .vacuum) }
                }
                Button("VACUUM (Full)") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .vacuumFull) }
                }
                Button("VACUUM (Analyze)") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .vacuumAnalyze) }
                }
                Button("ANALYZE") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .analyze) }
                }
                Button("REINDEX") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .reindex) }
                }
            } label: {
                Label("Maintenance", systemImage: "wrench.and.screwdriver")
            }

            Divider()
        }

        // MSSQL-specific operations
        if session.connection.databaseType == .microsoftSQL {
            Menu {
                if database.isOnline {
                    Button("Shrink Database") {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .shrink) }
                    }

                    Divider()

                    Button("Take Offline") {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .takeOffline) }
                    }
                } else {
                    Button("Bring Online") {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .bringOnline) }
                    }
                }
            } label: {
                Label("Tasks", systemImage: "gearshape")
            }

            Divider()
        }

        // Drop / Delete
        if session.connection.databaseType == .postgresql {
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .standard)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database", systemImage: "trash")
            }
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .cascade)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database (Cascade)", systemImage: "trash")
            }
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .force)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database (Force)", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: session.connection.databaseType, variant: .standard)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database", systemImage: "trash")
            }
        }

        Divider()

        Button {
            viewModel.propertiesDatabaseName = database.name
            viewModel.propertiesConnectionID = connID
            viewModel.showDatabaseProperties = true
        } label: {
            Label("Properties\u{2026}", systemImage: "info.circle")
        }
    }

    // MARK: - PostgreSQL Maintenance

    private enum PostgresMaintenanceOp {
        case vacuum, vacuumFull, vacuumAnalyze, analyze, reindex
    }

    private func runPostgresMaintenance(session: ConnectionSession, database: String, operation: PostgresMaintenanceOp) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        let admin = pgSession.client.admin
        do {
            switch operation {
            case .vacuum:
                _ = try await admin.vacuum()
            case .vacuumFull:
                _ = try await admin.vacuum(full: true)
            case .vacuumAnalyze:
                _ = try await admin.vacuum(analyze: true)
            case .analyze:
                _ = try await admin.analyze()
            case .reindex:
                _ = try await admin.reindex(database: database)
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .maintenanceFailed, message: "Maintenance failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - PostgreSQL Drop

    private func dropPostgresDatabase(session: ConnectionSession, name: String, cascade: Bool, force: Bool) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        do {
            _ = try await pgSession.client.admin.dropDatabase(name: name, ifExists: true, withForce: force)
            Task { @MainActor in
                await environmentState.refreshDatabaseStructure(for: session.id)
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .generalError, message: "Drop failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - MSSQL Tasks

    private enum MSSQLDatabaseTask {
        case shrink, takeOffline, bringOnline, drop
    }

    private func runMSSQLTask(session: ConnectionSession, database: String, task: MSSQLDatabaseTask) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin

        do {
            let messages: [SQLServerStreamMessage]
            switch task {
            case .shrink:
                messages = try await admin.shrinkDatabase(name: database)
            case .takeOffline:
                messages = try await admin.takeDatabaseOffline(name: database)
            case .bringOnline:
                messages = try await admin.bringDatabaseOnline(name: database)
            case .drop:
                messages = try await admin.dropDatabase(name: database)
            }

            // Show server info messages as toast
            let infoMessages = messages.filter { $0.kind == .info }
            let toastMessage = infoMessages.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                if !toastMessage.isEmpty {
                    environmentState.notificationEngine?.post(category: .maintenanceCompleted, message: toastMessage)
                }
                // Refresh structure to update database states in the sidebar
                Task {
                    await environmentState.refreshDatabaseStructure(for: session.id)
                }
            }
        } catch {
            await MainActor.run {
                environmentState.notificationEngine?.post(category: .maintenanceFailed, message: "Task failed: \(error.localizedDescription)")
            }
        }
    }
}
