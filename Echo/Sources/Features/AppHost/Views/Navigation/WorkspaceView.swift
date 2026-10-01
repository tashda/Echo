import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Thin shell that owns the `.toolbar` declaration. This view has NO
/// direct `@Environment` subscriptions to frequently-changing state, so its
/// body never re-evaluates when observable state changes (e.g. AppState).
/// This prevents SwiftUI from re-creating ToolbarItem structs, which
/// was causing NSToolbar to re-layout and shift the action button group.
struct WorkspaceView: View {
    var body: some View {
        WorkspaceBody()
            .toolbar {
                WorkspaceToolbarItems()
            }
    }
}

/// Contains all the actual workspace content and state-dependent modifiers.
private struct WorkspaceBody: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(TabStore.self) private var tabStore

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(ClipboardHistoryStore.self) private var clipboardHistory
    
    @Bindable private var sparkleUpdater = SparkleUpdater.shared

    var body: some View {
        let tabBarStyle = appState.workspaceTabBarStyle

        WorkspaceShell()
        .commandPalette()
        .navigationTitle("Echo")
        .background(WorkspaceWindowConfigurator(tabBarStyle: tabBarStyle))
        .sheet(isPresented: Binding(get: { appState.activeSheet == .connectionEditor }, set: { if !$0 { appState.dismissSheet() } })) {
            connectionEditorSheet
        }
        .sheet(isPresented: Binding(get: { appState.activeSheet == .quickConnect }, set: { if !$0 { appState.dismissSheet() } })) {
            quickConnectSheet
        }
        .onChange(of: navigationStore.showManageProjectsSheet) { _, show in
            if show {
                ManageConnectionsWindowController.shared.present(initialSection: .projects)
                navigationStore.showManageProjectsSheet = false
            }
        }
        .sheet(isPresented: Binding(get: { navigationStore.showNewProjectSheet }, set: { navigationStore.showNewProjectSheet = $0 })) {
            NewProjectSheet()
                .environment(projectStore)
                .environment(environmentState)
        }
        .task {
            if !AppDirector.shared.isInitialized { await AppDirector.shared.initialize() }
        }
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
        .alert("Update Error", isPresented: $sparkleUpdater.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = sparkleUpdater.lastError {
                Text(error.localizedDescription)
            } else {
                Text("An unknown error occurred while checking for updates.")
            }
        }
        .alert(
            "Switch to \(environmentState.pendingProjectSwitch?.name ?? "project")?",
            isPresented: Binding(
                get: { environmentState.pendingProjectSwitch != nil },
                set: { if !$0 { environmentState.cancelProjectSwitch() } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                environmentState.cancelProjectSwitch()
            }
            Button("Switch Project") {
                environmentState.confirmProjectSwitch()
            }
        } message: {
            Text("All active connections will be closed.")
        }
        .alert("Unsaved Changes", isPresented: Bindable(tabStore).showPendingChangesAlert) {
            Button("Cancel", role: .cancel) {
                tabStore.cancelCloseTabWithPendingChanges()
            }
            Button("Discard Changes", role: .destructive) {
                tabStore.confirmCloseTabWithPendingChanges()
            }
        } message: {
            Text("This tab has pending structure changes that haven't been applied. Are you sure you want to close it?")
        }
    }

    private var connectionEditorSheet: some View {
        // New Connection; existing connections are edited in Manage Connections (CN5).
        ConnectionEditorView(
            connection: nil,
            onSave: { connection, password, action in
                appState.dismissSheet()
                Task {
                    await environmentState.upsertConnection(connection, password: password)
                    if action == .saveAndConnect { environmentState.connect(to: connection) }
                }
            }
        )
        .environment(environmentState)
        .environment(appState)
    }

    private var quickConnectSheet: some View {
        ConnectionEditorView(
            connection: nil,
            isQuickConnect: true,
            onSave: { connection, password, action in
                appState.dismissSheet()
                Task {
                    if action == .saveAndConnect {
                        await environmentState.upsertConnection(connection, password: password)
                        environmentState.connect(to: connection)
                    } else if action == .connect {
                        // Quick Connect keeps its password in the Keychain too (design board CR6).
                        var quick = connection
                        if let password, !password.isEmpty {
                            try? environmentState.identityRepository.setPassword(password, for: &quick)
                        }
                        environmentState.connect(to: quick)
                    }
                }
            }
        )
        .environment(environmentState)
        .environment(appState)
    }
}

