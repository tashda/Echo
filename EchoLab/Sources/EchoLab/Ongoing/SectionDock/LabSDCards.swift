import SwiftUI

/// One card per server behind the rows, cut to the visible part of the tree (Echo's
/// `ExplorerTreeCardsLayer`, with the editor card's own `.workspaceCard()`).
///
/// N0 (today) animates the whole layer whenever any row changes, so when the list gets shorter
/// and the view scrolls back, cards you didn't touch animate too. N1 and N2 animate a card only
/// when its own place or height changes.
struct LabSDCardsLayer: View {
    let cards: [LabSDLayout.Card]
    let scroll: LabSDScroll
    let neighbours: LabSDNeighbours
    let motion: EchoMotion
    let selections: [String]
    let rowIDs: [String]

    var body: some View {
        let layer = ZStack(alignment: .top) {
            ForEach(cards) { card in
                cardView(card)
                    .modifier(LabSDOwnCardAnimation(isOn: neighbours != .today, motion: motion, minY: card.minY, height: card.height))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)

        if neighbours == .today {
            layer.animation(motion.settle, value: selections).animation(motion.expand, value: rowIDs)
        } else {
            // Only a card's own change animates (LabSDOwnCardAnimation); nothing else does.
            layer.transaction { $0.animation = nil }
        }
    }

    @ViewBuilder
    private func cardView(_ card: LabSDLayout.Card) -> some View {
        let top = max(card.minY - scroll.offset, 0)
        let bottom = min(card.minY + card.height - scroll.offset, scroll.viewport)
        if bottom - top > SpacingTokens.micro {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: bottom - top)
                .workspaceCard()
                .offset(y: top)
        }
    }
}

/// N1 and N2: a card animates when its own top or height changes, never because the view scrolled.
struct LabSDOwnCardAnimation: ViewModifier {
    let isOn: Bool
    let motion: EchoMotion
    let minY: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        if isOn {
            content.animation(motion.settle, value: [minY, height])
        } else {
            content
        }
    }
}

/// Behind a pinned name and dock: once rows scroll under it, a light wash of the card colour,
/// strongest at the top (Echo's `ExplorerPinnedHeaderWash`).
struct LabSDHeaderWash: View {
    let restingMinY: CGFloat
    let scroll: LabSDScroll

    private var isPinned: Bool { scroll.offset > restingMinY + SpacingTokens.micro }

    var body: some View {
        LinearGradient(stops: [
            .init(color: ColorTokens.Workspace.card.opacity(0.85), location: 0),
            .init(color: ColorTokens.Workspace.card.opacity(0.45), location: 0.55),
            .init(color: ColorTokens.Workspace.card.opacity(0), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .opacity(isPinned ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: isPinned)
        .allowsHitTesting(false)
    }
}

/// A row under a pinned header blurs and fades more the higher it goes (Echo's `ExplorerRowEdgeBlur`).
struct LabSDRowEdgeBlur: ViewModifier {
    let headerHeight: CGFloat

    func body(content: Content) -> some View {
        if headerHeight > 0 {
            content.visualEffect { [headerHeight] effect, proxy in
                let midY = proxy.frame(in: .scrollView).midY
                let progress = min(max((headerHeight - midY) / headerHeight, 0), 1)
                return effect.blur(radius: progress * 10).opacity(1 - pow(progress, 0.8) * 0.92)
            }
        } else {
            content
        }
    }
}
