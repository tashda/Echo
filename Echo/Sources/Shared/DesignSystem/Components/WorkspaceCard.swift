import SwiftUI

/// An opaque content card on the workspace canvas: 12pt continuous corners, a 0.5pt separator
/// edge and the floating shadow (Design/02-layout.md › Cards). Glass never goes on cards.
struct WorkspaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
        content
            .clipShape(shape)
            // The shadow is drawn by the fill behind the content, so AppKit-backed content
            // (the editor, the grid) is never rendered offscreen for it.
            .background {
                shape
                    .fill(ColorTokens.Workspace.card)
                    .shadow(ShadowTokens.workspaceCard)
            }
            .overlay {
                shape.strokeBorder(
                    ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity),
                    lineWidth: LayoutTokens.Workspace.cardEdgeWidth
                )
                .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Puts the view on an opaque workspace card.
    func workspaceCard() -> some View {
        modifier(WorkspaceCardModifier())
    }
}
