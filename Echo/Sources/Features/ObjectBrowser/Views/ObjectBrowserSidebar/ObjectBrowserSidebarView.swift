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
    }

    // MARK: - Per-Server Section

    @ViewBuilder
    private func serverSection(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.expandedServerIDs.contains(connID)
        let isSelected = connID == selectedConnectionID

        VStack(alignment: .leading, spacing: 0) {
            serverHeaderRow(session: session, isExpanded: isExpanded, isSelected: isSelected)

            if isExpanded {
                serverContent(session: session, proxy: proxy)
                    .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
        .task { viewModel.initializeSessionState(for: session, autoExpandSections: projectStore.globalSettings.sidebarExpandSections(for: session.connection.databaseType)) }
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
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SidebarRowConstants.chevronFont)
                    .foregroundStyle(.tertiary)
                    .frame(width: SidebarRowConstants.chevronWidth)

                Image(session.connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: SidebarRowConstants.iconFrame, height: SidebarRowConstants.iconFrame)

                Text(serverDisplayName(session))
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let version = serverVersionLabel(session) {
                    Text("(\(version))")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Circle()
                    .fill(session.isConnected ? ColorTokens.Status.success : ColorTokens.Status.error)
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Disconnect") {
                Task { await environmentState.disconnectSession(withID: session.id) }
            }
        }
    }

    // MARK: - Server Content (Folder Groups)

    @ViewBuilder
    private func serverContent(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        switch session.structureLoadingState {
        case .ready, .loading:
            if let structure = session.databaseStructure, !structure.databases.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    databasesFolderSection(session: session, structure: structure, proxy: proxy)

                    if session.connection.databaseType == .microsoftSQL {
                        managementFolderSection(session: session)
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

        VStack(alignment: .leading, spacing: 0) {
            folderHeaderRow(
                title: "Databases",
                icon: "square.stack.3d.up",
                count: structure.databases.count,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.databasesFolderExpandedBySession[connID] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(structure.databases, id: \.name) { database in
                        databaseSection(database: database, session: session, proxy: proxy)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    // MARK: - Management Folder (MSSQL)

    @ViewBuilder
    private func managementFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.managementFolderExpandedBySession[connID] ?? false

        VStack(alignment: .leading, spacing: 0) {
            folderHeaderRow(
                title: "Management",
                icon: "wrench.and.screwdriver",
                count: nil,
                isExpanded: isExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.managementFolderExpandedBySession[connID] = !isExpanded
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    agentJobsSection(session: session)
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    // MARK: - Folder Header Row

    private func folderHeaderRow(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SidebarRowConstants.chevronFont)
                    .foregroundStyle(.tertiary)
                    .frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Per-Database Section

    @ViewBuilder
    private func databaseSection(database: DatabaseInfo, session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name)
        let isSelected = database.name == session.selectedDatabaseName
        let hasSchemas = !database.schemas.isEmpty && database.schemas.contains(where: { !$0.objects.isEmpty })

        VStack(alignment: .leading, spacing: 0) {
            databaseHeaderRow(
                database: database,
                session: session,
                isExpanded: isExpanded,
                isSelected: isSelected
            )

            if isExpanded {
                databaseContent(database: database, session: session, hasSchemas: hasSchemas, proxy: proxy)
                    .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
    }

    private func databaseHeaderRow(database: DatabaseInfo, session: ConnectionSession, isExpanded: Bool, isSelected: Bool) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.isDatabaseLoading(connectionID: connID, databaseName: database.name)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleDatabaseExpanded(connectionID: connID, databaseName: database.name)
            }
            // After toggle, check if now expanded — if so, trigger loading if no schemas
            let nowExpanded = viewModel.isDatabaseExpanded(connectionID: connID, databaseName: database.name)
            if nowExpanded {
                let hasContent = database.schemas.contains(where: { !$0.objects.isEmpty })
                if !hasContent && !isLoading {
                    viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
                    Task {
                        await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                        viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SidebarRowConstants.chevronFont)
                    .foregroundStyle(.tertiary)
                    .frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: isSelected ? "cylinder.fill" : "cylinder")
                    .font(.system(size: 12))
                    .foregroundStyle(database.isOnline ? (isSelected ? Color.orange : Color.secondary) : Color.secondary.opacity(0.5))
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(database.name)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(database.isOnline ? Color.primary : Color.secondary.opacity(0.5))
                    .lineLimit(1)

                if !database.isOnline, let state = database.stateDescription {
                    Text("(\(state))")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            databaseContextMenu(database: database, session: session)
        }
    }

    @ViewBuilder
    private func databaseContent(database: DatabaseInfo, session: ConnectionSession, hasSchemas: Bool, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isLoading = viewModel.isDatabaseLoading(connectionID: connID, databaseName: database.name)

        if hasSchemas {
            VStack(spacing: 2) {
                Color.clear.frame(height: 0)
                    .id("\(connID)-\(database.name)-objects-top")

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
        } else if isLoading {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading…")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs)
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading objects\u{2026}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs)
            .task {
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        }
    }

    // MARK: - Compact Inline States

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

    // MARK: - Database Context Menu

    @ViewBuilder
    private func databaseContextMenu(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id

        Button("Refresh Schema") {
            viewModel.ensureDatabaseExpanded(connectionID: connID, databaseName: database.name)
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        }

        Divider()

        // New Query in this database
        Button("New Query") {
            environmentState.openQueryTab(for: session)
        }

        Divider()

        // PostgreSQL-specific operations
        if session.connection.databaseType == .postgresql {
            Menu("Maintenance") {
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
            }

            Divider()
        }

        // MSSQL-specific operations
        if session.connection.databaseType == .microsoftSQL {
            Menu("Tasks") {
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
            }

            Divider()
        }

        // Drop / Delete
        if session.connection.databaseType == .postgresql {
            Button("Drop Database", role: .destructive) {
                Task { await dropPostgresDatabase(session: session, name: database.name, cascade: false, force: false) }
            }
            Button("Drop Database (Cascade)", role: .destructive) {
                Task { await dropPostgresDatabase(session: session, name: database.name, cascade: true, force: false) }
            }
            Button("Drop Database (Force)", role: .destructive) {
                Task { await dropPostgresDatabase(session: session, name: database.name, cascade: false, force: true) }
            }
        } else {
            Button("Drop Database", role: .destructive) {
                Task { await runMSSQLTask(session: session, database: database.name, task: .drop) }
            }
        }

        Divider()

        Button("Properties\u{2026}") {
            viewModel.propertiesDatabaseName = database.name
            viewModel.propertiesConnectionID = connID
            viewModel.showDatabaseProperties = true
        }
    }

    // MARK: - PostgreSQL Maintenance

    private enum PostgresMaintenanceOp {
        case vacuum, vacuumFull, vacuumAnalyze, analyze, reindex
    }

    private func runPostgresMaintenance(session: ConnectionSession, database: String, operation: PostgresMaintenanceOp) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        let admin = PostgresAdmin(client: pgSession.client, logger: pgSession.logger)
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
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Maintenance failed: \(error.localizedDescription)", style: .error)
            }
        }
    }

    // MARK: - PostgreSQL Drop

    private func dropPostgresDatabase(session: ConnectionSession, name: String, cascade: Bool, force: Bool) async {
        guard let pgSession = session.session as? PostgresSession else { return }

        do {
            _ = try await pgSession.client.dropDatabase(name: name, ifExists: true, withForce: force)
            Task { @MainActor in
                await environmentState.refreshDatabaseStructure(for: session.id)
            }
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Drop failed: \(error.localizedDescription)", style: .error)
            }
        }
    }

    // MARK: - MSSQL Tasks

    private enum MSSQLDatabaseTask {
        case shrink, takeOffline, bringOnline, drop
    }

    private func runMSSQLTask(session: ConnectionSession, database: String, task: MSSQLDatabaseTask) async {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.makeAdministrationClient()

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
                    environmentState.toastCoordinator.show(icon: "checkmark.circle", message: toastMessage, style: .success)
                }
                // Refresh structure to update database states in the sidebar
                Task {
                    await environmentState.refreshDatabaseStructure(for: session.id)
                }
            }
        } catch {
            await MainActor.run {
                environmentState.toastCoordinator.show(icon: "exclamationmark.triangle", message: "Task failed: \(error.localizedDescription)", style: .error)
            }
        }
    }
}
