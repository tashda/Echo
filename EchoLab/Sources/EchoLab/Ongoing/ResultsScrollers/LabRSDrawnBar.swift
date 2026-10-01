import SwiftUI

/// Round 27: one bar drawn in a style other than the system's (S2 to S6). It sits in a lane
/// `length` long; the thumb shows the visible part at `position`, and dragging it scrolls.
struct LabRSDrawnBar: View {
    enum Axis { case horizontal, vertical }

    let axis: Axis
    let style: LabRSBarStyle
    let length: CGFloat
    let visibleFraction: CGFloat
    let position: CGFloat
    let isNear: Bool
    /// T2: a faint track along the whole length while the bar shows.
    var showsTrack = false
    let onScroll: (CGFloat) -> Void

    private var thickness: CGFloat { isNear ? style.hoverThickness : style.thickness }
    private var thumbLength: CGFloat { max(length * visibleFraction, LayoutTokens.Footer.chipHeight) }
    private var travel: CGFloat { max(length - thumbLength, 1) }

    var body: some View {
        ZStack(alignment: axis == .horizontal ? .leading : .top) {
            track
            thumb
                .frame(width: axis == .horizontal ? thumbLength : thumbThickness,
                       height: axis == .horizontal ? thumbThickness : thumbLength)
                .offset(x: axis == .horizontal ? travel * position : 0, y: axis == .vertical ? travel * position : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: axis == .horizontal ? .leading : .top)
        }
        .frame(width: axis == .horizontal ? length : style.lane, height: axis == .horizontal ? style.lane : length)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            let along = axis == .horizontal ? value.location.x : value.location.y
            onScroll((along - thumbLength / 2) / travel)
        })
        .animation(.easeOut(duration: 0.12), value: isNear)
    }

    /// The glass track holds its thumb inside; the others are as thick as they look.
    private var thumbThickness: CGFloat { style == .glass ? thickness - SpacingTokens.xxs * 2 : thickness }

    @ViewBuilder
    private var track: some View {
        switch style {
        case .glass:
            Capsule()
                .fill(.clear)
                .frame(width: axis == .horizontal ? length : thickness, height: axis == .horizontal ? thickness : length)
                .glassEffect(.regular, in: .capsule)
        case .system where isNear || showsTrack:
            // The overlay bar shows its track only while the pointer is on it.
            Capsule()
                .fill(ColorTokens.Sidebar.hoverFill)
                .frame(width: axis == .horizontal ? length : thickness + SpacingTokens.xxs, height: axis == .horizontal ? thickness + SpacingTokens.xxs : length)
        case .groove:
            Capsule()
                .fill(ColorTokens.Sidebar.hoverFill)
                .frame(width: axis == .horizontal ? length : thickness, height: axis == .horizontal ? thickness : length)
        default:
            Color.clear
        }
    }

    private var thumb: some View {
        Capsule().fill(thumbColor).padding(style == .glass ? SpacingTokens.xxs : 0)
    }

    private var thumbColor: Color {
        switch style {
        case .system: ColorTokens.Text.secondary.opacity(0.75)
        case .thinLine: ColorTokens.Text.tertiary
        case .softCapsule: ColorTokens.Text.primary.opacity(0.25)
        case .accent: ColorTokens.accent.opacity(0.75)
        case .glass: ColorTokens.Text.primary.opacity(0.45)
        case .groove: ColorTokens.Text.secondary.opacity(0.6)
        }
    }
}
