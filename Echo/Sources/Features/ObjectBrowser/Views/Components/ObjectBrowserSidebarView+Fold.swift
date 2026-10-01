import SwiftUI

/// Round 30.2, CM2: a server card folds while its rows fade, and opens the same way.
extension ObjectBrowserSidebarView {
    /// Opens or closes a server's card in two steps:
    /// 1. the cards are marked as folding with nothing moving, so the rows about to leave are
    ///    drawn once with the fold's transition (a leaving row keeps the transition it last had);
    /// 2. the server opens or closes on `expand`: the card's edge glides and its rows fade and are
    ///    cut by the edge (ObjectBrowserOutlineView+Fold). The mark is cleared when it ends.
    /// Every server is marked, since opening one can close the others (one server at a time).
    func foldServerCard(of session: ConnectionSession, isExpanded: Bool) {
        let connectionID = session.connection.id
        viewModel.foldGeneration += 1
        let generation = viewModel.foldGeneration
        WindowDragPause.pauseWorkspace(for: 0.22 * motion.durationScale + 0.15)
        withAnimation(.linear(duration: 0)) {
            viewModel.foldingConnectionIDs = Set(sessions.map(\.connection.id))
        } completion: {
            withAnimation(motion.expand) {
                viewModel.setServerExpanded(
                    isExpanded,
                    connectionID: connectionID,
                    sessions: sessions,
                    collapseOthers: projectStore.globalSettings.sidebarExpandOneConnectionAtATime
                )
            } completion: {
                guard viewModel.foldGeneration == generation else { return }
                viewModel.foldingConnectionIDs = []
            }
        }
    }
}
