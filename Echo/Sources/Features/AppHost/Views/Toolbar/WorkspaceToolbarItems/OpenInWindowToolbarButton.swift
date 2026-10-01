import SwiftUI

/// Moves the front tool tab into a window of its own (the owner, 2026-10-01: in the toolbar, its
/// own group at the start of the right-hand side, not in the tab). Only Agent Jobs opens in a window.
struct OpenInWindowToolbarButton: View {
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            guard let tab = tabStore.activeTab, tab.kind == .jobQueue,
                  let sessionID = environmentState.popOutJobQueueTab(tab) else { return }
            openWindow(id: JobQueueWindow.sceneID, value: sessionID)
        } label: {
            Label("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .labelStyle(.iconOnly)
        .help("Open in New Window")
    }
}
