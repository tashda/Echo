import SwiftUI

/// One server's mark in the trail, in one of round 51's styles. `custom` is what the user set;
/// unset parts stay automatic.
struct LabTIMark: View {
    let server: LabTIServer
    let style: LabTIStyle
    var custom = LabTICustomisation()
    var isSelected = false
    /// The server's card is minimised and the trail shows that (SH5).
    var isRing = false
    var size: CGFloat = SpacingTokens.xl + SpacingTokens.nano - SpacingTokens.micro

    private var color: Color { custom.color ?? server.server.color }
    private var text: String { custom.text.isEmpty ? server.monogram : String(custom.text.prefix(2)).uppercased() }
    private var glyph: LabTIGlyph? { custom.glyph ?? (style == .glyph ? server.glyph : nil) }

    var body: some View {
        mark
            .frame(width: size, height: size)
            .overlay {
                if isRing {
                    Circle().strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).padding(micro)
                }
            }
            .opacity(isRing ? 0.7 : 1)
    }

    private var micro: CGFloat { SpacingTokens.micro }

    @ViewBuilder
    private var mark: some View {
        switch style {
        case .monogram:
            centre(foreground: isSelected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.85)), weight: isSelected ? .bold : .semibold)
        case .disc, .labelled:
            filled(color) { centre(foreground: AnyShapeStyle(ColorTokens.Text.onFill), weight: .bold) }
        case .tile:
            filled(color.opacity(0.2), stroke: color.opacity(0.4), defaultShape: .squircle) { centre(foreground: AnyShapeStyle(color), weight: .bold) }
        case .ring:
            (custom.shape ?? .circle).path(size: size).stroke(color, lineWidth: SpacingTokens.xxxs)
                .padding(SpacingTokens.xxxs * 1.5)
                .overlay { centre(foreground: AnyShapeStyle(ColorTokens.Text.primary), weight: .semibold) }
        case .engine:
            Image(systemName: server.engine)
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(color)
        case .glyph:
            filled(color.opacity(0.2), stroke: color.opacity(0.35)) { centre(foreground: AnyShapeStyle(color), weight: .bold) }
        case .bar:
            centre(foreground: isSelected ? AnyShapeStyle(color) : AnyShapeStyle(ColorTokens.Text.secondary), weight: isSelected ? .bold : .semibold)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: SpacingTokens.nano, height: size * 0.5).offset(x: -SpacingTokens.xxs1)
                }
        case .badge:
            (custom.shape ?? .squircle).path(size: size)
                .fill(ColorTokens.Text.primary.opacity(0.08))
                .padding(SpacingTokens.xxxs)
                .overlay { centre(foreground: AnyShapeStyle(ColorTokens.Text.primary), weight: .semibold) }
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(color)
                        .frame(width: size * 0.34, height: size * 0.34)
                        .overlay { Circle().strokeBorder(ColorTokens.Workspace.canvas, lineWidth: SpacingTokens.micro * 1.5) }
                        .overlay { Image(systemName: server.engine).font(.system(size: size * 0.17, weight: .bold)).foregroundStyle(ColorTokens.Text.onFill) }
                }
        }
    }

    private func filled<Content: View>(_ fill: Color, stroke: Color? = nil, defaultShape: LabTIShape = .circle,
                                       @ViewBuilder content: () -> Content) -> some View {
        let shape = (custom.shape ?? defaultShape).path(size: size)
        return shape.fill(fill)
            .overlay { if let stroke { shape.stroke(stroke, lineWidth: 0.5) } }
            .padding(SpacingTokens.xxxs)
            .overlay(content())
    }

    /// The letters, or the symbol or emoji the user chose, or the engine's symbol (TI4).
    @ViewBuilder
    private func centre(foreground: AnyShapeStyle, weight: Font.Weight) -> some View {
        switch glyph {
        case .symbol(let name)?:
            Image(systemName: name).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(foreground)
        case .emoji(let value)?:
            Text(value).font(.system(size: size * 0.46))
        case nil:
            Text(text)
                .font(.system(size: size * LayoutTokens.Rail.monogramFontRatio, weight: weight, design: .rounded))
                .foregroundStyle(foreground)
        }
    }
}
