import SwiftUI

/// A server's monogram in the rail: secondary grey, or bold in the server's own colour when
/// selected. With Server Header Color set to the server's colour it is always in that colour,
/// bold when selected (round 30.1, CO1). A connecting server breathes; a lost one is dimmed.
struct ServerRailItem: View {
    let monogram: String
    /// The symbol or emoji the user chose, drawn in place of the monogram (round 51, TI0).
    var glyph: ServerRailGlyph?
    let color: Color
    let status: ServerRailStatus
    let isSelected: Bool
    let size: CGFloat
    var isAlwaysColored = false
    /// The server's card is minimized: the mark takes a dashed ring (round 51, SH5).
    var isMinimized = false

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    var body: some View {
        ServerRailMark(
            monogram: monogram,
            glyph: glyph,
            color: color,
            letterColor: foreground,
            weight: isSelected ? .bold : .semibold,
            size: size
        )
        .overlay {
            if isMinimized {
                Circle()
                    .strokeBorder(
                        color,
                        style: StrokeStyle(lineWidth: LayoutTokens.Rail.minimizedRingWidth, dash: LayoutTokens.Rail.minimizedRingDash)
                    )
                    .padding(SpacingTokens.micro)
            }
        }
        .opacity(isMinimized ? LayoutTokens.Rail.minimizedOpacity : 1)
        .opacity(status == .failed ? LayoutTokens.Rail.lostOpacity : 1)
        .modifier(ServerRailBreathing(isActive: status == .connecting))
        .contentShape(Circle())
        .onHover { isHovering = $0 }
        .animation(motion.hover, value: isHovering)
        .animation(motion.press, value: isSelected)
        .animation(motion.standard, value: status)
        .animation(motion.standard, value: isMinimized)
    }

    private var foreground: Color {
        if isSelected || isAlwaysColored { return color }
        return isHovering ? ColorTokens.Text.primary : ColorTokens.Text.secondary
    }
}

/// Fades a connecting server in and out, dipping slightly in size, until it connects
/// (Design/06-tokens.md). With Reduce Motion it is shown still and dimmed instead.
struct ServerRailBreathing: ViewModifier {
    let isActive: Bool

    @Environment(\.echoMotion) private var motion

    func body(content: Content) -> some View {
        if !isActive {
            content
        } else if !motion.allowsLoopingEffects {
            content.opacity(LayoutTokens.Rail.lostOpacity)
        } else {
            let halfPeriod = motion.pulseHalfPeriod
            content.phaseAnimator([false, true]) { view, isDimmed in
                view
                    .opacity(isDimmed ? EchoMotion.pulseMinimumOpacity : 1)
                    .scaleEffect(isDimmed ? EchoMotion.pulseMinimumScale : 1)
            } animation: { _ in
                .easeInOut(duration: halfPeriod)
            }
        }
    }
}

/// A tool button's symbol in the rail's bottom pill.
struct ServerRailToolLabel: View {
    let symbol: String
    let isSelected: Bool
    let width: CGFloat
    var height: CGFloat = LayoutTokens.Rail.toolHeight

    @Environment(\.echoMotion) private var motion
    @State private var isHovering = false

    var body: some View {
        Image(systemName: symbol)
            .symbolVariant(isSelected ? .fill : .none)
            .font(.system(size: LayoutTokens.Rail.toolSymbolSize))
            .foregroundStyle(foreground)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(motion.hover, value: isHovering)
            .animation(motion.press, value: isSelected)
    }

    private var foreground: Color {
        if isSelected { return .accentColor }
        return isHovering ? ColorTokens.Text.primary : ColorTokens.Text.secondary
    }
}
