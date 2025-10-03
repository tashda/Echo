import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @State private var showingConnectionEditor = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var windowWidth: CGFloat = 900

    private var selectedConnection: SavedConnection? { appModel.selectedConnection }
    private var selectedSession: ConnectionSession? {
        guard let connection = selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }

    var body: some View {
        GeometryReader { proxy in
            layout(for: proxy.safeAreaInsets.top)
                .onAppear { windowWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { newWidth in
                    windowWidth = newWidth
                }
        }
        .background(themeManager.windowBackground)
        .sheet(isPresented: $showingConnectionEditor) {
            ConnectionEditorView(
                connection: selectedConnection,
                onSave: { connection, password, action in
                    Task {
                        await appModel.upsertConnection(connection, password: password)
                        if action == .saveAndConnect {
                            await appModel.connect(to: connection)
                        }
                    }
                }
            )
            .environmentObject(appModel)
            .environmentObject(appState)
        }
        .sheet(isPresented: $appModel.showManageConnectionsTab) {
            ManageConnectionsTab()
                .environmentObject(appModel)
                .environmentObject(appState)
        }
        .sheet(isPresented: $appModel.showManageProjectsSheet) {
            ManageProjectsSheet()
                .environmentObject(appModel)
                .environmentObject(clipboardHistory)
        }
        .sheet(isPresented: $appModel.showNewProjectSheet) {
            NewProjectSheet()
                .environmentObject(appModel)
        }
        .task { await appModel.load() }
        .onChange(of: appModel.selectedConnectionID) { _, newValue in
            if newValue == nil {
                appState.showInfoSidebar = false
            }
        }
        .onChange(of: appState.activeSheet) { _, newSheet in
            showingConnectionEditor = (newSheet == .connectionEditor)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let connection = selectedConnection, let session = selectedSession {
            if appModel.tabManager.activeTab != nil {
                TabbedQueryView()
                    .environmentObject(appModel)
                    .environmentObject(appState)
                    .environmentObject(themeManager)
            } else {
                ActiveConnectionView(connection: connection, session: session)
                    .environmentObject(appModel)
                    .environmentObject(appState)
            }
        } else if let connection = selectedConnection {
            DisconnectedConnectionView(connection: connection)
                .environmentObject(appModel)
                .environmentObject(appState)
        } else {
            NoConnectionSelectedView(onAddConnection: {
                showingConnectionEditor = true
            })
        }
    }
}

private extension ContentView {
    func layout(for safeTopInset: CGFloat) -> some View {
        splitView
            .background(themeManager.windowBackground)
    }

    @ViewBuilder
    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        SidebarView(
            selectedConnectionID: $appModel.selectedConnectionID,
            selectedIdentityID: $appModel.selectedIdentityID,
            onAddConnection: {
                showingConnectionEditor = true
            }
        )
        .environmentObject(appModel)
        .environmentObject(appState)
        .navigationTitle("Connections")
        .frame(minWidth: 220)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
    }

    private var detailPane: some View {
        detailContent
            .navigationTitle("")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(themeManager.windowBackground)
            .toolbar { toolbarContent }
            .toolbar(removing: .sidebarToggle)
            .inspector(isPresented: $appState.showInfoSidebar) {
                InfoSidebarView()
                    .environmentObject(appModel)
                    .frame(minWidth: 260, idealWidth: 300)
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TopBarNavigatorToolbar(windowWidth: windowWidth)
                .environmentObject(appModel)
                .environmentObject(appModel.navigationState)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            newTabToolbarButton
            tabOverviewToolbarButton
            infoToolbarButton
        }
    }

    private var newTabToolbarButton: some View {
        Button(action: createNewTab) {
            Label("New Tab", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .disabled(appModel.sessionManager.activeSession == nil)
#if os(macOS)
        .help("New Query Tab")
#endif
    }

    private var tabOverviewToolbarButton: some View {
        Button {
            appState.showTabOverview.toggle()
        } label: {
            Image(systemName: "square.grid.2x2")
                .symbolVariant(appState.showTabOverview ? .fill : .none)
        }
        .disabled(appModel.tabManager.tabs.isEmpty)
#if os(macOS)
        .help("Tab Overview")
#endif
        .tint(appState.showTabOverview ? Color.accentColor : nil)
    }

    private var infoToolbarButton: some View {
        Button {
            appState.showInfoSidebar.toggle()
        } label: {
            Label("Toggle Info Inspector", systemImage: appState.showInfoSidebar ? "info.circle.fill" : "info.circle")
                .labelStyle(.iconOnly)
        }
#if os(macOS)
        .help("Toggle Info Inspector")
#endif
        .tint(appState.showInfoSidebar ? Color.accentColor : nil)
        .disabled(appModel.selectedConnection == nil)
    }

    private func createNewTab() {
        guard let session = appModel.sessionManager.activeSession else { return }
        appModel.openQueryTab(for: session)
    }
}

private struct TopBarNavigatorToolbar: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var navigationState: NavigationState
    let windowWidth: CGFloat

    var body: some View {
        let width = resolvedWidth(for: windowWidth)

        HStack(spacing: 0) {
            Spacer(minLength: 0)
            TopBarNavigator(width: width)
                .environmentObject(appModel)
                .environmentObject(navigationState)
                .frame(width: width, height: 36)
            Spacer(minLength: 0)
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }

    private func resolvedWidth(for windowWidth: CGFloat) -> CGFloat {
        let reservedWidth: CGFloat = 320 // approximate space for trailing controls and margins
        let minWidth: CGFloat = 480
        let maxWidth: CGFloat = 640
        let candidate = windowWidth - reservedWidth
        return min(max(candidate, minWidth), maxWidth)
    }
}

private struct ActiveConnectionView: View {
    let connection: SavedConnection
    let session: ConnectionSession
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(connection.color.opacity(0.18))
                        .frame(width: 84, height: 84)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(connection.color.opacity(0.4), lineWidth: 1)
                        .frame(width: 84, height: 84)
                    Image(connection.databaseType.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(connection.color)
                }
                Text("Connected to \(connection.connectionName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(session.selectedDatabaseName.map { "Database: \($0)" } ?? "No database selected")
                    .foregroundStyle(.secondary)
            }

            if let structure = session.databaseStructure {
                Text("Loaded \(structure.databases.count) database(s)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Loading database structure…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Disconnect") {
                Task { await appModel.disconnectSession(withID: session.id) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu {
            Button {
                appModel.openQueryTab(for: session)
            } label: {
                Label("Open Query Window", systemImage: "square.and.pencil")
            }
            .disabled(!appModel.canOpenQueryTab)
        }
    }
}

private struct DisconnectedConnectionView: View {
    let connection: SavedConnection
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(connection.color.opacity(0.14))
                        .frame(width: 84, height: 84)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(connection.color.opacity(0.3), lineWidth: 1)
                        .frame(width: 84, height: 84)
                    Image(connection.databaseType.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(connection.color)
                }
                Text("Not Connected")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Connect to \(connection.connectionName) to browse schemas and run queries.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Connect") {
                    Task {
                        appState.isConnecting = true
                        await appModel.connect(to: connection)
                        appState.isConnecting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.isConnecting)

                Button("Edit Connection") {
                    appState.showSheet(ActiveSheet.connectionEditor)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if appState.isConnecting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Connecting…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoConnectionSelectedView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @State private var connectingRecordID: String?
    let onAddConnection: () -> Void

    private var recentItems: [RecentConnectionDisplayItem] {
        appModel.recentConnections.prefix(5).compactMap { record in
            guard let connection = appModel.connections.first(where: { $0.id == record.connectionID }) else { return nil }
            return RecentConnectionDisplayItem(record: record, connection: connection)
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            headerSection

            if recentItems.isEmpty {
                emptyStateSection
            } else {
                recentConnectionsSection
            }

            Button("Add Connection", action: onAddConnection)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.isConnecting)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    .frame(width: 88, height: 88)
                Image(systemName: recentItems.isEmpty ? "server.rack" : "clock.arrow.circlepath")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(recentItems.isEmpty ? "No Connection Selected" : "Pick a Recent Connection")
                .font(.title2)
                .fontWeight(.semibold)
            Text(recentItems.isEmpty ? "Create or select a connection from the sidebar to get started." : "Choose one of your recent servers to jump back in instantly.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 10) {
            Text("No recent connections yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Once you connect to a server, it will appear here for quick access.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
    }

    private var recentConnectionsSection: some View {
        let items = recentItems
        return HStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 6)
                    }
                    RecentConnectionRow(
                        item: items[index],
                        isConnecting: connectingRecordID == items[index].id && appState.isConnecting,
                        isEnabled: !appState.isConnecting,
                        onConnect: { connect(to: items[index]) }
                    )
                    .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: 360)
            Spacer(minLength: 0)
        }
    }

    private func connect(to item: RecentConnectionDisplayItem) {
        Task { @MainActor in
            connectingRecordID = item.id
            appState.isConnecting = true
            defer {
                appState.isConnecting = false
                connectingRecordID = nil
            }
            await appModel.connectToRecentConnection(item.record)
        }
    }
}

private struct RecentConnectionDisplayItem: Identifiable {
    let record: RecentConnectionRecord
    let connection: SavedConnection

    var id: String { record.id }

    var displayName: String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        if !connection.host.isEmpty { return connection.host }
        return "Untitled Connection"
    }

    var serverSummary: String {
        let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedHost = host.isEmpty ? "Local" : host
        let username = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty { return resolvedHost }
        return "\(username)@\(resolvedHost)"
    }

    var databaseSummary: String {
        if let databaseName = record.databaseName, !databaseName.isEmpty {
            return databaseName
        }
        let savedDatabase = connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return savedDatabase.isEmpty ? "Default database" : savedDatabase
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var formattedLastConnected: String {
        let formatted = Self.dateFormatter.string(from: record.lastConnectedAt)
        return "Last connected \(formatted)"
    }
}

private struct RecentConnectionRow: View {
    let item: RecentConnectionDisplayItem
    let isConnecting: Bool
    let isEnabled: Bool
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 12)
                    if isConnecting {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                Text("\(item.serverSummary) • \(item.databaseSummary)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.formattedLastConnected)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isConnecting)
    }
}

#Preview {
    let clipboardHistory = ClipboardHistoryStore()
    ContentView()
        .environmentObject(AppModel(clipboardHistory: clipboardHistory))
        .environmentObject(AppState())
        .environmentObject(clipboardHistory)
        .environmentObject(ThemeManager())
}
