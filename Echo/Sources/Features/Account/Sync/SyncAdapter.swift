import Foundation

/// Converts between Echo domain models and SyncDocument format.
///
/// Each domain object becomes a SyncDocument whose `fields` dictionary
/// contains one entry per syncable property. Field values are JSON-encoded.
/// Credentials (passwords, keychain identifiers) are excluded in Phase 2.
struct SyncAdapter: Sendable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Connection ↔ SyncDocument

    func toSyncDocument(_ connection: SavedConnection, hlc: UInt64) throws -> SyncDocument {
        let projectID = connection.projectID ?? UUID()
        var fields: [String: SyncField] = [:]

        fields["connectionName"] = try field(connection.connectionName, hlc: hlc)
        fields["host"] = try field(connection.host, hlc: hlc)
        fields["port"] = try field(connection.port, hlc: hlc)
        fields["database"] = try field(connection.database, hlc: hlc)
        fields["username"] = try field(connection.username, hlc: hlc)
        fields["authenticationMethod"] = try field(connection.authenticationMethod, hlc: hlc)
        fields["domain"] = try field(connection.domain, hlc: hlc)
        fields["credentialSource"] = try field(connection.credentialSource, hlc: hlc)
        fields["identityID"] = try field(connection.identityID, hlc: hlc)
        fields["folderID"] = try field(connection.folderID, hlc: hlc)
        fields["useTLS"] = try field(connection.useTLS, hlc: hlc)
        fields["trustServerCertificate"] = try field(connection.trustServerCertificate, hlc: hlc)
        fields["tlsMode"] = try field(connection.tlsMode, hlc: hlc)
        fields["sslRootCertPath"] = try field(connection.sslRootCertPath, hlc: hlc)
        fields["sslCertPath"] = try field(connection.sslCertPath, hlc: hlc)
        fields["sslKeyPath"] = try field(connection.sslKeyPath, hlc: hlc)
        fields["mssqlEncryptionMode"] = try field(connection.mssqlEncryptionMode, hlc: hlc)
        fields["readOnlyIntent"] = try field(connection.readOnlyIntent, hlc: hlc)
        fields["connectionTimeout"] = try field(connection.connectionTimeout, hlc: hlc)
        fields["queryTimeout"] = try field(connection.queryTimeout, hlc: hlc)
        fields["databaseType"] = try field(connection.databaseType, hlc: hlc)
        fields["colorHex"] = try field(connection.colorHex, hlc: hlc)

        // Excluded from sync (Phase 2): keychainIdentifier, logo, cachedStructure,
        // cachedStructureUpdatedAt, serverVersion — these are local-only.

        return SyncDocument(
            id: connection.id,
            collection: .connections,
            projectID: projectID,
            fields: fields
        )
    }

    func applyToConnection(_ doc: SyncDocument, existing: SavedConnection?) throws -> SavedConnection {
        var conn = existing ?? SavedConnection(
            id: doc.id,
            projectID: doc.projectID,
            connectionName: "",
            host: "",
            port: 5432,
            database: "",
            username: ""
        )
        conn.projectID = doc.projectID

        if let v: String = try value(doc, "connectionName") { conn.connectionName = v }
        if let v: String = try value(doc, "host") { conn.host = v }
        if let v: Int = try value(doc, "port") { conn.port = v }
        if let v: String = try value(doc, "database") { conn.database = v }
        if let v: String = try value(doc, "username") { conn.username = v }
        if let v: DatabaseAuthenticationMethod = try value(doc, "authenticationMethod") { conn.authenticationMethod = v }
        if let v: String = try value(doc, "domain") { conn.domain = v }
        if let v: CredentialSource = try value(doc, "credentialSource") { conn.credentialSource = v }
        if let v: UUID? = try optionalValue(doc, "identityID") { conn.identityID = v }
        if let v: UUID? = try optionalValue(doc, "folderID") { conn.folderID = v }
        if let v: Bool = try value(doc, "useTLS") { conn.useTLS = v }
        if let v: Bool = try value(doc, "trustServerCertificate") { conn.trustServerCertificate = v }
        if let v: TLSMode = try value(doc, "tlsMode") { conn.tlsMode = v }
        if let v: String? = try optionalValue(doc, "sslRootCertPath") { conn.sslRootCertPath = v }
        if let v: String? = try optionalValue(doc, "sslCertPath") { conn.sslCertPath = v }
        if let v: String? = try optionalValue(doc, "sslKeyPath") { conn.sslKeyPath = v }
        if let v: MSSQLEncryptionMode = try value(doc, "mssqlEncryptionMode") { conn.mssqlEncryptionMode = v }
        if let v: Bool = try value(doc, "readOnlyIntent") { conn.readOnlyIntent = v }
        if let v: TimeInterval = try value(doc, "connectionTimeout") { conn.connectionTimeout = v }
        if let v: TimeInterval = try value(doc, "queryTimeout") { conn.queryTimeout = v }
        if let v: DatabaseType = try value(doc, "databaseType") { conn.databaseType = v }
        if let v: String = try value(doc, "colorHex") { conn.colorHex = v }

        return conn
    }

    // MARK: - Folder ↔ SyncDocument

    func toSyncDocument(_ folder: SavedFolder, hlc: UInt64) throws -> SyncDocument {
        let projectID = folder.projectID ?? UUID()
        var fields: [String: SyncField] = [:]

        fields["name"] = try field(folder.name, hlc: hlc)
        fields["folderDescription"] = try field(folder.folderDescription, hlc: hlc)
        fields["icon"] = try field(folder.icon, hlc: hlc)
        fields["parentFolderID"] = try field(folder.parentFolderID, hlc: hlc)
        fields["colorHex"] = try field(folder.colorHex, hlc: hlc)
        fields["kind"] = try field(folder.kind, hlc: hlc)
        fields["credentialMode"] = try field(folder.credentialMode, hlc: hlc)
        fields["identityID"] = try field(folder.identityID, hlc: hlc)
        fields["createdAt"] = try field(folder.createdAt, hlc: hlc)

        // children are not synced — they are reconstructed from folderID references

        return SyncDocument(
            id: folder.id,
            collection: .folders,
            projectID: projectID,
            fields: fields
        )
    }

    func applyToFolder(_ doc: SyncDocument, existing: SavedFolder?) throws -> SavedFolder {
        var folder = existing ?? SavedFolder(name: "", projectID: doc.projectID)
        folder.id = doc.id
        folder.projectID = doc.projectID

        if let v: String = try value(doc, "name") { folder.name = v }
        if let v: String? = try optionalValue(doc, "folderDescription") { folder.folderDescription = v }
        if let v: String = try value(doc, "icon") { folder.icon = v }
        if let v: UUID? = try optionalValue(doc, "parentFolderID") { folder.parentFolderID = v }
        if let v: String = try value(doc, "colorHex") { folder.colorHex = v }
        if let v: FolderKind = try value(doc, "kind") { folder.kind = v }
        if let v: FolderCredentialMode = try value(doc, "credentialMode") { folder.credentialMode = v }
        if let v: UUID? = try optionalValue(doc, "identityID") { folder.identityID = v }
        if let v: Date = try value(doc, "createdAt") { folder.createdAt = v }

        return folder
    }

    // MARK: - Identity ↔ SyncDocument

    func toSyncDocument(_ identity: SavedIdentity, hlc: UInt64) throws -> SyncDocument {
        let projectID = identity.projectID ?? UUID()
        var fields: [String: SyncField] = [:]

        fields["name"] = try field(identity.name, hlc: hlc)
        fields["identityDescription"] = try field(identity.identityDescription, hlc: hlc)
        fields["authenticationMethod"] = try field(identity.authenticationMethod, hlc: hlc)
        fields["username"] = try field(identity.username, hlc: hlc)
        fields["domain"] = try field(identity.domain, hlc: hlc)
        fields["folderID"] = try field(identity.folderID, hlc: hlc)
        fields["createdAt"] = try field(identity.createdAt, hlc: hlc)
        fields["updatedAt"] = try field(identity.updatedAt, hlc: hlc)

        // keychainIdentifier is excluded — credentials stay in local Keychain (Phase 2)

        return SyncDocument(
            id: identity.id,
            collection: .identities,
            projectID: projectID,
            fields: fields
        )
    }

    func applyToIdentity(_ doc: SyncDocument, existing: SavedIdentity?) throws -> SavedIdentity {
        var identity = existing ?? SavedIdentity(
            id: doc.id,
            projectID: doc.projectID,
            name: "",
            username: ""
        )
        identity.projectID = doc.projectID

        if let v: String = try value(doc, "name") { identity.name = v }
        if let v: String? = try optionalValue(doc, "identityDescription") { identity.identityDescription = v }
        if let v: DatabaseAuthenticationMethod = try value(doc, "authenticationMethod") { identity.authenticationMethod = v }
        if let v: String = try value(doc, "username") { identity.username = v }
        if let v: String? = try optionalValue(doc, "domain") { identity.domain = v }
        if let v: UUID? = try optionalValue(doc, "folderID") { identity.folderID = v }
        if let v: Date = try value(doc, "createdAt") { identity.createdAt = v }
        if let v: Date? = try optionalValue(doc, "updatedAt") { identity.updatedAt = v }

        return identity
    }

    // MARK: - Project ↔ SyncDocument

    func toSyncDocument(_ project: Project, hlc: UInt64) throws -> SyncDocument {
        var fields: [String: SyncField] = [:]

        fields["name"] = try field(project.name, hlc: hlc)
        fields["colorHex"] = try field(project.colorHex, hlc: hlc)
        fields["iconName"] = try field(project.iconName, hlc: hlc)
        fields["isDefault"] = try field(project.isDefault, hlc: hlc)
        fields["createdAt"] = try field(project.createdAt, hlc: hlc)
        fields["updatedAt"] = try field(project.updatedAt, hlc: hlc)

        // settings and bookmarks are synced as separate collections
        // projectGlobalSettings will be synced as a settings document

        return SyncDocument(
            id: project.id,
            collection: .projects,
            projectID: project.id,
            fields: fields
        )
    }

    func applyToProject(_ doc: SyncDocument, existing: Project?) throws -> Project {
        var project = existing ?? Project(
            id: doc.id,
            name: ""
        )

        if let v: String = try value(doc, "name") { project.name = v }
        if let v: String = try value(doc, "colorHex") { project.colorHex = v }
        if let v: String? = try optionalValue(doc, "iconName") { project.iconName = v }
        if let v: Bool = try value(doc, "isDefault") { project.isDefault = v }
        if let v: Date = try value(doc, "createdAt") { project.createdAt = v }
        if let v: Date = try value(doc, "updatedAt") { project.updatedAt = v }

        return project
    }

    // MARK: - Bookmark ↔ SyncDocument

    func toSyncDocument(_ bookmark: Bookmark, projectID: UUID, hlc: UInt64) throws -> SyncDocument {
        var fields: [String: SyncField] = [:]

        fields["connectionID"] = try field(bookmark.connectionID, hlc: hlc)
        fields["databaseName"] = try field(bookmark.databaseName, hlc: hlc)
        fields["title"] = try field(bookmark.title, hlc: hlc)
        fields["query"] = try field(bookmark.query, hlc: hlc)
        fields["source"] = try field(bookmark.source, hlc: hlc)
        fields["createdAt"] = try field(bookmark.createdAt, hlc: hlc)
        fields["updatedAt"] = try field(bookmark.updatedAt, hlc: hlc)

        return SyncDocument(
            id: bookmark.id,
            collection: .bookmarks,
            projectID: projectID,
            fields: fields
        )
    }

    func applyToBookmark(_ doc: SyncDocument, existing: Bookmark?) throws -> Bookmark {
        var bookmark = existing ?? Bookmark(
            id: doc.id,
            connectionID: UUID(),
            databaseName: nil,
            title: nil,
            query: "",
            source: .savedQuery
        )

        if let v: UUID = try value(doc, "connectionID") { bookmark.connectionID = v }
        if let v: String? = try optionalValue(doc, "databaseName") { bookmark.databaseName = v }
        if let v: String? = try optionalValue(doc, "title") { bookmark.title = v }
        if let v: String = try value(doc, "query") { bookmark.query = v }
        if let v: Bookmark.Source = try value(doc, "source") { bookmark.source = v }
        if let v: Date = try value(doc, "createdAt") { bookmark.createdAt = v }
        if let v: Date? = try optionalValue(doc, "updatedAt") { bookmark.updatedAt = v }

        return bookmark
    }

    // MARK: - Settings ↔ SyncDocument

    /// Settings are synced as a single blob per project. The document ID is the project ID
    /// (one settings document per project). This avoids field-by-field mapping and
    /// automatically picks up new settings fields.
    func toSyncDocument(settings: GlobalSettings, projectID: UUID, hlc: UInt64) throws -> SyncDocument {
        var fields: [String: SyncField] = [:]
        fields["payload"] = try field(settings, hlc: hlc)

        return SyncDocument(
            id: settingsDocumentID(for: projectID),
            collection: .settings,
            projectID: projectID,
            fields: fields
        )
    }

    func applyToSettings(_ doc: SyncDocument, existing: GlobalSettings?) throws -> GlobalSettings {
        guard let payload: GlobalSettings = try value(doc, "payload") else {
            return existing ?? GlobalSettings()
        }
        return payload
    }

    /// Deterministic ID for a project's settings document.
    func settingsDocumentID(for projectID: UUID) -> UUID {
        // Use a namespace UUID derived from the project ID so it's stable
        let input = "settings:\(projectID.uuidString)"
        let hash = Array(input.utf8).withUnsafeBufferPointer { buffer -> [UInt8] in
            var result = [UInt8](repeating: 0, count: 16)
            for (i, byte) in buffer.enumerated() {
                result[i % 16] ^= byte
            }
            return result
        }
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3],
                           hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11],
                           hash[12], hash[13], hash[14], hash[15]))
    }

    // MARK: - Field Helpers

    private func field<T: Encodable>(_ value: T, hlc: UInt64) throws -> SyncField {
        let data = try encoder.encode(value)
        return SyncField(value: data, hlc: hlc)
    }

    private func value<T: Decodable>(_ doc: SyncDocument, _ key: String) throws -> T? {
        guard let syncField = doc.fields[key] else { return nil }
        return try decoder.decode(T.self, from: syncField.value)
    }

    private func optionalValue<T: Decodable>(_ doc: SyncDocument, _ key: String) throws -> T?? {
        guard let syncField = doc.fields[key] else { return nil }
        // The outer Optional indicates "field exists", inner indicates the decoded value
        let decoded = try decoder.decode(T?.self, from: syncField.value)
        return .some(decoded)
    }
}
