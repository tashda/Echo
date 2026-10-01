import SwiftUI

// MARK: - Isolated Toolbar Buttons
// Each button is its own View so state observation stays inside the
// view body, preventing the @ToolbarContentBuilder from re-evaluating
// when appState / tabStore / environmentState change.

struct InspectorToolbarButton: View {
    @Environment(AppState.self) private var appState

    private var showsDetails: Bool { appState.showInfoSidebar && !appState.isNotificationHistoryVisible }

    var body: some View {
        Button {
            appState.toggleInspector()
        } label: {
            Label("Inspector", systemImage: "sidebar.right")
                .symbolVariant(showsDetails ? .fill : .none)
        }
        .help(showsDetails ? "Hide Inspector" : "Show Inspector")
        .labelStyle(.iconOnly)
        .contentTransition(.identity)
        .accessibilityLabel(showsDetails ? "Hide Inspector" : "Show Inspector")
    }
}

/// Opens and closes the tab overview, the ⌘K palette on this window's tabs (round 35.1); ⇧⌘O and
/// a trackpad pinch do the same.
struct TabOverviewToolbarButton: View {
    @Environment(AppState.self) private var appState
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        Button {
            appState.toggleTabOverview()
        } label: {
            Label(appState.isTabOverviewVisible ? "Hide Tab Overview" : "Show Tab Overview", systemImage: "square.grid.2x2")
                .symbolVariant(appState.isTabOverviewVisible ? .fill : .none)
        }
        .labelStyle(.iconOnly)
        .disabled(!tabStore.hasTabs && !appState.isTabOverviewVisible)
        .help(appState.isTabOverviewVisible ? "Hide Tab Overview (⇧⌘O)" : "Show Tab Overview (⇧⌘O)")
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
