import SwiftUI

/// The rows on the canvas: only those near the view (`ExplorerTreeWindow`), each at its exact
/// place from the layout. A server's name and dock are one header that pins at the top while its
/// rows scroll under it, until the card's last row pushes it up (TC1).
extension ObjectBrowserOutlineView {
    /// Only `ExplorerTreeWindowed` reads the window, so stepping it rebuilds the rows and nothing
    /// else: the layout, cards and veil stay as they are.
    func rowsCanvas(_ layout: ObjectBrowserTreeLayout) -> some View {
        let groups = layout.groups
        let tops = Self.cardTops(layout)
        return ExplorerTreeWindowed(scroll: scroll) { window in
            rowsCanvas(layout, groups: groups, tops: tops, window: window)
        }
    }

    private func rowsCanvas(_ layout: ObjectBrowserTreeLayout, groups allGroups: [ObjectBrowserTreeLayout.Group],
                            tops: [String: CGFloat], window: ExplorerTreeWindow) -> some View {
        let groups = allGroups.filter { group in
            guard let first = group.header.first ?? group.rows.first, let last = group.rows.last ?? group.header.last else { return false }
            return window.intersects(minY: first.minY, maxY: last.minY + last.height)
        }
        return ExplorerTreeCanvasLayout(height: layout.contentHeight) {
            ForEach(groups) { group in
                let fold = fold(of: group, in: layout)
                let morph = dockMorph(of: group, in: layout)
                let headerHeight = morph == nil ? group.header.reduce(SpacingTokens.none) { $0 + $1.height } : SpacingTokens.none
                let shift = cardShift(of: group, tops: tops)
                let cardTop = travellingCardTop(of: group, in: layout)
                ForEach(group.rows.filter { window.intersects(minY: $0.minY, maxY: $0.minY + $0.height) }) { row in
                    rowSlot(row, underHeaderOf: headerHeight, isSwitching: isSwitching(group), fold: fold, arrivingFrom: shift, cardTop: cardTop)
                        .opacity(hidesRows(group) ? 0 : 1)
                        .explorerTreePlace(minY: row.minY, height: row.height)
                }
                if let morph, group.header.count == 2 {
                    morphingHeader(group, morph: morph, fold: fold, shift: shift, cardTop: cardTop)
                } else if let server = group.header.first {
                    let sectionEnd = group.rows.last.map { $0.minY + $0.height } ?? server.minY + headerHeight
                    VStack(spacing: SpacingTokens.none) {
                        ForEach(group.header) { row in rowSlot(row, isSwitching: cardTop != nil, fold: fold) }
                    }
                    .transition(headerTransition(shift: shift, cardTop: cardTop, rowTop: server.minY, height: headerHeight))
                    .background { ExplorerPinnedHeaderWash() }
                    .modifier(ExplorerTreePinnedHeader(travel: sectionEnd - server.minY - headerHeight))
                    .zIndex(1)
                    .explorerTreePlace(minY: server.minY, height: headerHeight)
                }
            }
        }
    }

    /// Before the view jumps or glides somewhere, builds the rows there too, so it never lands on
    /// a frame without them.
    func prepareWindow(for offset: CGFloat) {
        let target = ExplorerTreeWindow.around(offset: offset, viewport: scroll.viewportHeight)
        let current = scroll.window
        let both = ExplorerTreeWindow(minY: min(current.minY, target.minY), maxY: max(current.maxY, target.maxY))
        if both != current { scroll.window = both }
    }

    /// Each card's top, by its first row.
    static func cardTops(_ layout: ObjectBrowserTreeLayout) -> [String: CGFloat] {
        Dictionary(layout.cards.map { ($0.id, $0.minY) }, uniquingKeysWith: { first, _ in first })
    }

    /// How far a group's card has moved since the last change (zero for a group with no header
    /// or a new card): its rows that arrive now start that far off, where the card was.
    func cardShift(of group: ObjectBrowserTreeLayout.Group, tops: [String: CGFloat]) -> CGFloat {
        guard let server = group.header.first, let now = tops[server.id], let before = previousCardTops[server.id] else { return 0 }
        return before - now
    }
}
