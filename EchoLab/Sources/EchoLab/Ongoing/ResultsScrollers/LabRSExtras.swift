import SwiftUI

/// Round 27, X1 to X4: what ties the position to the card besides the bar.
struct LabRSExtras: View {
    let extra: LabRSExtra
    let scroll: LabRSScroll
    let size: CGSize
    let footerZone: CGFloat
    /// How far the footer is lifted beyond Echo's 4pt (D lifts it by the bar's lane).
    var footerLift: CGFloat = 0
    /// The footer's free gap, for the column map; nil when the gap is taken.
    let footerGap: (left: CGFloat, right: CGFloat)?

    var body: some View {
        switch extra {
        case .none: EmptyView()
        case .edgeFades: edgeFades
        case .footerLine: positionLine(atY: size.height - footerZone)
        case .columnMap: columnMap
        case .headerLine: positionLine(atY: scroll.headerHeight)
        }
    }

    /// X1: the rows fade at a side where more columns wait.
    private var edgeFades: some View {
        let width = SpacingTokens.xl
        let rows = max(size.height - scroll.headerHeight - footerZone, 0)
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [ColorTokens.Workspace.card, ColorTokens.Workspace.card.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: rows)
                .opacity(scroll.position > 0.005 ? 1 : 0)
            LinearGradient(colors: [ColorTokens.Workspace.card.opacity(0), ColorTokens.Workspace.card], startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: rows)
                .offset(x: size.width - width)
                .opacity(scroll.position < 0.995 && scroll.visibleFraction < 1 ? 1 : 0)
        }
        .offset(y: scroll.headerHeight)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.2), value: scroll.position > 0.005)
        .animation(.easeOut(duration: 0.2), value: scroll.position < 0.995)
        .allowsHitTesting(false)
    }

    /// X2 and X4: a 2pt line showing the visible part of the width.
    private func positionLine(atY y: CGFloat) -> some View {
        let length = max(size.width * scroll.visibleFraction, SpacingTokens.lg)
        return Capsule()
            .fill(ColorTokens.accent.opacity(0.7))
            .frame(width: length, height: SpacingTokens.xxxs)
            .offset(x: (size.width - length) * scroll.position, y: y - SpacingTokens.xxxs / 2)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .allowsHitTesting(false)
    }

    /// X3: one tick per column in the footer's gap, the visible ones lit; click one to jump there.
    @ViewBuilder
    private var columnMap: some View {
        if let gap = footerGap, scroll.columnCount > 1 {
            let width = max(size.width - gap.left - gap.right, 0)
            let count = scroll.columnCount
            Canvas { context, canvas in
                let step = canvas.width / CGFloat(count)
                let gap = min(SpacingTokens.xxxs, step / 3)
                for column in 1...count {
                    let rect = CGRect(x: CGFloat(column - 1) * step, y: (canvas.height - SpacingTokens.xs) / 2,
                                      width: max(step - gap, 1), height: SpacingTokens.xs)
                    let isVisible = column >= scroll.firstColumn && column <= scroll.lastColumn
                    context.fill(Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2),
                                 with: .color(isVisible ? ColorTokens.accent.opacity(0.8) : ColorTokens.Text.quaternary))
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                let inner = max(width - SpacingTokens.xs * 2, 1)
                let column = min(max(Int(value.location.x / inner * CGFloat(count)), 0), count - 1)
                scroll.scrollTo(CGFloat(column) / CGFloat(max(count - 1, 1)))
            })
            .padding(.horizontal, SpacingTokens.xs)
            .frame(width: width, height: LayoutTokens.Footer.chipHeight)
            .glassEffect(.regular, in: .capsule)
            .frame(width: width)
            .offset(x: gap.left, y: size.height - LayoutTokens.Footer.bottomLift - footerLift - LayoutTokens.Footer.height / 2 - LayoutTokens.Footer.chipHeight / 2)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }
}
