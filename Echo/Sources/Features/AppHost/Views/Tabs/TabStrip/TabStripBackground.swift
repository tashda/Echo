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
            let color = scheme == .dark ? Color(white: 0.22) : Color(white: 0.90)
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
        LinearGradient(colors: [Color.white.opacity(0.16), Color.black.opacity(0.14)], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

struct SafariTabBarTopEdge: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.45))
            .frame(height: tabHairlineWidth())
    }
}
#else
struct TabStripBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(white: 0.92))
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
