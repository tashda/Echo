import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
struct TabStripBackground: View {
    enum Style {
        case standard(ColorScheme)
        case themed(TabChromePalette)
    }

    var style: Style
    var height: CGFloat = SpacingTokens.lg
    var cornerRadius: CGFloat = 15 // Design specific radius for tabs

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(baseFill)
            .overlay(topEdgeOverlay)
            .overlay(bottomEdgeOverlay)
            .frame(height: height)
            .allowsHitTesting(false)
    }

    private var baseFill: AnyShapeStyle {
        switch style {
        case .standard(let scheme):
            let color = scheme == .dark ? ColorTokens.TabStrip.Background.dark : ColorTokens.TabStrip.Background.light
            return AnyShapeStyle(color)
        case .themed(let palette):
            return AnyShapeStyle(palette.baseFill)
        }
    }

    @ViewBuilder
    private var topEdgeOverlay: some View {
        if case .themed(let palette) = style {
            shape.stroke(palette.baseStroke, lineWidth: tabHairlineWidth())
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomEdgeOverlay: some View {
        EmptyView()
    }
}

struct SafariTabBarBackground: View {
    var body: some View {
        LinearGradient(colors: [ColorTokens.TabStrip.SafariBar.gradientTop, ColorTokens.TabStrip.SafariBar.gradientBottom], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

struct SafariTabBarTopEdge: View {
    var body: some View {
        Rectangle()
            .fill(ColorTokens.TabStrip.SafariBar.topEdge)
            .frame(height: tabHairlineWidth())
    }
}
#else
struct TabStripBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(ColorTokens.TabStrip.Background.light)
            .allowsHitTesting(false)
    }
}

struct SafariTabBarBackground: View {
    var body: some View { Color.clear }
}

struct SafariTabBarTopEdge: View {
    var body: some View { Color.clear.frame(height: 0) }
}
#endif
