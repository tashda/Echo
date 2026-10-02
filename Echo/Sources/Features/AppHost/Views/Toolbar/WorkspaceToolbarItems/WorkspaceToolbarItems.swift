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

    /// The front tab's own buttons (round 37.5), native toolbar items before the window's icons:
    /// the query editor's Run (its own glass, round 24) and its two groups; any other tab's special
    /// button, then each group of its other buttons. The items stay put and only hide, so the
    /// toolbar is not rebuilt as tabs switch; their buttons change in place.
    @ToolbarContentBuilder
    private var contextActionItems: some ToolbarContent {
        // The owner, 2026-10-01: Open in New Window is its own group at the start of the right-hand
        // side, not in the tab's header.
        ToolbarItem(id: "workspace.primary.openinwindow", placement: .primaryAction) {
            OpenInWindowToolbarButton()
        }
        .hidden(!toolbarContext.canOpenInWindow)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.queryrun", placement: .primaryAction) {
            QueryRunToolbarItem()
        }
        .hidden(!toolbarContext.isQuery)
        // Run draws its own glass so it can turn red without swapping buttons (round 24).
        .sharedBackgroundVisibility(.hidden)
        .keptOutOfOverflow()

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

        tabItems
    }

    /// Any other tab's special button, then each group of its other buttons (round 37.5).
    @ToolbarContentBuilder
    private var tabItems: some ToolbarContent {
        ToolbarItem(id: "workspace.primary.tabspecial", placement: .primaryAction) {
            TabToolbarSpecialSlot()
        }
        .hidden(!toolbarContext.hasTabSpecial)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.tabgroup0", placement: .primaryAction) {
            TabToolbarGroupSlot(index: 0)
        }
        .hidden(toolbarContext.tabGroupCount < 1)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.tabgroup1", placement: .primaryAction) {
            TabToolbarGroupSlot(index: 1)
        }
        .hidden(toolbarContext.tabGroupCount < 2)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.tabgroup2", placement: .primaryAction) {
            TabToolbarGroupSlot(index: 2)
        }
        .hidden(toolbarContext.tabGroupCount < 3)

        ToolbarSpacer(.fixed, placement: .primaryAction)
    }

    // MARK: - Right Side: Workspace Actions

    /// [Search · Overview · Refresh] [Bell · Inspector] (round IC, A1): the two buttons that open
    /// the inspector column share their own capsule at the trailing edge, above the column.
    /// Refresh is there only while the front tab can reload (round 34, RL1). In a narrow window
    /// these stay and the tab's buttons give way first (round 37.5, NW1).
    @ToolbarContentBuilder
    private var workspaceActionItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            SearchToolbarButton()
            TabOverviewToolbarButton()
            if toolbarContext.canReload {
                RefreshToolbarButton()
            }
        }
        .keptOutOfOverflow()

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItemGroup(placement: .primaryAction) {
            NotificationBellToolbarButton()
            InspectorToolbarButton()
        }
        .keptOutOfOverflow()
    }

    /// Changes only when the active tab needs other groups, so the toolbar content isn't rebuilt on
    /// every tab switch or while a tab's own state changes.
    private var toolbarContext: WorkspaceToolbarContext { tabStore.activeTabToolbarContext }
}
