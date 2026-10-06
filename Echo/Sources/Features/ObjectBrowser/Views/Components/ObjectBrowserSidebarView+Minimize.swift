import SwiftUI

/// Minimized cards (round 51, SH5): a card closed with its header's chevron leaves the tree and
/// its server stays in the trail, below the open ones under a short hairline (round 55). Clicking it, or anything that reveals
/// the server (a tab, a new connection, a focus request), restores the card and selects it.
extension ObjectBrowserSidebarView {
    /// Tells the rail which servers are minimized now, inside the transaction that moves the card, so the
    /// item and the card start on the same frame and the same curve (round 55).
    func moveRailItems() {
        let now = viewModel.minimizedServers(sessions: sessions).connectionIDs
        if railBridge?.minimizedConnectionIDs != now { railBridge?.minimizedConnectionIDs = now }
    }

    /// The minimized set changed: tell the rail, and load what the restored cards had open.
    func applyMinimizedServers(from old: Set<UUID>, to new: Set<UUID>) {
        if railBridge?.minimizedConnectionIDs != new { railBridge?.minimizedConnectionIDs = new }
        guard !old.subtracting(new).isEmpty else { return }
        loadSourcesOfOpenFolders(in: ObjectBrowserSnapshotBuilder.buildRoots(
            pendingConnections: [],
            sessions: sessions,
            settings: projectStore.globalSettings,
            viewModel: viewModel
        ))
    }
}

/// The tree's calm message when it has nothing to list.
struct ExplorerEmptyState: View {
    let symbol: String
    let title: String
    let hint: String

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Image(systemName: symbol)
                .font(TypographyTokens.hero.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
            VStack(spacing: SpacingTokens.xxxs) {
                Text(title)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text(hint)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, SpacingTokens.xl2)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
