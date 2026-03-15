import SwiftUI
import Foundation
import AppKit
import EchoSense

struct WorkspaceToolbarItems: ToolbarContent {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    @Environment(EnvironmentState.self) private var environmentState

    var body: some ToolbarContent {
        ToolbarItem(id: "workspace.navigation.project", placement: .navigation) {
            ProjectMenuButton(
                projectStore: projectStore,
                navigationStore: navigationStore
            )
            .padding(.leading, SpacingTokens.xxs)
        }

        ToolbarItem(id: "workspace.navigation.spacer", placement: .navigation) {
            Spacer().frame(width: SpacingTokens.xs)
        }

        ToolbarItem(id: "workspace.navigation.connect", placement: .navigation) {
            ConnectToolbarMenuButton(
                connectionStore: connectionStore,
                projectStore: projectStore,
                environmentState: environmentState
            )
            .padding(.horizontal, SpacingTokens.xxxs)
        }

        ToolbarItem(id: "workspace.principal.spacer", placement: .principal) {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }

        ToolbarItem(id: "workspace.primary.refresh", placement: .primaryAction) {
            RefreshToolbarButton()
        }

        ToolbarItem(id: "workspace.primary.newtab", placement: .primaryAction) {
            NewTabToolbarButton()
        }

        ToolbarItem(id: "workspace.primary.taboverview", placement: .primaryAction) {
            TabOverviewToolbarButton()
        }

        ToolbarItem(id: "workspace.primary.toggleinspector", placement: .primaryAction) {
            InspectorToolbarButton()
        }
    }

}
