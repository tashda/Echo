import Foundation

/// One saved connection as the opened server trail lists it (round 52): a name, "host · database"
/// under it, and the folder it lives in.
nonisolated struct ConnectTrailEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let host: String
    let database: String
    /// The folder's name, or its path ("corporate / eu") when nested; nil at the top level.
    let folder: String?

    /// "host · database", or only the host when no database is set.
    var detail: String { database.isEmpty ? host : "\(host) · \(database)" }
}

/// A heading and the connections under it.
nonisolated struct ConnectTrailSection: Identifiable, Equatable, Sendable {
    let title: String
    let entries: [ConnectTrailEntry]
    var id: String { title }
}

/// What the opened trail's list shows for a search (round 52, CT1 and KB1): saved connections
/// grouped by folder under small headings, filtered by what was typed, and which row Return connects.
nonisolated enum ConnectTrailListing {
    /// The heading over connections that are in no folder.
    static let unfolderedTitle = "Saved"

    /// Connections whose name or "host · database" contains the query, ignoring case and accents.
    static func matches(_ entries: [ConnectTrailEntry], query: String) -> [ConnectTrailEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedStandardContains(needle) || $0.detail.localizedStandardContains(needle)
        }
    }

    /// The matches under their folder's heading: connections in no folder first ("Saved"), then the
    /// folders by name. Rows inside a heading are in name order. Headings with no match are left out.
    static func sections(_ entries: [ConnectTrailEntry], query: String) -> [ConnectTrailSection] {
        let found = matches(entries, query: query)
        let byName: (ConnectTrailEntry, ConnectTrailEntry) -> Bool = {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var result: [ConnectTrailSection] = []
        let unfoldered = found.filter { $0.folder == nil }.sorted(by: byName)
        if !unfoldered.isEmpty {
            result.append(ConnectTrailSection(title: unfolderedTitle, entries: unfoldered))
        }

        let folderNames = Set(found.compactMap(\.folder))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        for folder in folderNames {
            result.append(ConnectTrailSection(title: folder, entries: found.filter { $0.folder == folder }.sorted(by: byName)))
        }
        return result
    }

    /// The rows in the order they are drawn.
    static func orderedIDs(_ sections: [ConnectTrailSection]) -> [UUID] {
        sections.flatMap { $0.entries.map(\.id) }
    }

    /// The row that is highlighted: the current one while it is still listed, else the first.
    /// Return connects it, so the first match is ready as soon as something is typed.
    static func highlight(current: UUID?, in ids: [UUID]) -> UUID? {
        if let current, ids.contains(current) { return current }
        return ids.first
    }

    /// The highlight moved up (-1) or down (+1) a row, stopping at the first and last.
    static func moved(from current: UUID?, in ids: [UUID], by step: Int) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return step >= 0 ? ids.first : ids.last
        }
        return ids[min(max(index + step, 0), ids.count - 1)]
    }
}
