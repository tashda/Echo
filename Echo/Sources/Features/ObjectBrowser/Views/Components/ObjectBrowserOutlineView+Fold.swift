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
    /// without fading (round 46, DA2). A row that arrives because its card moved (it was too far
    /// away to be drawn) starts where its card was and travels with it; every other row fades.
    func rowTransition(for row: ObjectBrowserTreeLayout.Row, fold: ExplorerTreeFold?, arrivingFrom shift: CGFloat = 0) -> AnyTransition {
        guard let fold else {
            guard abs(shift) > SpacingTokens.micro else { return Self.rowTransition(motion) }
            return .asymmetric(insertion: .offset(y: shift), removal: .opacity.animation(motion.rowRemoval))
        }
        let style: ExplorerTreeFoldTransition.Style = if case .dock = row.node.row { .grow } else { .fade }
        return AnyTransition(ExplorerTreeFoldTransition(fold: fold, rowTop: row.minY, style: style))
    }

    /// Closing a card you have scrolled into: its header is pinned at the top while its own place
    /// is above the view. Once the veil covers the rows, the view moves, with nothing visible
    /// changing, so the header's own place is where it is pinned; the fold then can't leave it
    /// above the view.
    func anchorClosingCard(_ connectionID: UUID, in layout: ObjectBrowserTreeLayout) {
        guard let server = layout.groups.first(where: { $0.header.first?.node.row.connectionID == connectionID })?.header.first,
              server.minY < scroll.offset - SpacingTokens.micro
        else { return }
        var still = Transaction()
        still.disablesAnimations = true
        prepareWindow(for: server.minY)
        withTransaction(still) { position.scrollTo(y: server.minY) }
    }

    /// After a fold leaves the tree shorter than what the view shows, the view glides back with
    /// the fold until the tree fills it, rather than keeping the empty room below the last card
    /// (that hold, N2, is for section switches).
    func settleAfterFold(in layout: ObjectBrowserTreeLayout) {
        guard !foldingConnectionIDs.isEmpty else { return }
        let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
        guard scroll.offset > maxOffset + SpacingTokens.micro else { return }
        prepareWindow(for: maxOffset)
        withAnimation(rowsCurve) { position.scrollTo(y: maxOffset) }
    }
}

/// Asks the tree to bring a closing card's header to its own place (round 46).
struct ExplorerFoldAnchor: Equatable {
    let connectionID: UUID
    let request: Int
}
