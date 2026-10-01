import SwiftUI

/// ST2, refined in round 36.1: the active tool tab with pages is exactly as wide as its title and
/// pages (RW1) and the other tabs share what is left; alone, it keeps that width at the leading
/// edge (SW1). It unfolds and folds on the house spring (UF1).
extension QueryTabStrip {
    var unfoldAnimation: Animation { motion.standard }

    func tabWidths(for tabs: [(WorkspaceTab, Bool)], equalWidth: CGFloat, totalWidth: CGFloat) -> [UUID: CGFloat] {
        let active = tabs.first { $0.0.id == tabStore.activeTabId && !$0.1 }?.0
        guard let active, !active.toolPages.isEmpty else { return [:] }
        return TabUnfoldLayout.widths(
            tabIDs: tabs.map(\.0.id),
            unfoldedID: active.id,
            idealUnfoldedWidth: TabPageChipsMetrics.idealWidth(title: active.title, pages: active.toolPages),
            equalWidth: equalWidth,
            totalWidth: totalWidth
        )
    }
}

/// The widths of the tabs when one of them unfolds; empty when every tab keeps the equal width.
enum TabUnfoldLayout {
    static func widths(tabIDs: [UUID], unfoldedID: UUID, idealUnfoldedWidth: CGFloat,
                       equalWidth: CGFloat, totalWidth: CGFloat) -> [UUID: CGFloat] {
        guard tabIDs.contains(unfoldedID) else { return [:] }
        guard tabIDs.count > 1 else {
            // Alone: its own width, unless that is the whole strip anyway.
            return idealUnfoldedWidth < totalWidth ? [unfoldedID: idealUnfoldedWidth] : [:]
        }
        let unfolded = min(idealUnfoldedWidth, totalWidth * LayoutTokens.TabPages.maxShareOfStrip)
        guard unfolded != equalWidth else { return [:] }
        let others = max((totalWidth - unfolded) / CGFloat(tabIDs.count - 1), 0)
        return Dictionary(uniqueKeysWithValues: tabIDs.map { ($0, $0 == unfoldedID ? unfolded : others) })
    }
}
