import SwiftUI

/// The front tab's plate and the icons' layer, placed from the tabs' widths (round 49, MO2, MO9).
extension QueryTabStrip {
    private func width(of tab: WorkspaceTab, tabWidth: CGFloat, widths: [UUID: CGFloat]) -> CGFloat {
        widths[tab.id] ?? tabWidth
    }

    /// One plate behind the tabs, at the front tab's place; it glides with the tabs' widths.
    @ViewBuilder
    func activePlate(orderedTabs: [(WorkspaceTab, Bool)], tabWidth: CGFloat, widths: [UUID: CGFloat]) -> some View {
        if let index = orderedTabs.firstIndex(where: { $0.0.id == tabStore.activeTabId }) {
            let before = orderedTabs[..<index].reduce(CGFloat.zero) { $0 + width(of: $1.0, tabWidth: tabWidth, widths: widths) }
            TabActivePlate(width: width(of: orderedTabs[index].0, tabWidth: tabWidth, widths: widths),
                           offset: before + tabOffset(for: orderedTabs[index].0, index: index))
                // A dragged front tab carries its own plate above the others (TABS-2.13).
                .opacity(liftedTabID == tabStore.activeTabId ? 0 : 1)
        }
    }

    /// Every tab's icon, placed as its title is (`placedAtOnceWhenResized`).
    func iconLayer(orderedTabs: [(WorkspaceTab, Bool)], tabWidth: CGFloat, widths: [UUID: CGFloat], pagesInTab: Bool) -> some View {
        TabIconLayer(
            items: orderedTabs.enumerated().map { index, element in
                let tab = element.0
                let width = width(of: tab, tabWidth: tabWidth, widths: widths)
                let iconOnly = !widths.isEmpty && TabUnfoldLayout.isIconOnly(width: width, isFront: tab.id == tabStore.activeTabId)
                return TabIconLayer.Item(
                    id: tab.id,
                    symbol: element.1 ? nil : tab.iconName,
                    mark: tab.homeMark,
                    isActive: tab.id == tabStore.activeTabId,
                    isRunning: tab.query?.isExecuting == true,
                    width: width,
                    isIconOnly: iconOnly,
                    inset: TabLabelLayout.iconInset(title: TabLabelLayout.displayed(tab.title), width: width,
                                                    hasPages: pagesInTab && !tab.toolPages.isEmpty && tab.id == tabStore.activeTabId,
                                                    isIconOnly: iconOnly),
                    isHovered: hoveredTabID == tab.id,
                    dragOffset: tabOffset(for: tab, index: index),
                    isLifted: liftedTabID == tab.id
                )
            }
        )
    }
}
