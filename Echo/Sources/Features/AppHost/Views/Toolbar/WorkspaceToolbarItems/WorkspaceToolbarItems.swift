import SwiftUI

struct WorkspaceToolbarItems: ToolbarContent {
    @Environment(TabStore.self) private var tabStore

    var body: some ToolbarContent {
        navigationItems
        centerItems
        contextActionItems
        workspaceActionItems
    }

    // MARK: - Left Side (Navigation)

    @ToolbarContentBuilder
    private var navigationItems: some ToolbarContent {
        // Its own glass, apart from the connection group, like the sidebar button in Finder.
        ToolbarItem(id: "workspace.navigation.sidebar", placement: .navigation) {
            SidebarToggleToolbarButton()
                .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .navigation) {
            ProjectContextMenuButton()
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .navigation) {
            // Saved connections open from the + in the rail's server pill.
            RecentConnectionsMenuButton()
            Button {
                AppDirector.shared.appState.showSheet(.quickConnect)
            } label: {
                Label("Quick Connect", systemImage: "bolt.fill")
            }
            .labelStyle(.iconOnly)
            .help("Quick Connect")
        }
    }

    // MARK: - Center (Breadcrumb spacer)

    @ToolbarContentBuilder
    private var centerItems: some ToolbarContent {
        ToolbarItem(id: "workspace.principal.spacer", placement: .principal) {
            Color.clear
                .frame(width: SpacingTokens.none, height: SpacingTokens.none)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Right Side (plan K2)

    /// [tab tools] [Run] [Format · Validate · Help · Plan] [MSSQL toggles], each one system glass
    /// capsule, hidden when the active tab has no use for it.
    @ToolbarContentBuilder
    private var contextActionItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            TableStructureToolbarItem()
            ActivityMonitorToolbarItem()
            JobQueuePlayToolbarItem()
            JobQueuePopOutToolbarItem()
            ErrorLogCycleToolbarItem()
            TabContextToolbarButton()
        }
        .hidden(!toolbarContext.hasTabTools)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.queryrun", placement: .primaryAction) {
            QueryRunToolbarItem()
        }
        .hidden(!toolbarContext.isQuery)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.queryenhance", placement: .primaryAction) {
            QueryEditorEnhanceToolbarControls()
        }
        .hidden(!toolbarContext.isQuery)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.querydb", placement: .primaryAction) {
            QueryEditorDatabaseToolbarControls()
        }
        .hidden(!toolbarContext.hasDatabaseToggles)

        ToolbarSpacer(.fixed, placement: .primaryAction)
    }

    // MARK: - Right Side: Workspace Actions

    /// [Search · Overview · Refresh · Bell · Inspector] share one capsule; Inspector stays last.
    @ToolbarContentBuilder
    private var workspaceActionItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            SearchToolbarButton()
            TabOverviewToolbarButton()
            RefreshToolbarButton()
            NotificationBellToolbarButton()
            InspectorToolbarButton()
        }
    }

    /// Reads only the active tab's kind and database type, so the toolbar content re-evaluates on a
    /// tab change and not while a tab's own state changes.
    private var toolbarContext: WorkspaceToolbarContext {
        let tab = tabStore.activeTab
        return WorkspaceToolbarContext(kind: tab?.kind, databaseType: tab?.connection.databaseType)
    }
}
