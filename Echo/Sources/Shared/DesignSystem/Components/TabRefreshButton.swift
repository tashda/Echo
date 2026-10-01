import SwiftUI

/// The standard refresh action for toolbars inside workspace tabs.
/// Keeps the native button behavior and accessible label while presenting a
/// stable, icon-only control in every tab.
struct TabRefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    init(isRefreshing: Bool, action: @escaping () -> Void) {
        self.isRefreshing = isRefreshing
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .opacity(isRefreshing ? 0 : 1)
                .overlay {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityHidden(true)
                    }
                }
                .contentTransition(.identity)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(isRefreshing)
        .help(isRefreshing ? "Refreshing" : "Refresh this tab")
        .accessibilityLabel(isRefreshing ? "Refreshing" : "Refresh")
    }
}
