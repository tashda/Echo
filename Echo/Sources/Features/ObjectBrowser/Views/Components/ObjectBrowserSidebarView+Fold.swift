import SwiftUI

/// Opening and minimizing a server's card (rounds 30.2, 46 and 51): the card's edge glides on `expand`,
/// the dock grows out of the header (DA2), and the card's rows come and go the way a section
/// switch swaps them (RA1, CL2): under a veil in the card's colour.
extension ObjectBrowserSidebarView {
    /// Opening:
    /// 1. every card is marked as folding, and this one's rows will arrive hidden under an opaque
    ///    veil, nothing moving yet (the veil exists at the closed card's size, so it can grow);
    /// 2. the server opens on `expand`: the edge and the veil glide down together while the dock
    ///    grows out of the header, cut by the edge;
    /// 3. the rows show under the veil, and the veil fades away (the switch's fade in).
    ///
    /// Closing:
    /// 1. the veil fades over the rows (the switch's fade out); every card is marked as folding,
    ///    so the dock leaves with the fold's transition (a leaving row keeps the one it last had);
    /// 2. if the view is scrolled into the card, it moves so the pinned header is at its own place
    ///    (nothing visible changes: the rows are covered);
    /// 3. the server closes on `expand`: the rows go at once under the veil, the edge glides up and
    ///    the dock shrinks back into the header; if the tree is now shorter than the view, the
    ///    view glides back with it until the tree fills it (ObjectBrowserOutlineView+Fold).
    ///
    /// Only this card is marked as folding: cards open and close independently. When it is
    /// minimized it leaves the list as the fold ends (round 51, SH5), and the cards below close
    /// the gap on `expand`; the others' rows move with their cards.
    func foldServerCard(of session: ConnectionSession, isExpanded: Bool) {
        let connectionID = session.connection.id
        viewModel.foldGeneration += 1
        let generation = viewModel.foldGeneration
        let timing = ExplorerDockSwitchTiming(motion: motion)
        let changing: Set<UUID> = [connectionID]
        WindowDragPause.pauseWorkspace(for: timing.totalDuration + 0.15)

        let toggle = {
            viewModel.setServerExpanded(isExpanded, connectionID: connectionID)
        }
        let finish = {
            withoutAnimation {
                _ = viewModel.dockHiddenRowsConnectionIDs.remove(connectionID)
                _ = viewModel.dockFadingConnectionIDs.remove(connectionID)
                _ = viewModel.dockSwitchingConnectionIDs.remove(connectionID)
            }
            if viewModel.foldGeneration == generation {
                viewModel.foldingConnectionIDs = []
                viewModel.travellingConnectionIDs = []
            }
        }
        // A closing card of a set-up server is minimized: it leaves the tree as one piece while its trail
        // item moves below the hairline, on the house spring in one transaction (round 55). No veil: the
        // rows go with the card.
        if !isExpanded, projectStore.globalSettings.closedCardDestination == .serverTrail,
           viewModel.initializedConnectionIDs.contains(connectionID) {
            travelServerCard(connectionID, arriving: false, finish: finish)
            return
        }

        if isExpanded {
            withAnimation(.linear(duration: 0)) {
                viewModel.foldingConnectionIDs = changing
                _ = viewModel.dockSwitchingConnectionIDs.insert(connectionID)
                _ = viewModel.dockFadingConnectionIDs.insert(connectionID)
                _ = viewModel.dockHiddenRowsConnectionIDs.insert(connectionID)
            } completion: {
                withAnimation(motion.expand) { toggle() } completion: {
                    withoutAnimation { _ = viewModel.dockHiddenRowsConnectionIDs.remove(connectionID) }
                    withAnimation(timing.fadeIn) { _ = viewModel.dockFadingConnectionIDs.remove(connectionID) } completion: { finish() }
                }
            }
        } else {
            withAnimation(timing.fadeOut) {
                viewModel.foldingConnectionIDs = changing
                _ = viewModel.dockSwitchingConnectionIDs.insert(connectionID)
                _ = viewModel.dockFadingConnectionIDs.insert(connectionID)
            } completion: {
                // The rows are covered: if the view is inside this card, bring its header to its
                // own place, then fold.
                withAnimation(.linear(duration: 0)) {
                    viewModel.foldAnchor = ExplorerFoldAnchor(connectionID: connectionID, request: generation)
                } completion: {
                    withAnimation(motion.expand) { toggle() } completion: { finish() }
                }
            }
        }
    }

    /// A card leaves the tree (minimized) or comes back (restored), as one piece with its rows, and the
    /// trail's item moves in the same transaction (round 55). The fold is marked first, in an update of its
    /// own, so rows and cards already carry the right transitions and the tree's dock-switch rule
    /// (no animation for a section change) doesn't swallow the change.
    func travelServerCard(_ connectionID: UUID, arriving: Bool, finish: (() -> Void)? = nil) {
        viewModel.foldGeneration += 1
        let generation = viewModel.foldGeneration
        WindowDragPause.pauseWorkspace(for: motion.settleDuration + 0.15)
        let settle = {
            if viewModel.foldGeneration == generation {
                viewModel.foldingConnectionIDs = []
                viewModel.travellingConnectionIDs = []
            }
            finish?()
            if !arriving { hideSidebarWhenNoCardIsLeft() }
        }
        withAnimation(.linear(duration: 0)) {
            viewModel.foldingConnectionIDs = [connectionID]
            viewModel.travellingConnectionIDs = [connectionID]
        } completion: {
            withAnimation(motion.standard) {
                viewModel.setServerExpanded(arriving, connectionID: connectionID)
                moveRailItems()
            } completion: { settle() }
        }
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}
