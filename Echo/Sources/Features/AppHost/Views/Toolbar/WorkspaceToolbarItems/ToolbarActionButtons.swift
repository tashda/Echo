import SwiftUI

// MARK: - Isolated Toolbar Buttons
// Each button is its own View so state observation stays inside the
// view body, preventing the @ToolbarContentBuilder from re-evaluating
// when appState / tabStore / environmentState change.

struct InspectorToolbarButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.showInfoSidebar.toggle()
        } label: {
            Label("Inspector", systemImage: "sidebar.right")
                .symbolVariant(appState.showInfoSidebar ? .fill : .none)
        }
        .help(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
        .labelStyle(.iconOnly)
        .contentTransition(.identity)
        .accessibilityLabel(appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector")
    }
}
