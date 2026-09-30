import Foundation

/// State for the ⌘K palette and the toolbar search (plan K4): what was typed, the rows that match
/// and the selected row. Objects come from the global search engine as it finds them; everything
/// else is matched locally on each keystroke.
@MainActor @Observable
final class CommandPaletteModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            objectSearch.query = query
            selectedID = nil
        }
    }
    /// The selected row, by identity, so rows arriving from the object search can't move the
    /// selection to a different row. Nil selects the first row.
    var selectedID: String?

    let objectSearch = SearchSidebarViewModel()
    @ObservationIgnored var localItems: [CommandPaletteItem] = []
    @ObservationIgnored var objectItem: (GlobalSearchResult) -> CommandPaletteItem? = { _ in nil }

    /// Rows per section, so one busy source can't push the others out.
    static let rowsPerSection = 6
    /// With nothing typed, the palette offers actions and tabs.
    static let emptyQuerySections: Set<CommandPaletteItem.Section> = [.actions, .tabs]

    var results: [CommandPaletteItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        var scored: [(item: CommandPaletteItem, score: Int)] = localItems.compactMap { item in
            if trimmed.isEmpty, !Self.emptyQuerySections.contains(item.section) { return nil }
            return CommandPaletteMatcher.score(trimmed, title: item.title, keywords: item.keywords).map { (item, $0) }
        }
        if !trimmed.isEmpty {
            scored += objectSearch.results.compactMap { result in objectItem(result).map { ($0, 500) } }
        }
        let grouped = Dictionary(grouping: scored, by: \.item.section)
        return CommandPaletteItem.Section.allCases.flatMap { section in
            (grouped[section] ?? [])
                .sorted { $0.score > $1.score }
                .prefix(Self.rowsPerSection)
                .map(\.item)
        }
    }

    var isSearchingObjects: Bool { objectSearch.isSearching }

    /// The index of the selected row in `rows`: the selected ID's row, or the first.
    func selectedIndex(in rows: [CommandPaletteItem]) -> Int {
        selectedID.flatMap { id in rows.firstIndex { $0.id == id } } ?? 0
    }

    /// Moves the selection, wrapping at either end.
    func moveSelection(by offset: Int) {
        let rows = results
        guard !rows.isEmpty else { return }
        let index = (selectedIndex(in: rows) + offset + rows.count) % rows.count
        selectedID = rows[index].id
    }

    func select(_ id: String) {
        selectedID = id
    }

    /// Performs the selected row; returns whether there was one.
    @discardableResult
    func performSelected() -> Bool {
        let rows = results
        guard !rows.isEmpty else { return false }
        rows[selectedIndex(in: rows)].perform()
        return true
    }

    func reset() {
        query = ""
        selectedID = nil
    }
}
