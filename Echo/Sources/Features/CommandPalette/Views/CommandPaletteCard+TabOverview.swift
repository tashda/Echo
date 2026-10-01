import AppKit
import SwiftUI

/// The tab overview's actions (round 35.1): go to a tab, and the keys the owner asked for
/// (⌫ closes the tab, ⌘D duplicates it, ⌥⌫ closes the others). The palette stays open after a
/// key so you can keep tidying; Return or a click goes to the tab and closes it.
extension CommandPaletteCard {
    var shownTabs: [TabOverviewEntry] {
        tabOverview.shown(TabOverviewEntry.entries(for: tabStore.tabs))
    }

    var selectedTabID: UUID? {
        tabOverview.selection(in: shownTabs, activeID: tabStore.activeTabId)
    }

    func openTab(_ id: UUID) {
        guard let tab = tabStore.tabs.first(where: { $0.id == id }) else { return }
        environmentState.sessionGroup.setActiveSession(tab.connectionSessionID)
        tabStore.activeTabId = id
        onClose()
    }

    /// ⌫ and ⌥⌫ edit the search while something is typed; ⌘⌫ and ⌘D always act on the tab.
    func performTabKey(_ command: CommandPaletteSearchField.KeyCommand) -> Bool {
        switch command {
        case .deleteBackward:
            guard tabOverview.query.isEmpty else { return false }
            closeSelectedTab()
        case .deleteToLineStart:
            closeSelectedTab()
        case .deleteWordBackward:
            guard tabOverview.query.isEmpty else { return false }
            closeOtherTabs()
        }
        return true
    }

    /// ⌘D and Esc in the tab overview, seen before the menus and whatever holds the keyboard: ⌘D
    /// never reached the field (owner, 1 Oct), and Esc must close the overview wherever focus is.
    /// Installed only while the palette shows the tabs (the monitor keeps the scope it was made with).
    func updateKeyMonitor(for scope: CommandPaletteScope) {
        removeKeyMonitor()
        if scope == .tabs { installKeyMonitor() }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == Self.escapeKeyCode, modifiers.isEmpty {
                onClose()
                return nil
            }
            if modifiers == .command, event.charactersIgnoringModifiers == "d" {
                duplicateSelectedTab()
                return nil
            }
            return event
        }
    }

    func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static let escapeKeyCode: UInt16 = 53

    private func closeSelectedTab() {
        let shown = shownTabs
        guard let id = tabOverview.selection(in: shown, activeID: tabStore.activeTabId) else { return }
        let next = TabOverviewEntry.neighbour(of: id, in: shown)
        tabStore.closeTab(id: id)
        // Closing can be refused (unsaved work): keep the selection on the tab then.
        guard !tabStore.tabs.contains(where: { $0.id == id }) else { return }
        tabOverview.selectedID = next
        if tabStore.tabs.isEmpty { onClose() }
    }

    private func closeOtherTabs() {
        guard let id = selectedTabID else { return }
        tabStore.closeOtherTabs(keeping: id)
        tabOverview.selectedID = id
    }

    func duplicateSelectedTab() {
        guard let id = selectedTabID, let tab = tabStore.tabs.first(where: { $0.id == id }) else { return }
        let before = Set(tabStore.tabs.map(\.id))
        environmentState.duplicateTab(tab)
        tabOverview.selectedID = tabStore.tabs.first { !before.contains($0.id) }?.id ?? id
    }
}
