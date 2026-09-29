import SwiftUI

struct WorkspaceToolbarItems: ToolbarContent {
    var body: some ToolbarContent {
        navigationItems
        centerItems
        contextActionItems
        workspaceActionItems
    }

    // MARK: - Left Side (Navigation)

    @ToolbarContentBuilder
    private var navigationItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            ProjectContextMenuButton()
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .navigation) {
            // Saved connections open from the + in the rail's server pill.
            RecentConnectionsMenuButton()
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .navigation) {
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

    // MARK: - Right Side: Context-Specific Actions

    @ToolbarContentBuilder
    private var contextActionItems: some ToolbarContent {
        // Structure tab — Add/Script/Apply buttons
        ToolbarItem(id: "workspace.primary.structure", placement: .primaryAction) {
            TableStructureToolbarItem()
        }
        .sharedBackgroundVisibility(.hidden)

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
    private var workspaceActionItems: some ToolbarContent {
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
