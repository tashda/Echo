import SwiftUI

struct WorkspaceToolbarItems: CustomizableToolbarContent {
    var body: some CustomizableToolbarContent {
        navigationItems
        centerItems
        contextActionItems
        workspaceActionItems
    }

    // MARK: - Left Side (Navigation)

    @ToolbarContentBuilder
    private var navigationItems: some CustomizableToolbarContent {
        // Project — own glass group
        ToolbarItem(id: "workspace.nav.project", placement: .navigation) {
            ProjectContextMenuButton()
                .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        // Recent Connections + Connections — shared glass group
        ToolbarItem(id: "workspace.nav.recents", placement: .navigation) {
            RecentConnectionsMenuButton()
        }

        ToolbarItem(id: "workspace.nav.connections", placement: .navigation) {
            ConnectionsMenuButton()
        }

        // Quick Connect — own glass group
        ToolbarItem(id: "workspace.nav.quickconnect", placement: .navigation) {
            Button {
                AppDirector.shared.appState.showSheet(.quickConnect)
            } label: {
                Label("Quick Connect", systemImage: "bolt.fill")
            }
            .labelStyle(.iconOnly)
            .help("Quick Connect")
            .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)
    }

    // MARK: - Center (Breadcrumb spacer)

    @ToolbarContentBuilder
    private var centerItems: some CustomizableToolbarContent {
        ToolbarItem(id: "workspace.principal.spacer", placement: .principal) {
            Color.clear
                .frame(width: SpacingTokens.none, height: SpacingTokens.none)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Right Side: Context-Specific Actions

    @ToolbarContentBuilder
    private var contextActionItems: some CustomizableToolbarContent {
        // Activity Monitor, Job Queue, Maintenance — tab-specific controls
        ToolbarItem(id: "workspace.primary.activitymonitor", placement: .primaryAction) {
            ActivityMonitorToolbarItem()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(id: "workspace.primary.jobqueueplay", placement: .primaryAction) {
            JobQueuePlayToolbarItem()
        }

        ToolbarItem(id: "workspace.primary.jobqueuepopout", placement: .primaryAction) {
            JobQueuePopOutToolbarItem()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(id: "workspace.primary.errorlogcycle", placement: .primaryAction) {
            ErrorLogCycleToolbarItem()
                .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(id: "workspace.primary.tabcontext", placement: .primaryAction) {
            TabContextToolbarButton()
        }
        .sharedBackgroundVisibility(.hidden)

        // Run — standalone, leftmost query action
        ToolbarItem(id: "workspace.primary.queryrun", placement: .primaryAction) {
            QueryRunToolbarItem()
        }
        .sharedBackgroundVisibility(.hidden)

        // Format + Estimated Plan — "enhance" group
        ToolbarItem(id: "workspace.primary.queryenhance", placement: .primaryAction) {
            QueryEditorEnhanceToolbarControls()
        }
        .sharedBackgroundVisibility(.hidden)

        // Database-specific mode toggles (SQLCMD, Statistics)
        ToolbarItem(id: "workspace.primary.querydb", placement: .primaryAction) {
            QueryEditorDatabaseToolbarControls()
        }
        .sharedBackgroundVisibility(.hidden)
    }

    // MARK: - Right Side: Workspace Actions

    @ToolbarContentBuilder
    private var workspaceActionItems: some CustomizableToolbarContent {
        // Refresh — standalone with own glass
        ToolbarItem(id: "workspace.primary.refresh", placement: .primaryAction) {
            RefreshToolbarButton()
                .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        // Inspector — standalone, rightmost
        ToolbarItem(id: "workspace.primary.inspector", placement: .primaryAction) {
            InspectorToolbarButton()
        }
    }
}
