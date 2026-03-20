import SwiftUI

struct WorkspaceToolbarItems: CustomizableToolbarContent {
    var body: some CustomizableToolbarContent {
        navigationItems
        centerItems
        primaryActionItems
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

    // MARK: - Right Side (Primary Actions)

    @ToolbarContentBuilder
    private var primaryActionItems: some CustomizableToolbarContent {
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

        ToolbarItem(id: "workspace.primary.tabcontext", placement: .primaryAction) {
            TabContextToolbarButton()
        }
        .sharedBackgroundVisibility(.hidden)

        // Database-specific query controls (e.g. MSSQL: SQLCMD, Statistics)
        ToolbarItem(id: "workspace.primary.querydb", placement: .primaryAction) {
            QueryEditorDatabaseToolbarControls()
        }
        .sharedBackgroundVisibility(.hidden)

        // Generic query controls (Estimated Plan)
        ToolbarItem(id: "workspace.primary.querygeneric", placement: .primaryAction) {
            QueryEditorToolbarControls()
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(id: "workspace.primary.refresh", placement: .primaryAction) {
            RefreshToolbarButton()
        }

        ToolbarItem(id: "workspace.primary.taboverview", placement: .primaryAction) {
            TabOverviewToolbarButton()
        }

        ToolbarItem(id: "workspace.primary.newtab", placement: .primaryAction) {
            NewTabToolbarButton()
        }

        ToolbarItem(id: "workspace.primary.inspector", placement: .primaryAction) {
            InspectorToolbarButton()
        }
    }
}
