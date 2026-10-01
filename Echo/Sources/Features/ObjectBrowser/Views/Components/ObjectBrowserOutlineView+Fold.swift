import SwiftUI

/// Round 30.2, CM2: a server card folds; for the length of the fold the card's edge glides
/// (ExplorerTreeCardsLayer) and the dock grows out of the header, cut by the edge
/// (ExplorerTreeFoldTransition, round 46). The opening or closing card's own rows come and go under
/// the section switch's veil (ObjectBrowserSidebarView+Fold); other cards' rows fade and are cut.
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

    /// A folding card's rows fade and are cut by its edge, and its dock grows out of the header
    /// without fading (round 46, DA2); every other row fades as usual.
    func rowTransition(for row: ObjectBrowserTreeLayout.Row, fold: ExplorerTreeFold?) -> AnyTransition {
        guard let fold else { return Self.rowTransition(motion) }
        let style: ExplorerTreeFoldTransition.Style = if case .dock = row.node.row { .grow } else { .fade }
        return AnyTransition(ExplorerTreeFoldTransition(fold: fold, rowTop: row.minY, style: style))
    }
}
