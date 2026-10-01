import Foundation

/// The section each server's dock shows, remembered per connection. Where each section was
/// scrolled to is kept by the outline (ObjectBrowserOutlineView).
extension ObjectBrowserSidebarViewModel {
    private static func dockSelectionKey(for connectionID: UUID) -> String {
        "echo.sidebar.dockSection.\(connectionID.uuidString)"
    }

    func dockSelection(for connectionID: UUID) -> String? {
        if let selected = dockSelections[connectionID] { return selected }
        return ExplorerStateStore.string(forKey: Self.dockSelectionKey(for: connectionID))
    }

    /// Every connection's saved choice, for building the tree.
    func dockSelections(for connectionIDs: [UUID]) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for id in connectionIDs {
            if let selected = dockSelection(for: id) { result[id] = selected }
        }
        return result
    }

    func setDockSelection(_ itemID: String, for connectionID: UUID) {
        dockSelections[connectionID] = itemID
        ExplorerStateStore.set(itemID, forKey: Self.dockSelectionKey(for: connectionID))
    }
}
