import Foundation
import SwiftUI

enum DatabaseType: String, Codable, CaseIterable {
    case postgresql = "postgresql"
    case mysql = "mysql"
    case microsoftSQL = "mssql"
    case sqlite = "sqlite"

    var displayName: String {
        switch self {
        case .postgresql: return "PostgreSQL"
        case .mysql: return "MySQL"
        case .microsoftSQL: return "Microsoft SQL Server"
        case .sqlite: return "SQLite"
        }
    }

    var iconName: String {
        switch self {
        case .postgresql: return "postgresql"
        case .mysql: return "mysql"
        case .microsoftSQL: return "mssql"
        case .sqlite: return "sqlite"
        }
    }

    var defaultPort: Int {
        switch self {
        case .postgresql: return 5432
        case .mysql: return 3306
        case .microsoftSQL: return 1433
        case .sqlite: return 0
        }
    }
}

enum CredentialSource: String, Codable, CaseIterable {
    case manual
    case inherit
    case identity

    var displayName: String {
        switch self {
        case .manual: return "Set Manually"
        case .inherit: return "Inherit from Folder"
        case .identity: return "Use Identity"
        }
    }
}

struct SavedConnection: Identifiable, Codable, Hashable {
    var id: UUID
    var projectID: UUID?
    var connectionName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var credentialSource: CredentialSource
    var identityID: UUID?
    var keychainIdentifier: String?
    var folderID: UUID?
    var useTLS: Bool
    var databaseType: DatabaseType
    var serverVersion: String?
    var colorHex: String
    var logo: Data?
    var cachedStructure: DatabaseStructure?
    var cachedStructureUpdatedAt: Date?

    var usesInheritedCredentials: Bool { credentialSource == .inherit }
    var usesIdentity: Bool { credentialSource == .identity && identityID != nil }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectID
        case connectionName
        case host
        case port
        case database
        case username
        case credentialSource
        case identityID
        case keychainIdentifier
        case folderID
        case useTLS
        case databaseType
        case serverVersion
        case colorHex
        case logo
        case cachedStructure
        case cachedStructureUpdatedAt
    }

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        connectionName: String,
        host: String,
        port: Int,
        database: String,
        username: String,
        credentialSource: CredentialSource = .manual,
        identityID: UUID? = nil,
        keychainIdentifier: String? = nil,
        folderID: UUID? = nil,
        useTLS: Bool = true,
        databaseType: DatabaseType = .postgresql,
        serverVersion: String? = nil,
        colorHex: String = "",
        logo: Data? = nil,
        cachedStructure: DatabaseStructure? = nil,
        cachedStructureUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.connectionName = connectionName
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.credentialSource = credentialSource
        self.identityID = identityID
        self.keychainIdentifier = keychainIdentifier
        self.folderID = folderID
        self.useTLS = useTLS
        self.databaseType = databaseType
        self.serverVersion = serverVersion
        self.colorHex = colorHex
        self.logo = logo
        self.cachedStructure = cachedStructure
        self.cachedStructureUpdatedAt = cachedStructureUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        connectionName = try container.decode(String.self, forKey: .connectionName)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        database = try container.decode(String.self, forKey: .database)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        credentialSource = try container.decodeIfPresent(CredentialSource.self, forKey: .credentialSource) ?? .manual
        identityID = try container.decodeIfPresent(UUID.self, forKey: .identityID)
        keychainIdentifier = try container.decodeIfPresent(String.self, forKey: .keychainIdentifier)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        useTLS = try container.decodeIfPresent(Bool.self, forKey: .useTLS) ?? true
        databaseType = try container.decodeIfPresent(DatabaseType.self, forKey: .databaseType) ?? .postgresql
        serverVersion = try container.decodeIfPresent(String.self, forKey: .serverVersion)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        logo = try container.decodeIfPresent(Data.self, forKey: .logo)
        cachedStructure = try container.decodeIfPresent(DatabaseStructure.self, forKey: .cachedStructure)
        cachedStructureUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .cachedStructureUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(connectionName, forKey: .connectionName)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(database, forKey: .database)
        try container.encode(username, forKey: .username)
        try container.encode(credentialSource, forKey: .credentialSource)
        try container.encodeIfPresent(identityID, forKey: .identityID)
        try container.encodeIfPresent(keychainIdentifier, forKey: .keychainIdentifier)
        try container.encodeIfPresent(folderID, forKey: .folderID)
        try container.encode(useTLS, forKey: .useTLS)
        try container.encode(databaseType, forKey: .databaseType)
        try container.encodeIfPresent(serverVersion, forKey: .serverVersion)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(logo, forKey: .logo)
        try container.encodeIfPresent(cachedStructure, forKey: .cachedStructure)
        try container.encodeIfPresent(cachedStructureUpdatedAt, forKey: .cachedStructureUpdatedAt)
    }

    static let example = SavedConnection(
        connectionName: "Local",
        host: "localhost",
        port: 5432,
        database: "postgres",
        username: "postgres",
        credentialSource: .manual,
        useTLS: false,
        databaseType: .postgresql
    )

    static func == (lhs: SavedConnection, rhs: SavedConnection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
extension SavedConnection {
    var color: Color {
        if colorHex.isEmpty || colorHex == "default" {
            return Color.accentColor
        }
        return Color(hex: colorHex) ?? Color.accentColor
    }

    mutating func updateColor(_ color: Color) {
        colorHex = color.toHex() ?? ""
    }
}
