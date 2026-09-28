import Foundation

enum ConnectionDockVisibilityPolicy {
    static func visibleIndices(
        connectionIDs: [UUID],
        selectedConnectionID: UUID?,
        showsAllConnections: Bool
    ) -> [Int] {
        let allIndices = Array(connectionIDs.indices)
        let itemLimit = LayoutTokens.ConnectionDock.collapsedItemLimit

        guard !showsAllConnections, connectionIDs.count > itemLimit else {
            return allIndices
        }
        guard
            let selectedConnectionID,
            let selectedIndex = connectionIDs.firstIndex(of: selectedConnectionID)
        else {
            return Array(allIndices.prefix(itemLimit))
        }

        if selectedIndex.isMultiple(of: itemLimit) {
            let adjacentIndex = selectedIndex + 1 < connectionIDs.count
                ? selectedIndex + 1
                : selectedIndex - 1
            return [selectedIndex, adjacentIndex]
        }

        return [selectedIndex - 1, selectedIndex]
    }
}
