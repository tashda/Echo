import Foundation

/// Round 43.5 (SE2): what Settings search can find. One entry per setting that has a row, with the
/// page and group it lives on; choosing a result opens the page and highlights the group.
struct SettingsSearchEntry: Identifiable, Hashable {
    let title: String
    let section: SettingsView.SettingsSection
    let group: String
    var id: String { "\(section.rawValue)/\(group)/\(title)" }

    var location: String { "\(section.title) › \(group)" }
}

enum SettingsSearchIndex {
    static let entries: [SettingsSearchEntry] = [
        .init(title: "Font", section: .editor, group: "Text"),
        .init(title: "Size", section: .editor, group: "Text"),
        .init(title: "Line Height", section: .editor, group: "Text"),
        .init(title: "Ligatures", section: .editor, group: "Text"),
        .init(title: "Line Numbers", section: .editor, group: "Gutter"),
        .init(title: "Gutter Style", section: .editor, group: "Gutter"),
        .init(title: "Statement Focus", section: .editor, group: "While Typing"),
        .init(title: "Highlight the Word at the Caret", section: .editor, group: "While Typing"),
        .init(title: "Check the Query as You Type", section: .editor, group: "While Typing"),
        .init(title: "Wrap Long Lines", section: .editor, group: "While Typing"),
        .init(title: "Mark Corners", section: .editor, group: "Marks"),
        .init(title: "Mark Strength", section: .editor, group: "Marks"),
        .init(title: "Full Error Message at the Statement", section: .editor, group: "After a Run"),
        .init(title: "Outline Edge", section: .editor, group: "Edges"),
        .init(title: "Show row numbers", section: .queryResults, group: "Appearance"),
        .init(title: "Alternate row shading", section: .queryResults, group: "Appearance"),
        .init(title: "Monospaced cells", section: .queryResults, group: "Appearance"),
        .init(title: "Foreign keys in inspector", section: .queryResults, group: "Cell Inspector"),
        .init(title: "JSON values in inspector", section: .queryResults, group: "Cell Inspector"),
        .init(title: "Auto-open inspector", section: .queryResults, group: "Cell Inspector"),
        .init(title: "Auto-open on activity", section: .queryResults, group: "Bottom Panel"),
        .init(title: "Expand one connection at a time", section: .sidebar, group: "Object Browser"),
        .init(title: "Show scroll bar", section: .sidebar, group: "Object Browser"),
        .init(title: "Hide offline databases by default", section: .sidebar, group: "Databases"),
        .init(title: "Customize per database type", section: .sidebar, group: "General"),
        .init(title: "Confirm Unguarded Writes", section: .databases, group: "Execution & Ingestion"),
        .init(title: "Query time limit", section: .databases, group: "Execution & Ingestion"),
        .init(title: "Initial rows to display", section: .databases, group: "Execution & Ingestion"),
    ]

    /// Entries whose title, page or group contains every word of the query.
    static func matches(for query: String) -> [SettingsSearchEntry] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let pages = SettingsView.SettingsSection.allCases.map {
            SettingsSearchEntry(title: $0.title, section: $0, group: "Page")
        }
        return (entries + pages).filter { entry in
            let haystack = "\(entry.title) \(entry.section.title) \(entry.group)".lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
    }
}
