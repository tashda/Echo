import SwiftUI
import Foundation
import AppKit
import EchoSense

struct WorkspaceToolbarItems: ToolbarContent {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    @EnvironmentObject private var environmentState: EnvironmentState

    var body: some ToolbarContent {
        ToolbarItem(id: "workspace.navigation.project", placement: .navigation) {
            projectMenu
        }

        ToolbarItem(id: "workspace.navigation.connections", placement: .navigation) {
            ConnectionsMenuButton(
                connectionStore: connectionStore,
                projectStore: projectStore,
                environmentState: environmentState,
                title: connectionsTitle
            )
        }

        ToolbarItem(id: "workspace.navigation.databases", placement: .navigation) {
            DatabasesMenuButton(
                connectionStore: connectionStore,
                environmentState: environmentState,
                title: databaseTitle,
                isEnabled: connectionStore.selectedConnectionID != nil
            )
        }

        ToolbarItem(id: "workspace.status", placement: .primaryAction) {
            Text(statusText)
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .sharedBackgroundVisibility(.hidden)

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

    // MARK: - Derived State

    private var connectionsTitle: String {
        connectionStore.selectedConnection.map {
            $0.connectionName.isEmpty ? $0.host : $0.connectionName
        } ?? "Connections"
    }

    private var databaseTitle: String {
        (connectionStore.selectedConnectionID.flatMap {
            environmentState.sessionCoordinator.sessionForConnection($0)
        }?.selectedDatabaseName).map {
            $0.isEmpty ? "Databases" : $0
        } ?? "Databases"
    }

    private var statusText: String {
        guard let id = connectionStore.selectedConnectionID else { return "No Connection" }
        switch environmentState.connectionStates[id] {
        case .testing: return "Testing\u{2026}"
        case .connecting: return "Connecting\u{2026}"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        default:
            return environmentState.sessionCoordinator.sessionForConnection(id) != nil
                ? "Connected" : "Disconnected"
        }
    }

}
