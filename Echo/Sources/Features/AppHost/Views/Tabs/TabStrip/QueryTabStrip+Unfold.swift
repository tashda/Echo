import SwiftUI

/// ST2, refined in rounds 36.1 and 49: the front tool tab with pages is exactly as wide as its
/// title and pages (RW1, FP3) and the other tabs share what is left, down to their icons alone
/// (FP1). Alone, it keeps that width at the leading edge (SW1). When even that does not fit, the
/// pages take a row under the strip instead of hiding (FP4).
extension QueryTabStrip {
    /// Switching tabs: the plate, the widths and the pages move on one smooth curve (MO9).
    var switchAnimation: Animation { motion.glide }

    func frontToolTab(in tabs: [(WorkspaceTab, Bool)]) -> WorkspaceTab? {
        let active = tabs.first { $0.0.id == tabStore.activeTabId && !$0.1 }?.0
        guard let active, !active.toolPages.isEmpty else { return nil }
        return active
    }

    func pagePlacement(for tab: WorkspaceTab, tabCount: Int, totalWidth: CGFloat) -> TabPagePlacement {
        TabPagePlacement.resolve(idealWidth: TabPageChipsMetrics.idealWidth(title: tab.title, pages: tab.toolPages),
                                 tabCount: tabCount, totalWidth: totalWidth)
    }

    func tabWidths(for tabs: [(WorkspaceTab, Bool)], equalWidth: CGFloat, totalWidth: CGFloat) -> [UUID: CGFloat] {
        guard let active = frontToolTab(in: tabs),
              pagePlacement(for: active, tabCount: tabs.count, totalWidth: totalWidth) == .inTab else { return [:] }
        return TabUnfoldLayout.widths(
            tabIDs: tabs.map(\.0.id),
            unfoldedID: active.id,
            idealUnfoldedWidth: TabPageChipsMetrics.idealWidth(title: active.title, pages: active.toolPages),
            equalWidth: equalWidth,
            totalWidth: totalWidth
        )
    }
}
