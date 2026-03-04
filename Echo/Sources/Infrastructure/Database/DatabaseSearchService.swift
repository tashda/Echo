import Foundation

struct DatabaseSearchService {
    internal struct QueryConstants {
        static let maxNameResults = 50
        static let maxColumnResults = 120
    }

    private let strategy: any DatabaseSearchStrategy

    init(session: DatabaseSession, databaseType: DatabaseType, activeDatabase: String?) {
        self.strategy = DatabaseSearchService.makeStrategy(
            session: session,
            databaseType: databaseType,
            activeDatabase: activeDatabase
        )
    }

    func search(
        query: String,
        categories: Set<SearchSidebarCategory>
    ) async throws -> [SearchSidebarResult] {
        var aggregated: [SearchSidebarResult] = []
        var firstError: Error?
        var didSucceed = false

        if categories.contains(.tables) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchTables(query: query)
            }
        }

        if categories.contains(.views) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchViews(query: query)
            }
        }

        if categories.contains(.materializedViews) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchMaterializedViews(query: query)
            }
        }

        if categories.contains(.functions) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchFunctions(query: query)
            }
        }

        if categories.contains(.procedures) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchProcedures(query: query)
            }
        }

        if categories.contains(.triggers) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchTriggers(query: query)
            }
        }

        if categories.contains(.columns) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchColumns(query: query)
            }
        }

        if categories.contains(.indexes) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchIndexes(query: query)
            }
        }

        if categories.contains(.foreignKeys) {
            try Task.checkCancellation()
            await appendResults(into: &aggregated, didSucceed: &didSucceed, firstError: &firstError) {
                try await strategy.searchForeignKeys(query: query)
            }
        }

        if !didSucceed, let error = firstError {
            throw error
        }

        return aggregated.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.category.displayName.localizedCaseInsensitiveCompare(rhs.category.displayName) == .orderedAscending
        }
    }

    private func appendResults(
        into aggregated: inout [SearchSidebarResult],
        didSucceed: inout Bool,
        firstError: inout Error?,
        fetch: () async throws -> [SearchSidebarResult]
    ) async {
        do {
            let results = try await fetch()
            aggregated.append(contentsOf: results)
            didSucceed = didSucceed || !results.isEmpty
        } catch {
            if firstError == nil {
                firstError = error
            }
        }
    }

    static func makeLikePattern(_ query: String) -> String {
        var sanitized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "\\\\")
        sanitized = sanitized.replacingOccurrences(of: "%", with: "\\%")
        sanitized = sanitized.replacingOccurrences(of: "_", with: "\\_")
        sanitized = sanitized.replacingOccurrences(of: "'", with: "''")
        return sanitized
    }

    static func makeSnippet(from text: String, matching query: String, radius: Int = 80) -> String? {
        guard !text.isEmpty else { return nil }
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()
        guard let range = lowercasedText.range(of: lowercasedQuery) else { return nil }
        let lowerBound = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let upperBound = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        var snippet = String(text[lowerBound..<upperBound])
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "\r", with: " ")
        while snippet.contains("  ") {
            snippet = snippet.replacingOccurrences(of: "  ", with: " ")
        }
        snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if lowerBound > text.startIndex {
            snippet = "..." + snippet
        }
        if upperBound < text.endIndex {
            snippet += "..."
        }
        return snippet
    }

    private static func makeStrategy(
        session: DatabaseSession,
        databaseType: DatabaseType,
        activeDatabase: String?
    ) -> any DatabaseSearchStrategy {
        switch databaseType {
        case .postgresql:
            return PostgresDatabaseSearchStrategy(session: session)
        case .mysql:
            return MySQLDatabaseSearchStrategy(session: session, activeDatabase: activeDatabase)
        case .sqlite:
            return SQLiteDatabaseSearchStrategy(session: session)
        case .microsoftSQL:
            return MSSQLDatabaseSearchStrategy(session: session)
        }
    }
}

internal protocol DatabaseSearchStrategy {
    func searchTables(query: String) async throws -> [SearchSidebarResult]
    func searchViews(query: String) async throws -> [SearchSidebarResult]
    func searchMaterializedViews(query: String) async throws -> [SearchSidebarResult]
    func searchFunctions(query: String) async throws -> [SearchSidebarResult]
    func searchProcedures(query: String) async throws -> [SearchSidebarResult]
    func searchTriggers(query: String) async throws -> [SearchSidebarResult]
    func searchColumns(query: String) async throws -> [SearchSidebarResult]
    func searchIndexes(query: String) async throws -> [SearchSidebarResult]
    func searchForeignKeys(query: String) async throws -> [SearchSidebarResult]
}
