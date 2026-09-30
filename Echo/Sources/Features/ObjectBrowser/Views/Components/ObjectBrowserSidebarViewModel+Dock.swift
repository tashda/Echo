import Foundation

/// The section each server's dock shows, remembered per connection, and where each section was
/// scrolled to, so coming back to a section returns to the same place.
extension ObjectBrowserSidebarViewModel {
    private static func dockSelectionKey(for connectionID: UUID) -> String {
        "echo.sidebar.dockSection.\(connectionID.uuidString)"
    }

    func dockSelection(for connectionID: UUID) -> String? {
        if let selected = dockSelections[connectionID] { return selected }
        return UserDefaults.standard.string(forKey: Self.dockSelectionKey(for: connectionID))
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
        UserDefaults.standard.set(itemID, forKey: Self.dockSelectionKey(for: connectionID))
    }

    func dockScrollAnchor(connectionID: UUID, itemID: String) -> String? {
        dockScrollAnchors["\(connectionID.uuidString)|\(itemID)"]
    }

    func setDockScrollAnchor(_ rowID: String?, connectionID: UUID, itemID: String) {
        dockScrollAnchors["\(connectionID.uuidString)|\(itemID)"] = rowID
    }
}
