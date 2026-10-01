import Foundation

/// One tab in the tab overview (round 35.1, TO6), as plain values so matching, grouping and the
/// keys can be tested without a live session.
nonisolated struct TabOverviewEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let server: String
    /// The database, or for a tool tab its name and database.
    let detail: String
    /// Extra words that match but aren't shown, such as the first line of the SQL.
    var keywords: String = ""
}

/// A server's tabs, under its name, in tab strip order.
nonisolated struct TabOverviewServerGroup: Identifiable, Equatable, Sendable {
    let server: String
    let entries: [TabOverviewEntry]
    var id: String { server }
}

extension TabOverviewEntry {
    /// The tabs grouped by server, servers in the order their first tab appears in the strip.
    static func groups(_ entries: [TabOverviewEntry]) -> [TabOverviewServerGroup] {
        var order: [String] = []
        var byServer: [String: [TabOverviewEntry]] = [:]
        for entry in entries {
            if byServer[entry.server] == nil { order.append(entry.server) }
            byServer[entry.server, default: []].append(entry)
        }
        return order.map { TabOverviewServerGroup(server: $0, entries: byServer[$0] ?? []) }
    }

    /// The entries that match what was typed, keeping strip order: the overview is a survey,
    /// so rows don't jump around as you type.
    static func matching(_ query: String, in entries: [TabOverviewEntry]) -> [TabOverviewEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            CommandPaletteMatcher.score(trimmed, title: $0.title, keywords: "\($0.server) \($0.detail) \($0.keywords)") != nil
        }
    }

    /// The row that takes the selection when `id` closes: the next one, else the one before.
    static func neighbour(of id: UUID, in shown: [TabOverviewEntry]) -> UUID? {
        guard let index = shown.firstIndex(where: { $0.id == id }) else { return nil }
        if index + 1 < shown.count { return shown[index + 1].id }
        return index > 0 ? shown[index - 1].id : nil
    }
}
