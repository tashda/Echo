import SwiftUI

/// Cycle Log button that appears in the toolbar when an Error Log tab is active.
struct ErrorLogCycleToolbarItem: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, let vm = tab.errorLogVM {
            Button {
                Task { await vm.cycleLog() }
            } label: {
                Label("Cycle Log", systemImage: "arrow.triangle.2.circlepath")
            }
            .labelStyle(.iconOnly)
            .help("Archive the current error log and start a new one")
        } else {
            EmptyView()
        }
    }
}
