import SwiftUI

/// Round 19, S3: a switching card's rows are covered by a veil in the card's own colour, which
/// fades in (the rows seem to fade out), stays while the new section swaps in underneath, and
/// fades out again (the new rows seem to fade in). One layer animates instead of every row, so
/// the switch costs the main thread almost nothing per frame.
struct ExplorerTreeVeilLayer: View {
    struct Veil: Identifiable {
        let id: UUID
        /// The card's rows, in the tree's coordinates: below the header, to the card's bottom.
        let bodyTop: CGFloat
        let bodyBottom: CGFloat
        let headerHeight: CGFloat
        let isOpaque: Bool
    }

    let veils: [Veil]
    let scroll: ExplorerTreeScrollState
    let cornerRadius: CGFloat

    var body: some View {
        let offset = scroll.offset
        let viewport = scroll.viewportHeight
        ZStack(alignment: .top) {
            ForEach(veils) { veil in
                // A pinned header sits at the top of the view, so the rows start below it.
                let top = max(veil.bodyTop - offset, veil.headerHeight)
                let bottom = min(veil.bodyBottom - offset, viewport)
                if bottom - top > SpacingTokens.micro {
                    UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, style: .continuous)
                        .fill(ColorTokens.Workspace.card)
                        // Inside the card's edge line, so the edge stays visible.
                        .padding(.horizontal, LayoutTokens.Workspace.cardEdgeWidth)
                        .padding(.bottom, LayoutTokens.Workspace.cardEdgeWidth)
                        .frame(height: bottom - top)
                        .offset(y: top)
                        .opacity(veil.isOpaque ? 1 : 0)
                        // Appearing, it fades in with the switch's fade-out animation.
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension ExplorerTreeLayout {
    /// A veil for every switching server's card body.
    func veils(switching: Set<UUID>, opaque: Set<UUID>) -> [ExplorerTreeVeilLayer.Veil] {
        guard !switching.isEmpty else { return [] }
        return groups.compactMap { group in
            guard let serverRow = group.header.first, let connectionID = serverRow.node.row.connectionID,
                  switching.contains(connectionID),
                  let card = cards.first(where: { $0.id == serverRow.id })
            else { return nil }
            let headerHeight = group.header.reduce(0) { $0 + $1.height }
            return .init(id: connectionID, bodyTop: serverRow.minY + headerHeight, bodyBottom: card.minY + card.height,
                         headerHeight: headerHeight, isOpaque: opaque.contains(connectionID))
        }
    }
}
