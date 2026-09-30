import SwiftUI

/// ST2: when the active tab is a tool with pages, it widens to show them and the other tabs
/// share what is left.
extension QueryTabStrip {
    var unfoldAnimation: Animation { .snappy(duration: 0.32, extraBounce: 0.06) }

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
        guard tabIDs.count > 1, tabIDs.contains(unfoldedID) else { return [:] }
        let unfolded = min(max(equalWidth, idealUnfoldedWidth), totalWidth * LayoutTokens.TabPages.maxShareOfStrip)
        guard unfolded > equalWidth else { return [:] }
        let others = max((totalWidth - unfolded) / CGFloat(tabIDs.count - 1), 0)
        return Dictionary(uniqueKeysWithValues: tabIDs.map { ($0, $0 == unfoldedID ? unfolded : others) })
    }
}
