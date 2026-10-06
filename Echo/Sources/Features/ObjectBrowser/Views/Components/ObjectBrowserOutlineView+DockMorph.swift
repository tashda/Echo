import SwiftUI

/// Round 57 (HB3, MP0, PS0): with the title banner, a card's name block scrolls away with its
/// rows, and the dock row morphs into a floating pill held at the top of the view, pushed out by the
/// next card (`ExplorerDockMorph`). Other header styles keep the pinned header.
extension ObjectBrowserOutlineView {
    /// The morph for a group's dock row; nil when the header isn't a title banner with a dock.
    func dockMorph(of group: ObjectBrowserTreeLayout.Group, in layout: ObjectBrowserTreeLayout) -> ExplorerDockMorph? {
        guard dockMorphs, group.header.count == 2, let server = group.header.first,
              let card = layout.cards.first(where: { $0.id == server.id })
        else { return nil }
        return ExplorerDockMorph(cardTop: server.minY, nameHeight: server.height, dockHeight: group.header[1].height,
                                 cardBottom: card.minY + card.height)
    }

    /// The name block in its place, scrolling with the card, and the dock row above the rows.
    @ViewBuilder
    func morphingHeader(_ group: ObjectBrowserTreeLayout.Group, morph: ExplorerDockMorph, fold: ExplorerTreeFold?,
                        shift: CGFloat, cardTop: CGFloat? = nil) -> some View {
        let server = group.header[0]
        let dock = group.header[1]
        // A travelling card's banner and dock settle with the whole card, each about the card's top.
        let serverTransition = headerTransition(shift: shift, cardTop: cardTop, rowTop: server.minY, height: server.height)
        let dockTransition = headerTransition(shift: shift, cardTop: cardTop, rowTop: dock.minY, height: dock.height)
        rowSlot(server, isSwitching: cardTop != nil, fold: fold)
            .transition(serverTransition)
            .explorerTreePlace(minY: server.minY, height: server.height)
        rowSlot(dock, isSwitching: cardTop != nil, fold: fold)
            .transition(dockTransition)
            .explorerDockMorph(morph, scroll: scroll)
            .zIndex(1)
            .explorerTreePlace(minY: dock.minY, height: dock.height)
    }

    /// How a server's header (or its banner and dock) arrives and leaves: with its card as one piece, shifted
    /// with a card that moved, or fading.
    func headerTransition(shift: CGFloat, cardTop: CGFloat?, rowTop: CGFloat, height: CGFloat) -> AnyTransition {
        if let cardTop {
            return AnyTransition(ExplorerTreeCardUnitTransition(cardTop: cardTop, rowTop: rowTop, rowHeight: height))
        }
        return abs(shift) > SpacingTokens.micro ? .offset(y: shift) : .opacity
    }

    /// The veils start under the pill instead of under a pinned header.
    func morphAwareVeils(_ veils: [ExplorerTreeVeil]) -> [ExplorerTreeVeil] {
        guard dockMorphs else { return veils }
        return veils.map {
            ExplorerTreeVeil(id: $0.id, bodyTop: $0.bodyTop, bodyBottom: $0.bodyBottom,
                             headerHeight: ExplorerDockMorph.pillTop + ExplorerDockMorph.pillHeight, isOpaque: $0.isOpaque)
        }
    }

    /// The group whose pill is under a point (in the tree's view), if any: right-clicking it is the
    /// dock's, not the row's behind it.
    func dockPillRow(at point: CGPoint, in layout: ObjectBrowserTreeLayout) -> ObjectBrowserTreeLayout.Row? {
        for group in layout.groups {
            guard let morph = dockMorph(of: group, in: layout) else { continue }
            let offset = scroll.offset
            let progress = morph.progress(offset: offset)
            let top = morph.top(offset: offset)
            let height = morph.height(progress: progress)
            let width = morph.width(cardWidth: scroll.contentWidth, progress: progress)
            let left = (scroll.contentWidth - width) / 2
            if point.y >= top, point.y < top + height, point.x >= left, point.x < left + width { return group.header[1] }
        }
        return nil
    }

    // MARK: - Choosing a section (CK1) and where each section was left

    /// A switch is starting: remember how far into the card the view was in the section it leaves.
    func saveDockPlaces(of connectionIDs: Set<UUID>, in layout: ObjectBrowserTreeLayout) {
        let selections = layout.dockSelections
        for connectionID in connectionIDs {
            guard let section = selections[connectionID], let top = layout.serverTop(connectionID) else { continue }
            dockPlaces.save(scroll.offset - top, connectionID: connectionID, section: section)
        }
    }

    /// The new section is in, under the veil: the view scrolls smoothly to where this section was
    /// left, or to the card's top the first time; the dock opens back out of its pill as it goes.
    func returnToDockPlaces(changedFrom old: [UUID: String], to new: [UUID: String], in layout: ObjectBrowserTreeLayout) {
        let maxOffset = max(0, layout.contentHeight - scroll.viewportHeight)
        for (connectionID, section) in new where old[connectionID] != nil && old[connectionID] != section {
            guard let top = layout.serverTop(connectionID),
                  let y = dockPlaces.target(connectionID: connectionID, section: section, cardTop: top,
                                            offset: scroll.offset, maxOffset: maxOffset)
            else { continue }
            prepareWindow(for: y)
            withAnimation(motion.dockScroll) { position.scrollTo(y: y) }
        }
    }

    /// A server left the tree: its cards forget where their sections were left.
    func forgetDockPlaces(in layout: ObjectBrowserTreeLayout) {
        let present = Set(layout.rows.compactMap { $0.role.kind == .server ? $0.role.connectionID : nil })
        dockPlaces.drop(keeping: present)
    }
}
