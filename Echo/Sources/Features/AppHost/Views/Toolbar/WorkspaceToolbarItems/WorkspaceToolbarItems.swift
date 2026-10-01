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

    /// The front tab's own buttons (round 37.5): its symbol, its special button (Run, Start Trace,
    /// New Backup…) and one capsule of its other buttons, before the window's icons. One custom
    /// item that draws its own glass, so the glass can reshape from one tab's buttons to the next.
    @ToolbarContentBuilder
    private var contextActionItems: some ToolbarContent {
        // The owner, 2026-10-01: Open in New Window is its own group at the start of the right-hand
        // side, not in the tab's header.
        ToolbarItem(id: "workspace.primary.openinwindow", placement: .primaryAction) {
            OpenInWindowToolbarButton()
        }
        .hidden(!toolbarContext.canOpenInWindow)

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(id: "workspace.primary.tabsection", placement: .primaryAction) {
            TabToolbarSectionView()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarSpacer(.fixed, placement: .primaryAction)
    }

    // MARK: - Right Side: Workspace Actions

    /// [Search · Overview · Refresh · Bell · Inspector] share one capsule; Inspector stays last.
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
            NotificationBellToolbarButton()
            InspectorToolbarButton()
        }
        .keptOutOfOverflow()
    }

    /// Changes only when the active tab needs other groups, so the toolbar content isn't rebuilt on
    /// every tab switch or while a tab's own state changes.
    private var toolbarContext: WorkspaceToolbarContext { tabStore.activeTabToolbarContext }
}
