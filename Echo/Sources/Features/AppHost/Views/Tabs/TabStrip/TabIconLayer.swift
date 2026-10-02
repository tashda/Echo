import SwiftUI

/// The icons of the strip's tabs on a layer of their own, already at their final places (round 49,
/// MO9): when you switch tabs the tabs and the plate glide and the icons do not travel with them.
struct TabIconLayer: View {
    struct Item: Identifiable {
        let id: UUID
        /// Nil for a pinned tab, which shows its first letter instead.
        let symbol: String?
        let isActive: Bool
        let isRunning: Bool
        let width: CGFloat
        let isIconOnly: Bool
        /// Where the icon starts, from the tab's left edge (`TabLabelLayout.iconInset`).
        let inset: CGFloat
        let isHovered: Bool
        let dragOffset: CGFloat
    }

    let items: [Item]
    /// Changing the front tab moves no icon through the layer.
    let frontTabID: UUID?

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(items) { item in
                Color.clear
                    .frame(width: item.width, height: WorkspaceChromeMetrics.tabHeight)
                    .overlay(alignment: .leading) { icon(item) }
                    .offset(x: item.dragOffset)
            }
        }
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transaction(value: frontTabID) { $0.animation = nil }
    }

    @ViewBuilder
    private func icon(_ item: Item) -> some View {
        if let symbol = item.symbol { icon(item, symbol: symbol) }
    }

    @ViewBuilder
    private func icon(_ item: Item, symbol: String) -> some View {
        Group {
            if item.isRunning {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: symbol)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(Color(nsColor: item.isActive ? .labelColor : .secondaryLabelColor).opacity(item.isActive ? 0.8 : 0.7))
            }
        }
        .frame(width: SpacingTokens.sm2)
        .padding(.leading, item.inset)
        .opacity(item.isIconOnly && item.isHovered ? 0 : 1)
    }
}
