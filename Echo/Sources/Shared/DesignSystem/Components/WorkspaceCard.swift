import SwiftUI

extension EnvironmentValues {
    /// Corner radius of every workspace card, from the Card Corners setting.
    @Entry var workspaceCardCornerRadius: CGFloat = LayoutTokens.Workspace.cardCornerRadius
}

/// An opaque content card on the workspace canvas: continuous corners from the Card Corners setting, a 0.5pt separator
/// edge and the floating shadow (Design/02-layout.md › Cards). Glass never goes on cards.
struct WorkspaceCardModifier: ViewModifier {
    /// Fades the card's fill, shadow and edge (not its content), for a card dissolving into
    /// another, such as the results folding back into the footer.
    var chromeOpacity: Double = 1

    @Environment(\.workspaceCardCornerRadius) private var cornerRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .clipShape(shape)
            // The shadow is drawn by the fill behind the content, so AppKit-backed content
            // (the editor, the grid) is never rendered offscreen for it.
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
    }
}

extension View {
    /// Puts the view on an opaque workspace card.
    func workspaceCard() -> some View {
        modifier(WorkspaceCardModifier())
    }

    /// A workspace card whose fill, shadow and edge are faded to `chromeOpacity`.
    func workspaceCard(chromeOpacity: Double) -> some View {
        modifier(WorkspaceCardModifier(chromeOpacity: chromeOpacity))
    }
}
