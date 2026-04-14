import Foundation

struct ObjectBrowserCacheKey: Hashable, Codable, Sendable {
    let connectionID: UUID
}

struct ObjectBrowserCacheEntry: Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let key: ObjectBrowserCacheKey
    let connectionFingerprint: String
    let updatedAt: Date
    let structure: DatabaseStructure

    init(
        key: ObjectBrowserCacheKey,
        connectionFingerprint: String,
        updatedAt: Date = Date(),
        structure: DatabaseStructure
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.key = key
        self.connectionFingerprint = connectionFingerprint
        self.updatedAt = updatedAt
        self.structure = structure
    }
}
