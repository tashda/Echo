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
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        WorkspaceBody()
            .toolbar(id: "workspace") {
                WorkspaceToolbarItems()
            }
            .searchable(text: universalSearchText, placement: .toolbar, prompt: "Search")
    }

    private var universalSearchText: Binding<String> {
        if let vm = tabStore.activeTab?.errorLogVM {
            return Bindable(vm).searchText
        }
        return .constant("")
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

        NavigationSplitView(columnVisibility: Bindable(appState).workspaceSidebarVisibility) {
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
                .overlay(alignment: .topTrailing) {
                    if let toast = environmentState.toastPresenter.currentToast {
                        StatusToastView(icon: toast.icon, message: toast.message, style: toast.style)
                            .onTapGesture { environmentState.toastPresenter.dismiss() }
                            .padding(.top, 44)
                            .padding(.trailing, SpacingTokens.lg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.25), value: environmentState.toastPresenter.currentToast)
                    }
                }
                .inspector(isPresented: Bindable(appState).showInfoSidebar) {
                    let isJson = environmentState.dataInspectorContent?.isJson == true
                    inspectorContent
                        .inspectorColumnWidth(
                            min: WorkspaceLayoutMetrics.inspectorMinWidth,
                            ideal: isJson
                                ? WorkspaceLayoutMetrics.jsonInspectorWidth
                                : WorkspaceLayoutMetrics.inspectorIdealWidth,
                            max: WorkspaceLayoutMetrics.inspectorMaxWidth
                        )
                }
        }
        .navigationSplitViewStyle(.balanced)
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

    @ViewBuilder
    private var inspectorContent: some View {
        let isJson = environmentState.dataInspectorContent?.isJson == true
        let targetWidth = isJson
            ? WorkspaceLayoutMetrics.jsonInspectorWidth
            : navigationStore.inspectorWidth

        let widthBinding = Binding<CGFloat>(
            get: { navigationStore.inspectorWidth },
            set: { newValue in
                // Only update user-preferred width when NOT showing JSON
                // (so dragging during JSON mode doesn't overwrite the default)
                guard environmentState.dataInspectorContent?.isJson != true else { return }
                navigationStore.updateInspectorWidth(
                    newValue,
                    min: WorkspaceLayoutMetrics.inspectorMinWidth,
                    max: WorkspaceLayoutMetrics.inspectorMaxWidth
                )
            }
        )

        InfoSidebarView()
            .environment(environmentState)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, appState.workspaceTabBarStyle.chromeTopPadding)
            .padding(.bottom, SpacingTokens.sm)
            .padding(.horizontal, 18)
#if os(macOS)
            .background(
                InspectorSplitViewConfigurator(
                    width: widthBinding,
                    targetWidth: targetWidth,
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
                        environmentState.connect(to: connection)
                    }
                }
            }
        )
        .environment(environmentState)
        .environment(appState)
    }
}

