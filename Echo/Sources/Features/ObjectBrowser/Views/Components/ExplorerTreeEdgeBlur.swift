import SwiftUI

/// The blur under the pinned card header (Design/05-components.md › Explorer tree).
///
/// On macOS, SwiftUI materials and in-window visual effect views over the tree's rows only tint
/// or fade them. So the rows and card fills under the header band are drawn again here, in a few
/// copies whose blur grows toward the top edge. The smallest blur reaches the bottom of the band,
/// where it meets the real rows without a seam, and a light card tint keeps the header readable.
///
/// It reads the scroll offset, like the cards layer, so scrolling never re-renders the list.
struct ExplorerTreeEdgeBlur: View {
    let layout: ExplorerTreeLayout
    let scroll: ExplorerTreeScrollState
    let expandedNodeIDs: Set<String>
    let baseRowHeight: CGFloat
    /// Height of the pinned header; the band is this plus the fade below it.
    let headerHeight: CGFloat
    let rowContent: (ObjectBrowserNode, Bool, Int, CGFloat, @escaping () -> Void) -> AnyView

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    private var bandHeight: CGFloat { headerHeight + LayoutTokens.Workspace.pinnedHeaderFade }

    var body: some View {
        let offset = scroll.offset
        let isPinned = layout.topVisibleContext(atOffset: offset, baseRowHeight: baseRowHeight)?
            .isScrolledPastServerHeader ?? false

        ZStack(alignment: .top) {
            if isPinned {
                blurredBand(offset: offset)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.22), value: isPinned)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func blurredBand(offset: CGFloat) -> some View {
        let radii = LayoutTokens.Workspace.pinnedHeaderBlurRadii
        let reach = (radii.last ?? 0) * 2
        let rows = layout.rows.filter { $0.minY + $0.height > offset - reach && $0.minY < offset + bandHeight + reach }
        let cards = layout.cards.filter { $0.minY + $0.height > offset - reach && $0.minY < offset + bandHeight + reach }
        let count = CGFloat(radii.count)

        return ZStack(alignment: .top) {
            ForEach(Array(radii.enumerated()), id: \.offset) { index, radius in
                // Each stronger blur stops higher up, so the blur grows toward the top edge.
                let end = 1 - CGFloat(index) / count
                snapshot(rows: rows, cards: cards, offset: offset)
                    .blur(radius: radius, opaque: false)
                    .mask(Self.band(solidUntil: max(end - LayoutTokens.Workspace.pinnedHeaderBlurStep, 0), clearAt: end))
            }
            ColorTokens.Workspace.card
                .opacity(LayoutTokens.Workspace.pinnedHeaderTintOpacity)
                .mask(Self.band(solidUntil: headerHeight / bandHeight * 0.6, clearAt: 1))
        }
        .frame(height: bandHeight, alignment: .top)
        .clipped()
    }

    /// The card fills and rows around the band, placed where they sit in the scroll view. Drawn
    /// past the band's edges so the blur has real content to pull in at the top and bottom.
    private func snapshot(rows: [ExplorerTreeLayout.Row], cards: [ExplorerTreeLayout.Card], offset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ForEach(cards) { card in
                // Cut to the area around the band, keeping the card's own corners where they show.
                let reach = (LayoutTokens.Workspace.pinnedHeaderBlurRadii.last ?? 0) * 2
                let top = max(card.minY, offset - reach)
                let bottom = min(card.minY + card.height, offset + bandHeight + reach)
                let topRadius = top == card.minY ? cornerRadius : 0
                let bottomRadius = bottom == card.minY + card.height ? cornerRadius : 0
                UnevenRoundedRectangle(
                    topLeadingRadius: topRadius,
                    bottomLeadingRadius: bottomRadius,
                    bottomTrailingRadius: bottomRadius,
                    topTrailingRadius: topRadius,
                    style: .continuous
                )
                .fill(ColorTokens.Workspace.card)
                .frame(maxWidth: .infinity)
                .frame(height: max(bottom - top, 0))
                .offset(y: top - offset)
            }
            ForEach(rows) { row in
                rowContent(row.node, expandedNodeIDs.contains(row.node.id), row.depth, 0, {})
                    .frame(maxWidth: .infinity)
                    .frame(height: row.height)
                    .offset(y: row.minY - offset)
            }
        }
        // As wide as the real rows, which leave room for a scroll bar when it's always shown.
        .frame(width: scroll.contentWidth > 0 ? scroll.contentWidth : nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: bandHeight, alignment: .top)
    }

    private static func band(solidUntil start: CGFloat, clearAt end: CGFloat) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: start),
                .init(color: .clear, location: end),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
