import Foundation

struct SavedIdentity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectID: UUID?
    var name: String
    var username: String
    var keychainIdentifier: String?
    var createdAt: Date = Date()
    var updatedAt: Date?
    var folderID: UUID?

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        name: String,
        username: String,
        keychainIdentifier: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.username = username
        self.keychainIdentifier = keychainIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderID = folderID
    }
}

extension SavedIdentity {
    static let example = SavedIdentity(
        name: "Production",
        username: "db_admin"
    )
}
