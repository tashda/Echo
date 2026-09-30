import SwiftUI

/// The part of a card that shows while it grows or folds: a rounded rectangle `visibleHeight` tall,
/// hanging from the top edge or rising from the bottom one. It's animatable, so a card can open by
/// changing only its clip, with the content laid out once at its final size.
struct CardRevealShape: InsettableShape {
    var visibleHeight: CGFloat
    let cornerRadius: CGFloat
    let anchor: VerticalEdge
    /// False for content that brings cards of its own: cut only at the moving edge, leaving room
    /// for their shadows everywhere else.
    var roundsCorners = true
    var insetAmount: CGFloat = 0

    var animatableData: CGFloat {
        get { visibleHeight }
        set { visibleHeight = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let height = min(max(visibleHeight, 0), rect.height)
        guard height > 0 else { return Path() }
        let visible = CGRect(
            x: rect.minX,
            y: anchor == .top ? rect.minY : rect.maxY - height,
            width: rect.width,
            height: height
        )
        guard roundsCorners else {
            let allowance = ShadowTokens.workspaceCard.radius * 2
            var open = visible.insetBy(dx: -allowance, dy: 0)
            if anchor == .top { open.origin.y -= allowance }
            open.size.height += allowance
            return Path(open)
        }
        let inset = visible.insetBy(dx: insetAmount, dy: insetAmount)
        return RoundedRectangle(cornerRadius: max(cornerRadius - insetAmount, 0), style: .continuous).path(in: inset)
    }

    func inset(by amount: CGFloat) -> CardRevealShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// A workspace card that shows only its `visibleHeight` (plan RS2, smooth). The content keeps the
/// size it was laid out at, so the editor and the grid don't lay out again on every frame; the
/// clip, fill, shadow and edge follow the visible part.
struct RevealedWorkspaceCardModifier: ViewModifier {
    let visibleHeight: CGFloat
    let anchor: VerticalEdge
    var chromeOpacity: Double = 1
    var clipsContent = true

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    func body(content: Content) -> some View {
        let shape = CardRevealShape(visibleHeight: visibleHeight, cornerRadius: cornerRadius, anchor: anchor)
        content
            .clipShape(CardRevealShape(
                visibleHeight: visibleHeight,
                cornerRadius: cornerRadius,
                anchor: anchor,
                roundsCorners: clipsContent
            ))
            .background {
                shape
                    .fill(ColorTokens.Workspace.card)
                    .shadow(ShadowTokens.workspaceCard)
                    .opacity(chromeOpacity)
            }
            .overlay {
                shape.strokeBorder(
                    ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity),
                    lineWidth: LayoutTokens.Workspace.cardEdgeWidth
                )
                .opacity(chromeOpacity)
                .allowsHitTesting(false)
            }
            .preference(key: ContainsWorkspaceCardKey.self, value: true)
    }
}
