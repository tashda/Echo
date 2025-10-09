import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingConnectionEditor = false

    @ViewBuilder
    var body: some View {
        navigationLayout
            .preferredColorScheme(themeManager.effectiveColorScheme)
            .background(themeManager.windowBackground)
    }

    @ViewBuilder
    private var navigationLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarColumnView(showingConnectionEditor: $showingConnectionEditor)
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 420)
                .background(themeManager.surfaceBackgroundColor)
        } content: {
            WorkspaceContentColumn()
                .background(themeManager.surfaceBackgroundColor)
        } detail: {
            InspectorColumnView()
                .frame(minWidth: 260, idealWidth: 300)
                .background(themeManager.surfaceBackgroundColor)
        }
        .modifier(
            WorkspaceSceneModifier(
                showingConnectionEditor: $showingConnectionEditor,
                columnVisibility: $columnVisibility
            )
        )
        .toolbar {
            WorkspaceToolbarItems()
        }
    }
}

private struct SidebarColumnView: View {
    @Binding var showingConnectionEditor: Bool
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        SidebarView(
            selectedConnectionID: Binding(
                get: { appModel.selectedConnectionID },
                set: { appModel.selectedConnectionID = $0 }
            ),
            selectedIdentityID: Binding(
                get: { appModel.selectedIdentityID },
                set: { appModel.selectedIdentityID = $0 }
            ),
            onAddConnection: { showingConnectionEditor = true }
        )
        .background(themeManager.surfaceBackgroundColor)
    }
}

private struct WorkspaceContentColumn: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            headerChips
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Divider()
                .padding(.horizontal, 12)

            QueryTabsView(
                showsTabStrip: true,
                tabBarLeadingPadding: 12,
                tabBarTrailingPadding: appState.showInfoSidebar ? 320 : 12
            )
            .environment(\.useNativeTabBar, false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.surfaceBackgroundColor)
    }

    @ViewBuilder
    private var headerChips: some View {
        HStack(spacing: 8) {
            if let connection = appModel.selectedConnection {
                HelperChip(
                    label: connection.connectionName,
                    systemImage: "externaldrive",
                    tint: themeManager.accentColor
                )
            } else {
                HelperChip(
                    label: "No Connection",
                    systemImage: "externaldrive.slash",
                    tint: .secondary.opacity(0.6)
                )
            }

            if let session = activeSession,
               let database = session.selectedDatabaseName {
                HelperChip(
                    label: database,
                    systemImage: "database",
                    tint: themeManager.accentColor.opacity(0.8)
                )
            }

            Spacer()

            if appState.isConnecting {
                HelperChip(
                    label: "Connecting…",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .orange
                )
            }
        }
    }

    private var activeSession: ConnectionSession? {
        guard let connection = appModel.selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }
}

private struct InspectorColumnView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            if appState.showInfoSidebar {
                InfoSidebarView()
                    .environmentObject(appModel)
            } else {
                ContentUnavailableView {
                    Label("No Inspector", systemImage: "sidebar.right")
                } description: {
                    Text("Select an object to view contextual details.")
                }
            }
        }
        .background(themeManager.surfaceBackgroundColor)
    }
}

private struct HelperChip: View {
    var label: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(label)
                .font(.subheadline)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .foregroundStyle(.white)
        .background(
            Capsule(style: .continuous)
                .fill(tint.gradient)
        )
    }
}

private struct WorkspaceSceneModifier: ViewModifier {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    @Binding var showingConnectionEditor: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility

    func body(content: Content) -> some View {
        content
            .navigationSplitViewStyle(.balanced)
            .preferredColorScheme(themeManager.effectiveColorScheme)
            .sheet(isPresented: $showingConnectionEditor) {
                ConnectionEditorView(
                    connection: appModel.selectedConnection,
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
                    await AppCoordinator.shared.initialize()
                }
            }
            .onChange(of: appState.activeSheet) { _, newSheet in
                showingConnectionEditor = (newSheet == .connectionEditor)
            }
            .onChange(of: columnVisibility) { _, visibility in
                switch visibility {
                case .all:
                    if !appState.showInfoSidebar {
                        appState.showInfoSidebar = true
                    }
                case .doubleColumn, .detailOnly:
                    if appState.showInfoSidebar {
                        appState.showInfoSidebar = false
                    }
                default:
                    break
                }
            }
            .onChange(of: appState.showInfoSidebar) { _, showInspector in
                let targetVisibility: NavigationSplitViewVisibility = showInspector ? .all : .doubleColumn
                if columnVisibility != targetVisibility {
                    columnVisibility = targetVisibility
                }
            }
            .accentColor(themeManager.accentColor)
    }
}
