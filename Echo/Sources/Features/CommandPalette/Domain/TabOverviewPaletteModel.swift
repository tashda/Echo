import Foundation

/// The palette's tab overview (round 35.1, TO6): what was typed and the selected tab. The rows
/// themselves come live from the tab store, so a running tab's state updates while it shows.
@MainActor @Observable
final class TabOverviewPaletteModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            selectedID = nil
        }
    }
    /// Nil selects the active tab if it shows, else the first row.
    var selectedID: UUID?

    /// The rows in the order they show: matching tabs, grouped by server.
    func shown(_ entries: [TabOverviewEntry]) -> [TabOverviewEntry] {
        TabOverviewEntry.groups(TabOverviewEntry.matching(query, in: entries)).flatMap(\.entries)
    }

    func selection(in shown: [TabOverviewEntry], activeID: UUID?) -> UUID? {
        if let selectedID, shown.contains(where: { $0.id == selectedID }) { return selectedID }
        if let activeID, shown.contains(where: { $0.id == activeID }) { return activeID }
        return shown.first?.id
    }

    /// Moves the selection, wrapping at either end.
    func moveSelection(by offset: Int, in shown: [TabOverviewEntry], activeID: UUID?) {
        guard !shown.isEmpty else { return }
        let current = selection(in: shown, activeID: activeID).flatMap { id in shown.firstIndex { $0.id == id } } ?? 0
        selectedID = shown[(current + offset + shown.count) % shown.count].id
    }

    func reset() {
        query = ""
        selectedID = nil
    }
}
