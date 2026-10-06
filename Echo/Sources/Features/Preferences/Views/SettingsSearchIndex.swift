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
        .init(title: "Show scroll bar", section: .sidebar, group: "Object Browser"),
        .init(title: "Hide offline databases by default", section: .sidebar, group: "Databases"),
        .init(title: "Customize per database type", section: .sidebar, group: "General"),
        .init(title: "Confirm Unguarded Writes", section: .databases, group: "Execution & Ingestion"),
        .init(title: "Query time limit", section: .databases, group: "Execution & Ingestion"),
        .init(title: "Initial rows to display", section: .databases, group: "Execution & Ingestion"),
        .init(title: "Automatic Updates", section: .general, group: "Software Update"),
        .init(title: "Check for updates", section: .general, group: "Software Update"),
        .init(title: "Allow notifications", section: .notifications, group: "Notifications"),
        .init(title: "Notification delivery", section: .notifications, group: "Delivery"),
        .init(title: "Appearance", section: .appearance, group: "Appearance"),
        .init(title: "Explorer Sidebar", section: .appearance, group: "Appearance"),
        .init(title: "Sidebar Icons", section: .appearance, group: "Appearance"),
        .init(title: "Monochrome Style", section: .appearance, group: "Appearance"),
        .init(title: "Section Dock Icons", section: .appearance, group: "Appearance"),
        .init(title: "Current Dock Icon", section: .appearance, group: "Appearance"),
        .init(title: "Server Header", section: .appearance, group: "Appearance"),
        .init(title: "Server Header Color", section: .appearance, group: "Appearance"),
        .init(title: "Server Name Typeface", section: .appearance, group: "Appearance"),
        .init(title: "Server Name Size", section: .appearance, group: "Appearance"),
        .init(title: "Line Above the Name", section: .appearance, group: "Appearance"),
        .init(title: "Spacing", section: .appearance, group: "Appearance"),
        .init(title: "Banner Edge", section: .appearance, group: "Appearance"),
        .init(title: "Banner Text Color", section: .appearance, group: "Appearance"),
        .init(title: "Toolbar Project Button", section: .appearance, group: "Appearance"),
        .init(title: "Animation Speed", section: .appearance, group: "Workspace"),
        .init(title: "Spacing Between Panes", section: .appearance, group: "Workspace"),
        .init(title: "Card Corners", section: .appearance, group: "Workspace"),
        .init(title: "Server Rail Size", section: .appearance, group: "Workspace"),
        .init(title: "Show Recent Servers", section: .appearance, group: "Server Trail"),
        .init(title: "Number of Recent Servers", section: .appearance, group: "Server Trail"),
        .init(title: "Accent Color", section: .appearance, group: "Theme"),
        .init(title: "Include offline databases", section: .search, group: "Scope"),
        .init(title: "Minimum query length", section: .search, group: "Query"),
        .init(title: "Diagram prefetch", section: .diagrams, group: "Prefetching"),
        .init(title: "Background refresh", section: .diagrams, group: "Prefetching"),
        .init(title: "Verify diagram data before refresh", section: .diagrams, group: "Rendering"),
        .init(title: "Render relationships in large diagrams", section: .diagrams, group: "Rendering"),
        .init(title: "Qualify table completions", section: .echoSense, group: "Insertion"),
        .init(title: "Show system schemas", section: .echoSense, group: "Insertion"),
        .init(title: "Ghost text instead of the list", section: .echoSense, group: "Insertion"),
        .init(title: "Trigger shortcuts", section: .echoSense, group: "Shortcuts"),
        .init(title: "Maximum storage", section: .applicationCache, group: "Storage"),
        .init(title: "Object browser cache", section: .applicationCache, group: "Storage"),
        .init(title: "Streaming Mode", section: .databases, group: "Execution & Ingestion"),
        .init(title: "Continue after a failed statement", section: .databases, group: "Scripts"),
        .init(title: "Enable Postgres Console", section: .databases, group: "Managed Console"),
        .init(title: "Tool Path", section: .databases, group: "Backup & Restore Tools"),
        .init(title: "Refresh Interval", section: .databases, group: "Activity Monitor"),
        .init(title: "Slow down when not shown", section: .databases, group: "Activity Monitor"),
        .init(title: "Hide inaccessible databases", section: .databases, group: "Databases"),
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
