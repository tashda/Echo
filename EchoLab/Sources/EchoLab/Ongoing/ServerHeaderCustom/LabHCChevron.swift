import SwiftUI

/// The collapse control in one of round 53's designs. `color` is the header's type colour.
struct LabHCChevronView: View {
    let kind: LabHCChevron
    let isOpen: Bool
    let isHovering: Bool
    let motion: LabHCMotion
    let shows: LabHCChevronShows
    let color: Color
    var count = 0

    var body: some View {
        control
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.18), value: isHovering)
    }

    private var opacity: Double {
        switch shows {
        case .hover: isHovering || !isOpen ? 1 : 0
        case .always: isHovering ? 1 : 0.7
        case .collapsed: isOpen ? 0 : 1
        case .hoverOnly: isHovering ? 1 : 0
        }
    }

    private var chevronFont: Font { SidebarRowConstants.sectionChevronFont }

    @ViewBuilder
    private var control: some View {
        switch kind {
        case .today:
            Image(systemName: "chevron.down").font(chevronFont).foregroundStyle(color.opacity(0.85))
                .frame(width: SpacingTokens.md)
        case .turn:
            Image(systemName: "chevron.right").font(chevronFont).foregroundStyle(color.opacity(0.9))
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .animation(motion.animation, value: isOpen)
                .frame(width: SpacingTokens.md)
        case .disc:
            Image(systemName: "chevron.right").font(chevronFont).foregroundStyle(color)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .frame(width: SpacingTokens.lg - SpacingTokens.xxxs, height: SpacingTokens.lg - SpacingTokens.xxxs)
                .background(color.opacity(0.2), in: Circle())
                .scaleEffect(isHovering ? 1.12 : 1)
                .animation(motion.animation, value: isOpen)
                .animation(.smooth(duration: 0.2), value: isHovering)
        case .flip:
            LabHCFlipChevron(progress: isOpen ? 0 : 1)
                .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: SpacingTokens.md, height: SpacingTokens.sm)
                .animation(motion.animation, value: isOpen)
        case .label:
            HStack(spacing: SpacingTokens.xxxs) {
                Text(isOpen ? "Collapse" : "Expand").font(.system(size: 10.5, weight: .semibold))
                    .contentTransition(.interpolate)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).rotationEffect(.degrees(isOpen ? 90 : 0))
            }
            .foregroundStyle(color)
            .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
            .background(color.opacity(0.18), in: Capsule())
            .animation(motion.animation, value: isOpen)
        case .handle:
            EmptyView()
        case .symbol:
            Image(systemName: isOpen ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(color.opacity(0.9))
                .contentTransition(.symbolEffect(.replace))
                .animation(motion.animation, value: isOpen)
                .frame(width: SpacingTokens.md1)
        case .nudge:
            Image(systemName: "chevron.down").font(chevronFont).foregroundStyle(color.opacity(0.9))
                .rotationEffect(.degrees(isOpen ? 0 : -90))
                .phaseAnimator(isHovering && isOpen ? [0.0, 2.5] : [0.0], content: { view, offset in
                    view.offset(y: offset)
                }, animation: { _ in .easeInOut(duration: 0.45) })
                .animation(motion.animation, value: isOpen)
                .frame(width: SpacingTokens.md)
        case .count:
            HStack(spacing: SpacingTokens.xxs) {
                if !isOpen {
                    Text("\(count)").font(.system(size: 10.5, weight: .semibold)).monospacedDigit().foregroundStyle(color)
                        .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                        .background(color.opacity(0.2), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
                Image(systemName: "chevron.right").font(chevronFont).foregroundStyle(color.opacity(0.9))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
            }
            .animation(motion.animation, value: isOpen)
        }
    }
}

/// An up-pointing chevron that flattens into a line and comes out pointing down: `progress` 0 is
/// open (up), 1 is collapsed (down).
struct LabHCFlipChevron: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amplitude = rect.height * 0.5 * (1 - 2 * progress)
        let left = CGPoint(x: rect.minX, y: rect.midY + amplitude / 2)
        let apex = CGPoint(x: rect.midX, y: rect.midY - amplitude / 2)
        let right = CGPoint(x: rect.maxX, y: rect.midY + amplitude / 2)
        var path = Path()
        path.move(to: left)
        path.addLine(to: apex)
        path.addLine(to: right)
        return path
    }
}

/// CH5: a handle on the banner's bottom edge. It widens under the pointer and squashes on a click.
struct LabHCHandle: View {
    let isOpen: Bool
    let isHovering: Bool
    let motion: LabHCMotion
    let color: Color

    var body: some View {
        Capsule()
            .fill(color.opacity(isHovering ? 0.85 : 0.5))
            .frame(width: isHovering ? SpacingTokens.xl2 : SpacingTokens.lg + SpacingTokens.xxs, height: SpacingTokens.xxs)
            .scaleEffect(x: 1, y: isOpen ? 1 : 0.6)
            .animation(motion.animation, value: isOpen)
            .animation(.smooth(duration: 0.2), value: isHovering)
            .padding(.bottom, SpacingTokens.xxs)
    }
}
