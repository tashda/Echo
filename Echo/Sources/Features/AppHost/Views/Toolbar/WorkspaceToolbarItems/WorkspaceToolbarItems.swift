import SwiftUI
import Foundation
import AppKit
import EchoSense

struct WorkspaceToolbarItems: ToolbarContent {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(NavigationStore.self) internal var navigationStore

    var body: some ToolbarContent {
        ToolbarItem(id: "workspace.navigation.project", placement: .navigation) {
            projectMenu
        }

        ToolbarItem(id: "workspace.principal.breadcrumb", placement: .principal) {
            BreadcrumbToolbarContent()
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
