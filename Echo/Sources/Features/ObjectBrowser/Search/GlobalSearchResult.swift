import Foundation

/// A search result with full provenance — which server and database the result came from.
/// Used by the global multi-connection search to display grouped results.
struct GlobalSearchResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let connectionSessionID: UUID
    let serverName: String
    let databaseName: String
    let databaseType: DatabaseType
    let category: SearchSidebarCategory
    let title: String
    let subtitle: String?
    let metadata: String?
    let snippet: String?
    let payload: SearchSidebarResult.Payload?

    /// Grouping key for display: "ServerName > DatabaseName"
    var groupKey: String { "\(serverName) > \(databaseName)" }
}
