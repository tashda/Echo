import SwiftUI

extension QueryTabStrip {
    @ViewBuilder
    func tabButtonView(tab: WorkspaceTab, targetWidth: CGFloat, index: Int, totalCount: Int, appearance: TabChromePalette?) -> some View {
        let isActive = tabStore.activeTabId == tab.id
        let tabIndex = tabStore.index(of: tab.id) ?? 0
        let hasLeft = tabIndex > 0
        let hasRight = tabIndex < totalCount - 1
        let canDuplicate = tab.kind == .query
        let closeOthersDisabled = totalCount <= 1
        let isBeingDragged = dragState.isActive && dragState.id == tab.id

        QueryTabButton(
            tab: tab,
            isActive: isActive,
            onSelect: { tabStore.activeTabId = tab.id },
            onClose: { tabStore.closeTab(id: tab.id) },
            onAddBookmark: tab.query == nil ? nil : { bookmark(tab: tab) },
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
            }
        )
        .frame(width: targetWidth > 0 ? targetWidth : nil)
        .id(tab.id)
        .transaction { transaction in
            if isBeingDragged {
                transaction.animation = nil
            }
        }
    }

    func bookmark(tab: WorkspaceTab) {
        guard let queryState = tab.query else { return }
        let trimmed = queryState.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let database = queryState.clipboardMetadata.databaseName ?? tab.connection.database
        Task {
            await environmentState.addBookmark(
                for: tab.connection,
                databaseName: database,
                title: tab.title,
                query: trimmed,
                source: .tab
            )
        }
    }
}
