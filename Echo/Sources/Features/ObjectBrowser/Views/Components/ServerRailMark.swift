import SwiftUI

/// What one server looks like in the trail, the connection list and the connection sheet
/// (round 51, TI0): its two letters, or the symbol or emoji the user chose in their place, in the
/// same position and size. The drawing exists once so the three places cannot disagree.
struct ServerRailMark: View {
    let monogram: String
    let glyph: ServerRailGlyph?
    /// The server's colour: a chosen symbol is always drawn in it.
    let color: Color
    /// The letters' colour; the server's colour when nil.
    var letterColor: Color?
    var weight: Font.Weight = .semibold
    let size: CGFloat

    var body: some View {
        content
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var content: some View {
        switch glyph {
        case .symbol(let name)?:
            Image(systemName: name)
                .font(.system(size: size * LayoutTokens.Rail.glyphSymbolRatio, weight: .semibold))
                .foregroundStyle(color)
        case .emoji(let value)?:
            Text(value)
                .font(.system(size: size * LayoutTokens.Rail.glyphEmojiRatio))
        case nil:
            Text(monogram)
                .font(.system(size: size * LayoutTokens.Rail.monogramFontRatio, weight: weight, design: .rounded))
                .foregroundStyle(letterColor ?? color)
        }
    }
}
