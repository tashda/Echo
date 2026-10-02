import Foundation

public struct PendingLocalChange: Sendable, Hashable {
    public let account: String
    public let collection: String
    public let id: String
    public let projectID: String
    public let revision: Int64
    public let isDelete: Bool
}

public struct LocalCollectionSnapshot: Sendable {
    public let collection: String
    public let records: [LocalRecord]
    public init(collection: String, records: [LocalRecord]) {
        self.collection = collection
        self.records = records
    }
}

public struct LocalSyncContext: Codable, Sendable {
    public let account: String
    public let projects: Set<String>
    public init(account: String, projects: Set<String>) { self.account = account; self.projects = projects }
}
