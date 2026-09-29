import Foundation

/// State for the ⌘K palette and the toolbar search (plan K4): what was typed, the rows that match
/// and the selected row. Objects come from the global search engine as it finds them; everything
/// else is matched locally on each keystroke.
@MainActor @Observable
final class CommandPaletteModel {
    var query = "" {
        didSet {
            objectSearch.query = query
            selectedIndex = 0
        }
    }
    var selectedIndex = 0

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

    func moveSelection(by offset: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + offset + count) % count
    }

    /// Performs the selected row; returns whether there was one.
    @discardableResult
    func performSelected() -> Bool {
        let rows = results
        guard rows.indices.contains(selectedIndex) else { return false }
        rows[selectedIndex].perform()
        return true
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }
}
