import SwiftUI

/// The icons of the strip's tabs on a layer of their own, already at their final places (round 49,
/// MO9): when you switch tabs the tabs and the plate glide and the icons do not travel with them.
struct TabIconLayer: View {
    struct Item: Identifiable {
        let id: UUID
        /// Nil for a pinned tab, which shows its first letter instead.
        let symbol: String?
        /// What the icon says about the tab's home (round IC).
        var mark: Mark = .kind
        let isActive: Bool
        let isRunning: Bool
        let width: CGFloat
        let isIconOnly: Bool
        /// Where the icon starts, from the tab's left edge (`TabLabelLayout.iconInset`).
        let inset: CGFloat
        let isHovered: Bool
        let dragOffset: CGFloat
    }

    /// A query tab's home in place of its kind's icon (round IC): a filled bookmark in the accent
    /// colour, a document for a .sql file, a dot for changes not saved yet (as Safari and Xcode
    /// mark edited documents). `hidden` leaves the room to the tab's ☆ while the pointer is on a
    /// tab with no home.
    enum Mark: Equatable {
        case kind
        case bookmark
        case file
        case edited
        case hidden
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
                switch item.mark {
                case .kind:
                    Image(systemName: symbol).font(TypographyTokens.detail).foregroundStyle(tint(item))
                case .bookmark:
                    Image(systemName: "bookmark.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent)
                case .file:
                    Image(systemName: "doc.text").font(TypographyTokens.detail).foregroundStyle(tint(item))
                case .edited:
                    Circle().fill(tint(item))
                        .frame(width: LayoutTokens.TabHome.editedDotSize, height: LayoutTokens.TabHome.editedDotSize)
                case .hidden:
                    Color.clear
                }
            }
        }
        .frame(width: SpacingTokens.sm2)
        .padding(.leading, item.inset)
        .opacity(item.isIconOnly && item.isHovered ? 0 : 1)
    }

    private func tint(_ item: Item) -> Color {
        Color(nsColor: item.isActive ? .labelColor : .secondaryLabelColor).opacity(item.isActive ? 0.8 : 0.7)
    }
}

extension LayoutTokens {
    /// A query tab's home mark (round IC).
    enum TabHome {
        static let editedDotSize: CGFloat = 7
    }
}
