import SwiftUI

/// One switching card's veil: the card's rows, in the tree's coordinates, below the header to
/// the card's bottom.
public struct ExplorerTreeVeil: Identifiable, Sendable {
    public let id: UUID
    public let bodyTop: CGFloat
    public let bodyBottom: CGFloat
    public let headerHeight: CGFloat
    public let isOpaque: Bool

    public init(id: UUID, bodyTop: CGFloat, bodyBottom: CGFloat, headerHeight: CGFloat, isOpaque: Bool) {
        self.id = id
        self.bodyTop = bodyTop
        self.bodyBottom = bodyBottom
        self.headerHeight = headerHeight
        self.isOpaque = isOpaque
    }
}

/// Round 19, S3: a switching card's rows are covered by a veil in the card's own colour, which
/// fades in (the rows seem to fade out), stays while the new section swaps in underneath, and
/// fades out again (the new rows seem to fade in). One layer animates instead of every row, so
/// the switch costs the main thread almost nothing per frame.
public struct ExplorerTreeVeilLayer: View {
    let veils: [ExplorerTreeVeil]
    let scroll: ExplorerTreeScrollState
    let cornerRadius: CGFloat

    public init(veils: [ExplorerTreeVeil], scroll: ExplorerTreeScrollState, cornerRadius: CGFloat) {
        self.veils = veils
        self.scroll = scroll
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
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
