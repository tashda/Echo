import SwiftUI

/// The gutter's surfaces, drawn behind the editor across the card's full height and from its left
/// edge: the Column (GT1) and Hairline (round 28.2), cut by the card's corners, and the Lane
/// (round 28.14: the whole gutter, 5pt from the card's edges, corners concentric with the card's,
/// in the system's quiet fill). The gutter view is transparent; the text starts where it ends.
struct EditorGutterSurface: View {
    let style: EditorGutterStyle
    /// From the card's left edge to where the text begins.
    let width: CGFloat
    let fill: Color

    @Environment(\.workspaceCardCornerRadius) private var cardCornerRadius

    var body: some View {
        switch style {
        case .tinted:
            Rectangle().fill(fill)
                .frame(width: width)
                .overlay(alignment: .trailing) { edge }
        case .hairline:
            Color.clear.frame(width: width)
                .overlay(alignment: .trailing) { edge }
        case .lane:
            let inset = LayoutTokens.EditorGutter.laneInset
            RoundedRectangle(cornerRadius: max(cardCornerRadius - inset, SpacingTokens.xxs), style: .continuous)
                .fill(ColorTokens.Workspace.groupFill)
                .frame(width: max(width - inset * 2, 0))
                .padding(inset)
        case .subtle:
            EmptyView()
        }
    }

    private var edge: some View {
        Rectangle().fill(ColorTokens.Separator.primary).frame(width: LayoutTokens.EditorGutter.edgeWidth)
    }
}
