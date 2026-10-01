import AppKit

/// The rules every Explorer context menu follows (round 42.1): icons only on the familiar
/// actions (New, Copy, Refresh, Properties, Drop), no doubled or edge separators, Copy Name where
/// an object has a name. The menus list their commands in the agreed order; this tidies the result.
extension NSMenu {
    /// Titles whose icon the system uses for the same action everywhere.
    nonisolated static func hasFamiliarIcon(_ title: String) -> Bool {
        ["New ", "Copy", "Refresh", "Properties", "Drop", "Server Properties"].contains { title.hasPrefix($0) }
    }

    @discardableResult
    func applyingExplorerRules() -> NSMenu {
        for item in items {
            if let image = item.image, image.isTemplate, !Self.hasFamiliarIcon(item.title) {
                item.image = nil
            }
            item.submenu?.applyingExplorerRules()
        }
        moveRefreshToEnd()
        tidySeparators()
        return self
    }

    /// In a folder's menu Refresh comes last, after what you can create there. Menus that end in
    /// Drop or Properties already have it in place.
    private func moveRefreshToEnd() {
        let endsWithObjectCommands = items.contains { $0.title.hasPrefix("Drop") || $0.title == "Properties" }
        guard !endsWithObjectCommands,
              let refresh = items.first(where: { $0.title == "Refresh" }),
              refresh !== items.last else { return }
        removeItem(refresh)
        addItem(.separator())
        addItem(refresh)
    }

    /// Removes separators at either end and the second of two in a row.
    private func tidySeparators() {
        while let first = items.first, first.isSeparatorItem { removeItem(first) }
        while let last = items.last, last.isSeparatorItem { removeItem(last) }
        var index = 1
        while index < items.count {
            if items[index].isSeparatorItem, items[index - 1].isSeparatorItem {
                removeItem(at: index)
            } else {
                index += 1
            }
        }
    }

    /// Adds Copy Name to a menu that has none, in its own group before Drop and Properties.
    func insertingCopyName(_ name: String) -> NSMenu {
        let endIndex = items.firstIndex { $0.title.hasPrefix("Drop") || $0.title.hasPrefix("Delete") || $0.title == "Properties" } ?? items.count
        let copy = ClosureMenuItem(title: "Copy Name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(name, forType: .string)
        }
        copy.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy Name")
        // Before the separator that opens the Drop group, if there is one.
        var index = endIndex
        while index > 0, items[index - 1].isSeparatorItem { index -= 1 }
        // Separators on both sides; `applyingExplorerRules` removes doubled and edge ones.
        insertItem(.separator(), at: index)
        insertItem(copy, at: index + 1)
        insertItem(.separator(), at: index + 2)
        return self
    }

    /// Copy Name: puts the object's name on the pasteboard.
    @discardableResult
    func addCopyName(_ name: String) -> NSMenuItem {
        addActionItem("Copy Name", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(name, forType: .string)
        }
    }
}
