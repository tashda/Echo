import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingConnectionEditor = false

    private var selectedConnection: SavedConnection? { appModel.selectedConnection }
    private var selectedSession: ConnectionSession? {
        guard let connection = selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }

    var body: some View {
        Group {
            if appState.showInfoSidebar {
                // 3-column split: sidebar | content | right info sidebar
                NavigationSplitView {
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
                } content: {
                    detailContent
                        .navigationTitle(selectedConnection?.connectionName ?? "Fuzee")
                        .background(themeManager.windowBackground)
                } detail: {
                    InfoSidebarView()
                        .environmentObject(appModel)
                        .environmentObject(appState)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                // 2-column split: sidebar | content (no right info sidebar)
                NavigationSplitView {
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
                } detail: {
                    detailContent
                        .navigationTitle(selectedConnection?.connectionName ?? "Fuzee")
                        .background(themeManager.windowBackground)
                }
                .navigationSplitViewStyle(.balanced)
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
        .task { await appModel.load() }
        .onChange(of: appModel.selectedConnectionID) { _, _ in
            // Selection changes handled by explicit connect button
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
                    Image(systemName: connection.databaseType.iconName)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 40, weight: .medium))
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
            Button("Open Query Window") {
                appModel.openQueryTab(for: session)
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
                    Image(systemName: connection.databaseType.iconName)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 40, weight: .medium))
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
    let onAddConnection: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Connection Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Create or select a connection from the sidebar to get started.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Add Connection", action: onAddConnection)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
}
