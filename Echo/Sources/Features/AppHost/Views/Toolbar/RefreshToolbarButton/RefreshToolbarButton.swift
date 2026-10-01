import SwiftUI

/// Refresh (round 34): in the toolbar only while the front tab can reload (RL1), and showing only
/// its own reload (AS2). Query runs show on Run; other long operations on the bell.
struct RefreshToolbarButton: View {
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        if let tab = tabStore.activeTab, TabReloader.canReload(tab.kind) {
            let reloader = environmentState.tabReloader
            RefreshButtonContent(
                phase: reloader.phase(for: tab),
                resultMessage: reloader.message,
                onRefresh: { reloader.reload(tab, environmentState: environmentState) },
                onCancel: { reloader.cancel() }
            )
        }
    }
}
