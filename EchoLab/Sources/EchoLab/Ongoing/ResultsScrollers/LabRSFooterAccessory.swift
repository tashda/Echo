import SwiftUI

/// Round 27, options F and G: what sits in the footer instead of the system's horizontal bar.
struct LabRSFooterAccessory: View {
    let placement: LabRSPlacement
    let scroll: LabRSScroll

    var body: some View {
        switch placement {
        case .glassTrack: track
        case .positionChip: chip
        default: EmptyView()
        }
    }

    /// F: a capsule the height of the footer's chips; the thumb is the visible part of the width.
    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let inset = SpacingTokens.xxs
            let usable = max(width - inset * 2, 0)
            let thumb = max(usable * scroll.visibleFraction, LayoutTokens.Footer.chipHeight)
            let x = inset + (usable - thumb) * scroll.position
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ColorTokens.Text.primary.opacity(0.28))
                    .frame(width: thumb, height: LayoutTokens.Footer.chipHeight - inset * 3)
                    .offset(x: x)
            }
            .frame(width: width, height: LayoutTokens.Footer.chipHeight, alignment: .leading)
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let travel = max(usable - thumb, 1)
                scroll.scrollTo((value.location.x - inset - thumb / 2) / travel)
            })
        }
        .frame(height: LayoutTokens.Footer.chipHeight)
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel("Columns \(scroll.firstColumn) to \(scroll.lastColumn) of \(scroll.columnCount)")
    }

    /// G: which columns are in view.
    private var chip: some View {
        Text("Columns \(scroll.firstColumn)–\(scroll.lastColumn) of \(scroll.columnCount)")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .monospacedDigit()
            .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
            .frame(height: LayoutTokens.Footer.chipHeight)
            .glassEffect(.regular, in: .capsule)
    }
}
