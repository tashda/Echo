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
                LabRSDrawnBar(axis: .horizontal, style: options.style, length: length,
                              visibleFraction: scroll.visibleFraction, position: scroll.position,
                              isNear: isNear(y: size.height - frame.bottom - options.lane / 2),
                              onScroll: scroll.scrollTo)
                    .offset(x: frame.left, y: size.height - frame.bottom - options.lane)
            }
            if let bottom = options.verticalBottom(cornerRadius: cornerRadius, chips: LabRSCard.chips) {
                let top = scroll.headerHeight + SpacingTokens.xxxs
                let length = max(size.height - bottom - top, 0)
                LabRSDrawnBar(axis: .vertical, style: options.style, length: length,
                              visibleFraction: scroll.verticalVisibleFraction, position: scroll.verticalPosition,
                              isNear: isNear(x: size.width - options.lane / 2),
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
        switch options.visibility {
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
