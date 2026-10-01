import SwiftUI

/// Round 27: both bars in a drawn style (S2 to S6), placed and shown as the options say.
struct LabRSDrawnBars: View {
    let options: LabRSOptionSet
    let scroll: LabRSScroll
    let size: CGSize
    let cornerRadius: CGFloat

    @State private var isDragging = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let frame = options.horizontalFrame(cornerRadius: cornerRadius, chips: LabRSCard.chips) {
                let length = max(size.width - frame.left - frame.right, 0)
                LabRSBarBacking(behind: options.behind, length: length, lane: options.lane)
                    .offset(x: frame.left, y: size.height - frame.bottom - options.lane)
                LabRSDrawnBar(axis: .horizontal, style: options.style, length: length,
                              visibleFraction: scroll.visibleFraction, position: scroll.position,
                              isNear: isNear(y: size.height - frame.bottom - options.lane / 2),
                              showsTrack: options.track == .faint,
                              onScroll: scroll.scrollTo)
                    .offset(x: frame.left, y: size.height - frame.bottom - options.lane)
            }
            if let bottom = options.verticalBottom(cornerRadius: cornerRadius, chips: LabRSCard.chips) {
                let top = scroll.headerHeight + SpacingTokens.xxxs
                let length = max(size.height - bottom - top, 0)
                LabRSDrawnBar(axis: .vertical, style: options.style, length: length,
                              visibleFraction: scroll.verticalVisibleFraction, position: scroll.verticalPosition,
                              isNear: isNear(x: size.width - options.lane / 2),
                              showsTrack: options.track == .faint,
                              onScroll: scroll.scrollVerticallyTo)
                    .offset(x: size.width - options.lane, y: top)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .opacity(isShown ? 1 : 0)
        .animation(.easeOut(duration: isShown ? 0.12 : 0.4), value: isShown)
        .allowsHitTesting(isShown)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in isDragging = true }.onEnded { _ in isDragging = false })
    }

    private var isShown: Bool {
        if options.holdsBars { return true }
        return switch options.visibility {
        case .always: true
        case .whileScrolling: scroll.isScrolling || isDragging
        case .overGrid: scroll.pointer != nil || isDragging
        case .nearBottom:
            isDragging || scroll.pointer.map { $0.y > size.height - options.footerZone - options.lane - SpacingTokens.lg
                || $0.x > size.width - options.lane - SpacingTokens.lg } ?? false
        }
    }

    private func isNear(y: CGFloat) -> Bool {
        scroll.pointer.map { abs($0.y - y) < options.lane + SpacingTokens.xs } ?? false
    }

    private func isNear(x: CGFloat) -> Bool {
        scroll.pointer.map { abs($0.x - x) < options.lane + SpacingTokens.xs } ?? false
    }
}

/// Round 27, U3 and U4: what sits behind the horizontal bar while it shows.
struct LabRSBarBacking: View {
    let behind: LabRSBehind
    let length: CGFloat
    let lane: CGFloat

    var body: some View {
        switch behind {
        case .glassLane:
            Capsule()
                .fill(.clear)
                .frame(width: length, height: lane)
                .glassEffect(.regular, in: .capsule)
        case .softBand:
            // The card's colour, solid around the bar and fading out above it.
            LinearGradient(stops: [.init(color: ColorTokens.Workspace.card.opacity(0), location: 0),
                                   .init(color: ColorTokens.Workspace.card.opacity(0.9), location: 0.45),
                                   .init(color: ColorTokens.Workspace.card.opacity(0.9), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: length + SpacingTokens.md * 2, height: lane + SpacingTokens.md)
                .offset(x: -SpacingTokens.md, y: -SpacingTokens.md / 2)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }
}
