import SwiftUI
import EchoSense

// MARK: - Isolated Toolbar Buttons
// Each button is its own View so state observation stays inside the
// view body, preventing the @ToolbarContentBuilder from re-evaluating
// when appState / tabStore / environmentState change.

struct NewTabToolbarButton: View {
    @EnvironmentObject private var environmentState: EnvironmentState
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(ConnectionStore.self) private var connectionStore

    var body: some View {
        Button {
            environmentState.openQueryTab()
        } label: {
            Label("New Tab", systemImage: "plus")
        }
        .help("Open a new query tab")
        .disabled(!canOpenNewTab)
        .labelStyle(.iconOnly)
        .accessibilityLabel("New Tab")
    }

    private var canOpenNewTab: Bool {
        if let connection = navigationStore.navigationState.selectedConnection,
           let _ = environmentState.sessionCoordinator.sessionForConnection(connection.id) {
            return true
        }
        return environmentState.sessionCoordinator.activeSession != nil
            || environmentState.sessionCoordinator.activeSessions.first != nil
    }
}

struct TabOverviewToolbarButton: View {
    @EnvironmentObject private var appState: AppState
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        Button {
            appState.showTabOverview.toggle()
        } label: {
            Label(
                appState.showTabOverview ? "Hide Tab Overview" : "Tab Overview",
                systemImage: appState.showTabOverview ? "rectangle.grid.2x2.fill" : "rectangle.grid.2x2"
            )
        }
        .help(appState.showTabOverview ? "Hide Tab Overview" : "Show all tabs")
        .disabled(!tabStore.hasTabs)
        .labelStyle(.iconOnly)
        .contentTransition(.identity)
        .accessibilityLabel(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview")
    }
}

struct InspectorToolbarButton: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            appState.showInfoSidebar.toggle()
        } label: {
            Label(
                appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector",
                systemImage: appState.showInfoSidebar ? "sidebar.trailing" : "sidebar.right"
            )
        }
        .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
        .labelStyle(.iconOnly)
        .contentTransition(.identity)
        .accessibilityLabel(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
    }
}
