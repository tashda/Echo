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

/// Opens and closes the tab overview (plan O1); ⇧⌘O and a trackpad pinch do the same.
struct TabOverviewToolbarButton: View {
    @Environment(AppState.self) private var appState
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        Button {
            appState.showTabOverview.toggle()
        } label: {
            Label(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview", systemImage: "square.grid.2x2")
                .symbolVariant(appState.showTabOverview ? .fill : .none)
        }
        .labelStyle(.iconOnly)
        .disabled(!tabStore.hasTabs && !appState.showTabOverview)
        .help(appState.showTabOverview ? "Hide Tab Overview (⇧⌘O)" : "Show Tab Overview (⇧⌘O)")
    }
}

/// Opens the ⌘K palette, which is Echo's search (owner, 2026-09-30).
struct SearchToolbarButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.isCommandPaletteVisible.toggle()
        } label: {
            Label("Search", systemImage: "magnifyingglass")
        }
        .labelStyle(.iconOnly)
        .help("Search (⌘K)")
    }
}
