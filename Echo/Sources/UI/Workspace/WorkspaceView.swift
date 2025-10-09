import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore
    @Environment(\.useNativeTabBar) private var useNativeTabBar

    @State private var showingConnectionEditor = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var selectedConnection: SavedConnection? { appModel.selectedConnection }
    private var selectedSession: ConnectionSession? {
        guard let connection = selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }
    private var isSidebarCollapsed: Bool { columnVisibility == .detailOnly }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 560)
        } detail: {
            ZStack {
                mainContent

                if appState.showInfoSidebar {
                    HStack {
                        Spacer()
                        InfoSidebarView()
                            .environmentObject(appModel)
                            .frame(width: 300)
                            .ignoresSafeArea()
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
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
        .sheet(isPresented: $appModel.isManageConnectionsPresented) {
            ManageConnectionsView()
                .environmentObject(appModel)
                .environmentObject(appState)
        }
        .sheet(isPresented: $appModel.showManageProjectsSheet) {
            ManageProjectsSheet()
                .environmentObject(appModel)
                .environmentObject(clipboardHistory)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $appModel.showNewProjectSheet) {
            NewProjectSheet()
                .environmentObject(appModel)
        }
        .task {
            if !AppCoordinator.shared.isInitialized {
                await appModel.load()
            }
        }
        .onChange(of: appModel.selectedConnectionID) { _, newValue in
            if newValue == nil {
                appState.showInfoSidebar = false
            }
        }
        .onChange(of: appState.activeSheet) { _, newSheet in
            showingConnectionEditor = (newSheet == .connectionEditor)
        }
    }
}

private extension WorkspaceView {
    var sidebar: some View {
        SidebarView(
            selectedConnectionID: $appModel.selectedConnectionID,
            selectedIdentityID: $appModel.selectedIdentityID,
            onAddConnection: {
                showingConnectionEditor = true
            }
        )
        .environmentObject(appModel)
        .environmentObject(appState)
        .ignoresSafeArea()
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            if !useNativeTabBar && showsTabStrip {
                QueryTabStrip(
                    leadingPadding: 0,
                    trailingPadding: appState.showInfoSidebar ? 300 : 0,
                    createNewTab: createNewTab,
                    toggleOverview: { appState.showTabOverview.toggle() }
                )
                .frame(height: 44)
                .padding(.top, 6)
            }

            queryContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var queryContent: some View {
        Group {
            if let connection = selectedConnection, let session = selectedSession {
                if appModel.tabManager.activeTab != nil {
                    QueryTabsView(
                        showsTabStrip: false // We show tabs in mainContent now
                    )
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func createNewTab() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
        appModel.openQueryTab(for: activeSession)
    }

    private var showsTabStrip: Bool {
        !useNativeTabBar && !appModel.tabManager.tabs.isEmpty
    }
}


private struct ActiveConnectionView: View {
    let connection: SavedConnection
    let session: ConnectionSession
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Connected to \(connection.connectionName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(session.selectedDatabaseName.map { "Database: \($0)" } ?? "No database selected")
                .foregroundStyle(.secondary)

            Button("Disconnect") {
                Task { await appModel.disconnectSession(withID: session.id) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DisconnectedConnectionView: View {
    let connection: SavedConnection
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Not Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to \(connection.connectionName) to start working.")
                .foregroundStyle(.secondary)

            Button("Connect") {
                Task { await appModel.connect(to: connection) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoConnectionSelectedView: View {
    let onAddConnection: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("No Connection Selected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Open or add a connection to get started.")
                .foregroundStyle(.secondary)

            Button("Add Connection", action: onAddConnection)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
