import SwiftUI

/// The gutter's Column (GT1) and Hairline (round 28.2) surfaces, drawn behind the editor across
/// the card's full height and from its left edge, so the card's rounded corners cut them. The
/// gutter view is transparent and the text view starts where the surface ends. Subtle has no
/// surface; the lane is still drawn by the gutter (round 28.14 decides its look).
struct EditorGutterSurface: View {
    let style: EditorGutterStyle
    /// From the card's left edge to where the text begins.
    let width: CGFloat
    let fill: Color

    var body: some View {
        switch style {
        case .tinted:
            Rectangle().fill(fill)
                .frame(width: width)
                .overlay(alignment: .trailing) { edge }
        case .hairline:
            Color.clear.frame(width: width)
                .overlay(alignment: .trailing) { edge }
        case .subtle, .lane:
            EmptyView()
        }
    }

    private var edge: some View {
        Rectangle().fill(ColorTokens.Separator.primary).frame(width: LayoutTokens.EditorGutter.edgeWidth)
    }
}
