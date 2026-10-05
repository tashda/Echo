import SwiftUI

/// The icons of the strip's tabs on a layer of their own (round 49, MO9). When a tab's width
/// changes (switching to or from a tool tab) its icon lands at its final place at once, as its title
/// does; when tabs only move (a reorder, a drag) the icons ride with their tabs.
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
        /// A dragged tab draws its own icon above the tabs it passes (TABS-2.13).
        var isLifted = false
    }

    /// A query tab's home in place of its kind's icon (round IC): a filled bookmark in the accent
    /// colour, a document for a .sql file, a dot for changes not saved yet (as Safari and Xcode
    /// mark edited documents).
    enum Mark: Equatable {
        case kind
        case bookmark
        case file
        case edited
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            ForEach(items) { item in
                Color.clear
                    .frame(width: item.width, height: WorkspaceChromeMetrics.tabHeight)
                    .overlay(alignment: .leading) {
                        icon(item).placedAtOnceWhenResized(width: item.width, isActive: item.isActive)
                    }
                    .offset(x: item.dragOffset)
            }
        }
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func icon(_ item: Item) -> some View {
        if let symbol = item.symbol { icon(item, symbol: symbol) }
    }

    private func icon(_ item: Item, symbol: String) -> some View {
        TabIconGlyph(symbol: symbol, mark: item.mark, isActive: item.isActive, isRunning: item.isRunning)
            .padding(.leading, item.inset)
            .opacity(item.isLifted || (item.isIconOnly && item.isHovered) ? 0 : 1)
    }
}

/// A tab's icon: its kind's symbol, its home's mark, or a spinner while it runs. Drawn on the
/// strip's still layer, and by a dragged tab itself.
struct TabIconGlyph: View {
    let symbol: String
    let mark: TabIconLayer.Mark
    let isActive: Bool
    let isRunning: Bool

    var body: some View {
        Group {
            if isRunning {
                ProgressView().controlSize(.mini)
            } else {
                switch mark {
                case .kind:
                    Image(systemName: symbol).font(TypographyTokens.detail).foregroundStyle(tint)
                case .bookmark:
                    Image(systemName: "bookmark.fill").font(TypographyTokens.detail).foregroundStyle(ColorTokens.accent)
                case .file:
                    Image(systemName: "doc.text").font(TypographyTokens.detail).foregroundStyle(tint)
                case .edited:
                    Circle().fill(tint)
                        .frame(width: LayoutTokens.TabHome.editedDotSize, height: LayoutTokens.TabHome.editedDotSize)
                }
            }
        }
        .frame(width: SpacingTokens.sm2)
    }

    private var tint: Color {
        Color(nsColor: isActive ? .labelColor : .secondaryLabelColor).opacity(isActive ? 0.8 : 0.7)
    }
}

extension View {
    /// A tab's icon and title land at their place at once when the tab's width changes or it
    /// becomes the front tab (round 49, MO9), and ride with the tab when it only moves, so a
    /// reorder or a drag carries them together with their tab.
    func placedAtOnceWhenResized(width: CGFloat, isActive: Bool) -> some View {
        transaction(value: width) { $0.animation = nil }
            .transaction(value: isActive) { $0.animation = nil }
    }
}

extension LayoutTokens {
    /// A query tab's home mark (round IC).
    enum TabHome {
        static let editedDotSize: CGFloat = 7
    }
}
