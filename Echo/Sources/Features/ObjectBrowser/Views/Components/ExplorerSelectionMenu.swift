import AppKit
import Observation

/// The menu of the row selected in the Explorer, kept where the menu bar's Object menu can read
/// it (round 42.1, MB0): the same commands as the row's context menu, built by the same code.
@MainActor @Observable
final class ExplorerSelectionMenu {
    static let shared = ExplorerSelectionMenu()

    /// The selected row's menu, or nil when nothing is selected or the row has no menu.
    private(set) var menu: NSMenu?

    func update(menu: NSMenu?) {
        guard let menu, !menu.items.isEmpty else {
            self.menu = nil
            return
        }
        self.menu = menu
    }

    func clear() { menu = nil }
}
