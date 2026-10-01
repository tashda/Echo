import SwiftUI
import UniformTypeIdentifiers

extension TabOverviewView {
    var orderedTabIDs: [UUID] { tabs.map(\.id) }

    var visibleTabIDs: [UUID] {
        groupedTabs.reduce(into: [UUID]()) { result, serverGroup in
            let serverID = serverGroup.connection.id
            guard !collapsedServers.contains(serverID) else { return }
            for databaseGroup in serverGroup.databaseGroups.values {
                let identifier = databaseIdentifier(for: databaseGroup.databaseName, serverID: serverID)
                guard !collapsedDatabases.contains(identifier) else { continue }
                for section in databaseGroup.sections {
                    result.append(contentsOf: section.tabs.map(\.id))
                }
            }
        }
    }

    @ViewBuilder
    func tabCard(for tab: WorkspaceTab, serverID: UUID, databaseIdentifier: String) -> some View {
        Group {
            switch overviewStyle {
            case .comfortable:
                TabPreviewCard(
                    tab: tab,
                    isActive: tab.id == activeTabId,
                    isFocused: tab.id == focusedTabId,
                    isDropTarget: tab.id == dropTargetTabId,
                    onSelect: { onSelectTab(tab.id) },
                    onClose: { onCloseTab(tab.id) }
                )
            case .compact:
                CompactTabPreviewCard(
                    tab: tab,
                    isActive: tab.id == activeTabId,
                    isDropTarget: tab.id == dropTargetTabId,
                    onSelect: { onSelectTab(tab.id) },
                    onClose: { onCloseTab(tab.id) }
                )
            }
        }
        .onTapGesture { focusedTabId = tab.id }
        .focusEffectDisabled(true)
        .contextMenu {
            tabContextMenu(for: tab, serverID: serverID, databaseIdentifier: databaseIdentifier)
        }
        .onDrag {
            draggingTabId = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        } preview: { EmptyView() }
#if os(macOS)
        .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
            targetTabID: tab.id,
            isTrailingPlaceholder: false,
            tabStore: tabStore,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId
        ))
#endif
    }

    var overviewStyle: TabOverviewStyle {
        projectStore.globalSettings.tabOverviewStyle
    }

    var gridConfiguration: (columns: [GridItem], spacing: CGFloat) {
        let comfortableMinCardWidth: CGFloat = 260
        let comfortableMaxCardWidth: CGFloat = 360
        let comfortableGridSpacing: CGFloat = 18
        let compactMinCardWidth: CGFloat = 170
        let compactMaxCardWidth: CGFloat = 240
        let compactGridSpacing: CGFloat = 12

        switch overviewStyle {
        case .comfortable:
            return (
                [GridItem(.adaptive(minimum: comfortableMinCardWidth, maximum: comfortableMaxCardWidth), spacing: comfortableGridSpacing, alignment: .top)],
                comfortableGridSpacing
            )
        case .compact:
            return (
                [GridItem(.adaptive(minimum: compactMinCardWidth, maximum: compactMaxCardWidth), spacing: compactGridSpacing, alignment: .top)],
                compactGridSpacing
            )
        }
    }
}
