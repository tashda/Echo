import SwiftUI

extension QueryTabStrip {
    @ViewBuilder
    func tabButtonView(
        tab: WorkspaceTab,
        targetWidth: CGFloat,
        index: Int,
        totalCount: Int,
        appearance: TabChromePalette?,
        pagesInTab: Bool,
        isIconOnly: Bool,
        databaseNames: [String]
    ) -> some View {
        let isActive = tabStore.activeTabId == tab.id
        let tabIndex = tabStore.index(of: tab.id) ?? 0
        let hasLeft = tabIndex > 0
        let hasRight = tabIndex < totalCount - 1
        let canDuplicate = tab.kind == .query
        let closeOthersDisabled = totalCount <= 1
        let isBeingDragged = dragState.isActive && dragState.id == tab.id
        let databases = tab.kind == .query ? databaseNames : []

        QueryTabButton(
            tab: tab,
            isActive: isActive,
            onSelect: { tabStore.activeTabId = tab.id },
            onClose: { tabStore.closeTab(id: tab.id) },
            onPinToggle: { tabStore.togglePin(for: tab.id) },
            onDuplicate: { environmentState.duplicateTab(tab) },
            onCloseOthers: { tabStore.closeOtherTabs(keeping: tab.id) },
            onCloseLeft: { tabStore.closeTabsLeft(of: tab.id) },
            onCloseRight: { tabStore.closeTabsRight(of: tab.id) },
            canDuplicate: canDuplicate,
            closeOthersDisabled: closeOthersDisabled,
            closeTabsLeftDisabled: !hasLeft,
            closeTabsRightDisabled: !hasRight,
            isDropTarget: false,
            isBeingDragged: isBeingDragged,
            appearance: appearance,
            onHoverChanged: { hovering in
                if hovering {
                    hoveredTabID = tab.id
                } else if hoveredTabID == tab.id {
                    hoveredTabID = nil
                }
            },
            availableDatabases: databases,
            onSwitchDatabase: databases.isEmpty ? nil : { dbName in
                switchDatabase(dbName, for: tab)
            },
            finalWidth: targetWidth,
            pagesInTab: pagesInTab,
            isIconOnly: isIconOnly,
            isLifted: liftedTabID == tab.id
        )
        .frame(width: targetWidth > 0 ? targetWidth : nil)
        // The Save card hangs from the tab it saves (round IC).
        .tabBoundsAnchor(tab.id)
        .id(tab.id)
        .transaction { transaction in
            if isBeingDragged {
                transaction.animation = nil
            }
        }
    }

    // MARK: - Database Switching

    func switchDatabase(_ databaseName: String, for tab: WorkspaceTab) {
        environmentState.switchDatabase(databaseName, for: tab)
    }
}
