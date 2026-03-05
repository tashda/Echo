import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Thin shell that owns the `.toolbar` declaration. This view has NO
/// `@EnvironmentObject` subscriptions, so its body never re-evaluates
/// when ObservableObject publishers fire (e.g. AppState changes).
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

    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @EnvironmentObject private var clipboardHistory: ClipboardHistoryStore

    var body: some View {
        let tabBarStyle = appState.workspaceTabBarStyle

        NavigationSplitView(columnVisibility: $appState.workspaceSidebarVisibility) {
            SidebarColumn()
                .accessibilityIdentifier("workspace-sidebar")
                .navigationSplitViewColumnWidth(
                    min: WorkspaceLayoutMetrics.sidebarMinWidth,
                    ideal: WorkspaceLayoutMetrics.sidebarIdealWidth
                )
        } detail: {
            WorkspaceMainContent()
                .accessibilityIdentifier("workspace-content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Background.primary)
                .inspector(isPresented: $appState.showInfoSidebar) {
                    inspectorContent
                }
        }
        .navigationSplitViewStyle(.balanced)
        .background(WorkspaceWindowConfigurator(tabBarStyle: tabBarStyle))
        .sheet(isPresented: Binding(get: { appState.activeSheet == .connectionEditor }, set: { if !$0 { appState.dismissSheet() } })) {
            connectionEditorSheet
        }
        .sheet(isPresented: Binding(get: { navigationStore.showManageProjectsSheet }, set: { navigationStore.showManageProjectsSheet = $0 })) {
            ManageProjectsSheet()
                .environment(projectStore)
                .environmentObject(environmentState)
                .environmentObject(clipboardHistory)
                .environmentObject(appearanceStore)
        }
        .sheet(isPresented: Binding(get: { navigationStore.showNewProjectSheet }, set: { navigationStore.showNewProjectSheet = $0 })) {
            NewProjectSheet()
                .environment(projectStore)
                .environmentObject(environmentState)
        }
        .task {
            if !AppCoordinator.shared.isInitialized { await AppCoordinator.shared.initialize() }
        }
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
    }

    @ViewBuilder
    private var inspectorContent: some View {
        let widthBinding = Binding<CGFloat>(
            get: { navigationStore.inspectorWidth },
            set: { newValue in
                navigationStore.updateInspectorWidth(
                    newValue,
                    min: WorkspaceLayoutMetrics.inspectorMinWidth,
                    max: WorkspaceLayoutMetrics.inspectorMaxWidth
                )
            }
        )

        InfoSidebarView()
            .environmentObject(environmentState)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, appState.workspaceTabBarStyle.chromeTopPadding)
            .padding(.bottom, SpacingTokens.sm)
            .padding(.horizontal, 18)
#if os(macOS)
            .background(
                InspectorSplitViewConfigurator(
                    width: widthBinding,
                    minWidth: WorkspaceLayoutMetrics.inspectorMinWidth,
                    maxWidth: WorkspaceLayoutMetrics.inspectorMaxWidth
                )
            )
#endif
    }

    private var connectionEditorSheet: some View {
        ConnectionEditorView(
            connection: connectionStore.selectedConnection,
            onSave: { connection, password, action in
                Task {
                    await environmentState.upsertConnection(connection, password: password)
                    if action == .saveAndConnect { await environmentState.connect(to: connection) }
                    await MainActor.run { appState.dismissSheet() }
                }
            }
        )
        .environmentObject(environmentState)
        .environmentObject(appState)
    }
}
