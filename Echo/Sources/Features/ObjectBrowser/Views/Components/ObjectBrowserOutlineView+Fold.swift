import SwiftUI

/// Round 30.2, CM2: a server card folds while its rows fade. For the length of the fold the
/// card's edge glides (ExplorerTreeCardsLayer) and the rows leaving or arriving fade and are cut
/// by it (ExplorerTreeFoldTransition), so no row shows outside the card.
extension ObjectBrowserOutlineView {
    /// Where a folding server's card ends open and closed; nil when it isn't folding.
    func fold(of group: ObjectBrowserTreeLayout.Group, in layout: ObjectBrowserTreeLayout) -> ExplorerTreeFold? {
        guard let server = group.header.first, let connectionID = server.node.row.connectionID,
              foldingConnectionIDs.contains(connectionID),
              let card = layout.cards.first(where: { $0.id == server.id })
        else { return nil }
        return ExplorerTreeFold(openBottom: card.minY + card.height,
                                closedBottom: server.minY + server.height + LayoutTokens.Workspace.treeCardBottomPadding,
                                cornerRadius: cornerRadius)
    }

    /// The cards whose edge glides in a fold: the folding servers' own.
    func foldingCardIDs(in layout: ObjectBrowserTreeLayout) -> Set<String> {
        guard !foldingConnectionIDs.isEmpty else { return [] }
        return Set(layout.groups.compactMap { group in
            guard let server = group.header.first, let id = server.node.row.connectionID, foldingConnectionIDs.contains(id) else { return nil }
            return server.id
        })
    }

    /// A folding card's rows fade and are cut by its edge; every other row fades as usual.
    func rowTransition(for row: ObjectBrowserTreeLayout.Row, fold: ExplorerTreeFold?) -> AnyTransition {
        guard let fold else { return Self.rowTransition(motion) }
        return AnyTransition(ExplorerTreeFoldTransition(fold: fold, rowTop: row.minY))
    }
}
