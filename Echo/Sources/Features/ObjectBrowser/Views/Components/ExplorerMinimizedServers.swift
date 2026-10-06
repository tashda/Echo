import Foundation

/// Which servers' cards are minimized (round 51, SH5). A minimized card leaves the tree entirely
/// and its item moves below the hairline in the trail's connected pill (round 55); opening it from the trail restores it.
///
/// With the setting "When a Card Is Closed" on Header Card, nothing is minimized: a closed card stays in the tree as its header.
///
/// The state is the one a card's header chevron already writes: a server whose node is not in the
/// expanded set. A server not yet set up (`initializedConnectionIDs`) is never minimized, so a
/// card that has just connected does not drop below the hairline before it opens.
nonisolated struct ExplorerMinimizedServers: Equatable, Sendable {
    let connectionIDs: Set<UUID>

    init(
        sessionConnectionIDs: [UUID],
        initializedConnectionIDs: Set<UUID>,
        expandedNodeIDs: Set<String>,
        movesToTrail: Bool = true
    ) {
        // A card closed to its header alone stays in the tree: nothing is minimized.
        connectionIDs = !movesToTrail ? [] : Set(sessionConnectionIDs.filter { id in
            initializedConnectionIDs.contains(id)
                && !expandedNodeIDs.contains(ObjectBrowserSidebarViewModel.serverNodeID(connectionID: id))
        })
    }

    func isMinimized(_ connectionID: UUID) -> Bool {
        connectionIDs.contains(connectionID)
    }

    /// The servers whose cards stay in the tree, in order.
    func shown(from sessionConnectionIDs: [UUID]) -> [UUID] {
        sessionConnectionIDs.filter { !connectionIDs.contains($0) }
    }

    /// Every server is minimized and nothing else is in the tree: it shows its calm empty state.
    func leavesTreeEmpty(sessionConnectionIDs: [UUID], pendingCount: Int) -> Bool {
        !sessionConnectionIDs.isEmpty && pendingCount == 0 && shown(from: sessionConnectionIDs).isEmpty
    }
}
