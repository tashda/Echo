import SwiftUI
import Foundation
import AppKit
import EchoSense

struct WorkspaceToolbarItems: CustomizableToolbarContent {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    @Environment(EnvironmentState.self) internal var environmentState

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
            projectContextMenu
                .glassEffect(.regular.interactive())
        }
        .sharedBackgroundVisibility(.hidden)

        // Recent Connections + Connections — shared glass group
        ToolbarItem(id: "workspace.nav.recents", placement: .navigation) {
            recentConnectionsMenu
        }

        ToolbarItem(id: "workspace.nav.connections", placement: .navigation) {
            connectionsSelectionMenu
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
