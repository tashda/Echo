import SwiftUI

/// The section dock on the title banner (round 53, F5): the icons sit straight on the colour with
/// no capsule, no pill and no underline. The current one is the filled symbol, bold and in full
/// ink; the others are medium at 72%. Same slots, menus and More (») as the capsule dock.
struct ExplorerBannerDockRow: View {
    let connectionID: UUID
    let layout: ExplorerDockLayout
    let selectedID: String
    /// The header's type colour: white, or dark on a light colour.
    let ink: Color

    @Environment(\.sidebarDensity) private var density
    @Environment(\.explorerDockActions) private var actions
    @Environment(\.echoMotion) private var motion

    private var height: CGFloat { LayoutTokens.ExplorerDock.capsuleHeight(for: density) }
    private var moreID: String { ExplorerDock.moreItemID(connectionID) }

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(layout.shown) { item in
                let isCurrent = item.id == selectedID
                ExplorerDockButton(
                    title: item.count.map { "\(item.title) · \($0)" } ?? item.title,
                    isCurrent: isCurrent,
                    font: iconFont(isCurrent: isCurrent),
                    height: height,
                    action: { actions.select(connectionID, item.id) }
                ) {
                    Image(systemName: item.symbol)
                        .symbolVariant(isCurrent ? .fill : .none)
                        .foregroundStyle(ink.opacity(isCurrent ? 1 : ServerHeaderTokens.dockIdleOpacity))
                        .contentTransition(.symbolEffect(.replace))
                        .animation(motion.glide, value: isCurrent)
                }
                .lazyContextMenu { actions.menu(connectionID, item.id) }
            }
            if !layout.overflow.isEmpty {
                let isCurrent = selectedID == moreID
                ExplorerDockButton(title: "More sections", isCurrent: isCurrent, font: iconFont(isCurrent: isCurrent), height: height,
                                   action: { actions.select(connectionID, moreID) }) {
                    Image(systemName: "chevron.right.2")
                        .foregroundStyle(ink.opacity(isCurrent ? 1 : ServerHeaderTokens.dockIdleOpacity))
                }
            }
        }
        .padding(.horizontal, SpacingTokens.xxs2)
        .frame(height: height)
        // Behind the icons, so an icon's own menu wins and the empty row gets Dock alone.
        .background { Color.clear.lazyContextMenu { actions.menu(connectionID, nil) } }
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .frame(maxHeight: .infinity)
    }

    private func iconFont(isCurrent: Bool) -> Font {
        .system(size: ServerHeaderTokens.dockIconSize(for: density), weight: isCurrent ? .bold : .medium)
    }
}
