import Foundation
import SwiftUI

enum DatabaseType: String, Sendable, Codable, CaseIterable {
    case postgresql = "postgresql"
    case mysql = "mysql"
    case microsoftSQL = "mssql"
    case sqlite = "sqlite"

    nonisolated var displayName: String {
        switch self {
        case .postgresql: return "PostgreSQL"
        case .mysql: return "MySQL"
        case .microsoftSQL: return "Microsoft SQL Server"
        case .sqlite: return "SQLite"
        }
    }

    nonisolated var iconName: String {
        switch self {
        case .postgresql: return "PostgreSQL"
        case .mysql: return "MySQL"
        case .microsoftSQL: return "MicrosoftSQLServer"
        case .sqlite: return "SQLite"
        }
    }

    nonisolated var usesTemplateIcon: Bool {
        switch self {
        case .postgresql, .mysql, .microsoftSQL, .sqlite:
            return false
        }
    }

    /// Whether this database type is in beta within Echo.
    nonisolated var isBeta: Bool {
        switch self {
        case .mysql: return true
        case .postgresql, .microsoftSQL, .sqlite: return false
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .postgresql, .mysql, .microsoftSQL: return "server.rack"
        case .sqlite: return "doc.database.fill"
        }
    }

    nonisolated var defaultPort: Int {
        switch self {
        case .postgresql: return 5432
        case .mysql: return 3306
        case .microsoftSQL: return 1433
        case .sqlite: return 0
        }
    }

    nonisolated var supportedAuthenticationMethods: [DatabaseAuthenticationMethod] {
        switch self {
        case .microsoftSQL:
            return [.sqlPassword, .windowsIntegrated, .accessToken]
        case .postgresql:
            return [.sqlPassword, .kerberos]
        default:
            return [.sqlPassword]
        }
    }

    nonisolated var defaultAuthenticationMethod: DatabaseAuthenticationMethod {
        supportedAuthenticationMethods.first ?? .sqlPassword
    }
}


public struct DatabaseAuthenticationConfiguration: Sendable, Hashable {
    public var method: DatabaseAuthenticationMethod
    public var username: String
    public var password: String?
    public var domain: String?
    /// The password of an encrypted client key or .p12 file (PostgreSQL), from the Keychain.
    public var sslKeyPassword: String?

    public init(method: DatabaseAuthenticationMethod = .sqlPassword, username: String, password: String?, domain: String? = nil, sslKeyPassword: String? = nil) {
        self.method = method
        self.username = username
        self.password = password
        self.domain = domain
        self.sslKeyPassword = sslKeyPassword
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

struct SavedConnection: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var projectID: UUID?
    var connectionName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var authenticationMethod: DatabaseAuthenticationMethod
    var domain: String
    var credentialSource: CredentialSource
    var identityID: UUID?
    var keychainIdentifier: String?
    var folderID: UUID?
    var useTLS: Bool
    var trustServerCertificate: Bool
    var tlsMode: TLSMode
    var sslRootCertPath: String?
    var sslCertPath: String?
    var sslKeyPath: String?
    var mssqlEncryptionMode: MSSQLEncryptionMode
    var hostNameInCertificate: String?
    var readOnlyIntent: Bool
    var allowLegacyTLS: Bool
    var connectionTimeout: TimeInterval
    /// The old Query Timeout (60 s by default). It was never applied; round 21 (M3) resets every
    /// connection to the Settings default, so it is only kept for older copies and sync.
    var queryTimeout: TimeInterval
    /// The query time limit for this connection in seconds (round 21, TW2): nil uses Settings ›
    /// Databases › Query time limit, 0 means no limit.
    var queryTimeLimit: TimeInterval?
    /// PostgreSQL servers after `host`/`port`, tried in order (Echo Labs round 23, failover: FH1).
    var additionalHosts: [ConnectionHost] = []
    /// Which of the servers to use (FT1); only meaningful with additional hosts.
    var targetSessionAttributes: PostgresConnectTo = .any
    /// Spread connections over the servers (FL1: set only by a pasted URL's load_balance_hosts).
    var loadBalanceHosts = false
    /// Kerberos service name (libpq krbsrvname); nil means "postgres".
    var kerberosServiceName: String?
    var databaseType: DatabaseType
    var serverVersion: String?
    var colorHex: String
    var logo: Data?
    var cachedStructure: DatabaseStructure?
    var cachedStructureUpdatedAt: Date?
    /// This server's own section dock (round 16): the sections shown, in order, as section
    /// keys. Nil uses its database type's dock from Settings.
    var explorerDockSections: [String]?

    static func == (lhs: SavedConnection, rhs: SavedConnection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

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
        case authenticationMethod
        case domain
        case credentialSource
        case identityID
        case keychainIdentifier
        case folderID
        case useTLS
        case trustServerCertificate
        case tlsMode
        case sslRootCertPath
        case sslCertPath
        case sslKeyPath
        case mssqlEncryptionMode
        case hostNameInCertificate
        case readOnlyIntent
        case allowLegacyTLS
        case connectionTimeout
        case queryTimeout
        case queryTimeLimit
        case additionalHosts
        case targetSessionAttributes
        case loadBalanceHosts
        case kerberosServiceName
        case databaseType
        case serverVersion
        case colorHex
        case logo
        case cachedStructure
        case cachedStructureUpdatedAt
        case explorerDockSections
    }

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        connectionName: String,
        host: String,
        port: Int,
        database: String,
        username: String,
        authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword,
        domain: String = "",
        credentialSource: CredentialSource = .manual,
        identityID: UUID? = nil,
        keychainIdentifier: String? = nil,
        folderID: UUID? = nil,
        useTLS: Bool = true,
        trustServerCertificate: Bool = false,
        tlsMode: TLSMode = .prefer,
        sslRootCertPath: String? = nil,
        sslCertPath: String? = nil,
        sslKeyPath: String? = nil,
        mssqlEncryptionMode: MSSQLEncryptionMode = .mandatory,
        hostNameInCertificate: String? = nil,
        readOnlyIntent: Bool = false,
        allowLegacyTLS: Bool = false,
        connectionTimeout: TimeInterval = 30,
        queryTimeout: TimeInterval = 60,
        queryTimeLimit: TimeInterval? = nil,
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
        self.authenticationMethod = authenticationMethod
        self.domain = domain
        self.credentialSource = credentialSource
        self.identityID = identityID
        self.keychainIdentifier = keychainIdentifier
        self.folderID = folderID
        self.useTLS = useTLS
        self.trustServerCertificate = trustServerCertificate
        self.tlsMode = tlsMode
        self.sslRootCertPath = sslRootCertPath
        self.sslCertPath = sslCertPath
        self.sslKeyPath = sslKeyPath
        self.mssqlEncryptionMode = mssqlEncryptionMode
        self.hostNameInCertificate = hostNameInCertificate
        self.readOnlyIntent = readOnlyIntent
        self.allowLegacyTLS = allowLegacyTLS
        self.connectionTimeout = connectionTimeout
        self.queryTimeout = queryTimeout
        self.queryTimeLimit = queryTimeLimit
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
        authenticationMethod = try container.decodeIfPresent(DatabaseAuthenticationMethod.self, forKey: .authenticationMethod) ?? .sqlPassword
        domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? ""
        credentialSource = try container.decodeIfPresent(CredentialSource.self, forKey: .credentialSource) ?? .manual
        identityID = try container.decodeIfPresent(UUID.self, forKey: .identityID)
        keychainIdentifier = try container.decodeIfPresent(String.self, forKey: .keychainIdentifier)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        useTLS = try container.decodeIfPresent(Bool.self, forKey: .useTLS) ?? true
        trustServerCertificate = try container.decodeIfPresent(Bool.self, forKey: .trustServerCertificate) ?? false
        tlsMode = try container.decodeIfPresent(TLSMode.self, forKey: .tlsMode) ?? .prefer
        sslRootCertPath = try container.decodeIfPresent(String.self, forKey: .sslRootCertPath)
        sslCertPath = try container.decodeIfPresent(String.self, forKey: .sslCertPath)
        sslKeyPath = try container.decodeIfPresent(String.self, forKey: .sslKeyPath)
        mssqlEncryptionMode = try container.decodeIfPresent(MSSQLEncryptionMode.self, forKey: .mssqlEncryptionMode) ?? .optional
        hostNameInCertificate = try container.decodeIfPresent(String.self, forKey: .hostNameInCertificate)
        readOnlyIntent = try container.decodeIfPresent(Bool.self, forKey: .readOnlyIntent) ?? false
        allowLegacyTLS = try container.decodeIfPresent(Bool.self, forKey: .allowLegacyTLS) ?? false
        connectionTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .connectionTimeout) ?? 30
        queryTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .queryTimeout) ?? 60
        queryTimeLimit = try container.decodeIfPresent(TimeInterval.self, forKey: .queryTimeLimit)
        additionalHosts = (try? container.decodeIfPresent([ConnectionHost].self, forKey: .additionalHosts)) ?? []
        targetSessionAttributes = (try? container.decodeIfPresent(PostgresConnectTo.self, forKey: .targetSessionAttributes)) ?? .any
        loadBalanceHosts = try container.decodeIfPresent(Bool.self, forKey: .loadBalanceHosts) ?? false
        kerberosServiceName = try container.decodeIfPresent(String.self, forKey: .kerberosServiceName)
        databaseType = try container.decodeIfPresent(DatabaseType.self, forKey: .databaseType) ?? .postgresql
        serverVersion = try container.decodeIfPresent(String.self, forKey: .serverVersion)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        logo = try container.decodeIfPresent(Data.self, forKey: .logo)
        cachedStructure = try container.decodeIfPresent(DatabaseStructure.self, forKey: .cachedStructure)
        cachedStructureUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .cachedStructureUpdatedAt)
        explorerDockSections = try? container.decodeIfPresent([String].self, forKey: .explorerDockSections)
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
        try container.encode(authenticationMethod, forKey: .authenticationMethod)
        try container.encode(domain, forKey: .domain)
        try container.encode(credentialSource, forKey: .credentialSource)
        try container.encodeIfPresent(identityID, forKey: .identityID)
        try container.encodeIfPresent(keychainIdentifier, forKey: .keychainIdentifier)
        try container.encodeIfPresent(folderID, forKey: .folderID)
        try container.encode(useTLS, forKey: .useTLS)
        try container.encode(trustServerCertificate, forKey: .trustServerCertificate)
        try container.encode(tlsMode, forKey: .tlsMode)
        try container.encodeIfPresent(sslRootCertPath, forKey: .sslRootCertPath)
        try container.encodeIfPresent(sslCertPath, forKey: .sslCertPath)
        try container.encodeIfPresent(sslKeyPath, forKey: .sslKeyPath)
        try container.encode(mssqlEncryptionMode, forKey: .mssqlEncryptionMode)
        try container.encodeIfPresent(hostNameInCertificate, forKey: .hostNameInCertificate)
        try container.encode(readOnlyIntent, forKey: .readOnlyIntent)
        try container.encode(allowLegacyTLS, forKey: .allowLegacyTLS)
        try container.encode(connectionTimeout, forKey: .connectionTimeout)
        try container.encode(queryTimeout, forKey: .queryTimeout)
        try container.encodeIfPresent(queryTimeLimit, forKey: .queryTimeLimit)
        if !additionalHosts.isEmpty { try container.encode(additionalHosts, forKey: .additionalHosts) }
        if targetSessionAttributes != .any { try container.encode(targetSessionAttributes, forKey: .targetSessionAttributes) }
        if loadBalanceHosts { try container.encode(loadBalanceHosts, forKey: .loadBalanceHosts) }
        try container.encodeIfPresent(kerberosServiceName, forKey: .kerberosServiceName)
        try container.encode(databaseType, forKey: .databaseType)
        try container.encodeIfPresent(serverVersion, forKey: .serverVersion)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(logo, forKey: .logo)
        try container.encodeIfPresent(cachedStructure, forKey: .cachedStructure)
        try container.encodeIfPresent(cachedStructureUpdatedAt, forKey: .cachedStructureUpdatedAt)
        try container.encodeIfPresent(explorerDockSections, forKey: .explorerDockSections)
    }

    static let example = SavedConnection(
        connectionName: "Local",
        host: "localhost",
        port: 5432,
        database: "postgres",
        username: "postgres",
        authenticationMethod: .sqlPassword,
        domain: "",
        credentialSource: .manual,
        useTLS: false,
        databaseType: .postgresql
    )

}

@MainActor
extension SavedConnection {
    var color: Color {
        if colorHex.isEmpty || colorHex == "default" {
            return .blue
        }
        return Color(hex: colorHex) ?? .blue
    }

    mutating func updateColor(_ color: Color) {
        colorHex = color.toHex() ?? ""
    }

    var metadataColorHex: String? {
        let trimmed = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased() == "default" { return nil }
        return trimmed
    }
}
