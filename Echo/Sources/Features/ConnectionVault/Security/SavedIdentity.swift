import Foundation

struct SavedIdentity: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var projectID: UUID?
    var name: String
    var identityDescription: String?
    var authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword
    var username: String
    var domain: String?
    var keychainIdentifier: String?
    var createdAt: Date = Date()
    var updatedAt: Date?
    var folderID: UUID?

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        name: String,
        identityDescription: String? = nil,
        authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword,
        username: String,
        domain: String? = nil,
        keychainIdentifier: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.identityDescription = identityDescription
        self.authenticationMethod = authenticationMethod
        self.username = username
        self.domain = domain
        self.keychainIdentifier = keychainIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderID = folderID
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        name = try container.decode(String.self, forKey: .name)
        identityDescription = try container.decodeIfPresent(String.self, forKey: .identityDescription)
        authenticationMethod = try container.decodeIfPresent(DatabaseAuthenticationMethod.self, forKey: .authenticationMethod) ?? .sqlPassword
        username = try container.decode(String.self, forKey: .username)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        keychainIdentifier = try container.decodeIfPresent(String.self, forKey: .keychainIdentifier)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
    }
}

extension SavedIdentity {
    static let example = SavedIdentity(
        name: "Production",
        username: "db_admin"
    )
}
