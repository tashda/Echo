import Foundation

struct Bookmark: Identifiable, Codable, Hashable {
    enum Source: String, Codable, CaseIterable {
        case queryEditorSelection
        case savedQuery
        case tab
    }

    var id: UUID
    var connectionID: UUID
    var databaseName: String?
    var title: String?
    var query: String
    var createdAt: Date
    var updatedAt: Date?
    var source: Source

    init(
        id: UUID = UUID(),
        connectionID: UUID,
        databaseName: String?,
        title: String?,
        query: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        source: Source
    ) {
        self.id = id
        self.connectionID = connectionID
        self.databaseName = databaseName
        self.title = title
        self.query = query
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }

    var preview: String {
        let trimmed = query.replacingOccurrences(of: "\n", with: " ⏎ ")
        if trimmed.count <= 160 { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 160)
        return String(trimmed[..<index]) + "…"
    }

    var primaryLine: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        let firstLine = query.split(separator: "\n").first.map(String.init) ?? query
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Array where Element == Bookmark {
    func groupedByDatabase() -> [BookmarkDatabaseGroup] {
        let groups = Dictionary(grouping: self) { bookmark -> String in
            bookmark.databaseName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? BookmarkDatabaseGroup.unknownIdentifier
        }

        return groups
            .map { key, value in
                BookmarkDatabaseGroup(
                    id: key,
                    databaseName: key == BookmarkDatabaseGroup.unknownIdentifier ? nil : value.first?.databaseName?.trimmingCharacters(in: .whitespacesAndNewlines),
                    bookmarks: value.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.databaseName, rhs.databaseName) {
                case (.none, .none):
                    return false
                case (.none, .some):
                    return false
                case (.some, .none):
                    return true
                case (.some(let left), .some(let right)):
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
            }
    }
}

struct BookmarkDatabaseGroup: Identifiable, Hashable {
    static let unknownIdentifier = "__unknown_database__"

    var id: String
    var databaseName: String?
    var bookmarks: [Bookmark]
}

struct BookmarkConnectionGroup: Identifiable, Hashable {
    var id: UUID { connectionID }
    var connectionID: UUID
    var connectionName: String
    var bookmarks: [Bookmark]
}

extension Array where Element == Bookmark {
    func groupedByConnection(connectionNames: [UUID: String]) -> [BookmarkConnectionGroup] {
        let groups = Dictionary(grouping: self) { $0.connectionID }

        return groups
            .map { connectionID, bookmarks in
                BookmarkConnectionGroup(
                    connectionID: connectionID,
                    connectionName: connectionNames[connectionID] ?? "Unknown Server",
                    bookmarks: bookmarks.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { lhs, rhs in
                lhs.connectionName.localizedCaseInsensitiveCompare(rhs.connectionName) == .orderedAscending
            }
    }

    func matching(searchText: String, connectionNames: [UUID: String] = [:]) -> [Bookmark] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return self }
        return filter { bookmark in
            bookmark.primaryLine.lowercased().contains(query) ||
            bookmark.query.lowercased().contains(query) ||
            (bookmark.databaseName?.lowercased().contains(query) ?? false) ||
            (connectionNames[bookmark.connectionID]?.lowercased().contains(query) ?? false)
        }
    }
}
