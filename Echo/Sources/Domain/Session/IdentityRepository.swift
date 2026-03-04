import Foundation

@MainActor
final class IdentityRepository: IdentityRepositoryProtocol, @unchecked Sendable {
    private let keychain = KeychainVault()
    
    // We need access to these to resolve inheritance
    private let connectionStore: ConnectionStore
    
    init(connectionStore: ConnectionStore) {
        self.connectionStore = connectionStore
    }
    
    // MARK: - Password Management
    
    func password(for connection: SavedConnection) -> String? {
        guard let identifier = connection.keychainIdentifier else { return nil }
        return try? keychain.getPassword(account: identifier)
    }
    
    func password(for identity: SavedIdentity) -> String? {
        guard let identifier = identity.keychainIdentifier else { return nil }
        return try? keychain.getPassword(account: identifier)
    }
    
    func password(for folder: SavedFolder) -> String? {
        guard let identifier = folder.manualKeychainIdentifier else { return nil }
        return try? keychain.getPassword(account: identifier)
    }
    
    func setPassword(_ password: String, for connection: inout SavedConnection) throws {
        let identifier = connection.keychainIdentifier ?? "echo.\(connection.id.uuidString)"
        try keychain.setPassword(password, account: identifier)
        connection.keychainIdentifier = identifier
    }
    
    func setPassword(_ password: String, for identity: inout SavedIdentity) throws {
        let identifier = identity.keychainIdentifier ?? "echo.identity.\(identity.id.uuidString)"
        try keychain.setPassword(password, account: identifier)
        identity.keychainIdentifier = identifier
    }
    
    func setPassword(_ password: String, for folder: inout SavedFolder) throws {
        let identifier = folder.manualKeychainIdentifier ?? "echo.folder.manual.\(folder.id.uuidString)"
        try keychain.setPassword(password, account: identifier)
        folder.manualKeychainIdentifier = identifier
    }
    
    func deletePassword(for connection: SavedConnection) {
        if let identifier = connection.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }
    }
    
    func deletePassword(for identity: SavedIdentity) {
        if let identifier = identity.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }
    }
    
    func deletePassword(for folder: SavedFolder) {
        if let identifier = folder.manualKeychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }
    }
    
    // MARK: - Credential Resolution
    
    func resolveCredentials(for connection: SavedConnection, overridePassword: String?) -> ConnectionCredentials? {
        guard let config = resolveAuthenticationConfiguration(for: connection, overridePassword: overridePassword) else {
            return nil
        }
        return ConnectionCredentials(authentication: config)
    }

    func resolveAuthenticationConfiguration(for connection: SavedConnection, overridePassword: String?) -> DatabaseAuthenticationConfiguration? {
        let username: String
        let password: String?

        switch connection.credentialSource {
        case .manual:
            username = connection.username
            password = overridePassword ?? self.password(for: connection)
        case .identity:
            guard let identity = connectionStore.identities.first(where: { $0.id == connection.identityID }) else { return nil }
            username = identity.username
            password = overridePassword ?? self.password(for: identity)
        case .inherit:
            guard let folderID = connection.folderID,
                  let resolved = resolveInheritedDetails(folderID: folderID) else { return nil }
            
            username = resolved.username
            password = overridePassword ?? resolved.password
        }

        let trimmedDomain = connection.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let domain = trimmedDomain.isEmpty ? nil : trimmedDomain

        return DatabaseAuthenticationConfiguration(
            method: connection.authenticationMethod,
            username: username,
            password: password,
            domain: domain
        )
    }
    
    func resolveInheritedIdentity(folderID: UUID) -> SavedIdentity? {
        resolveInheritedIdentity(folderID: folderID, visited: [])
    }
    
    private func resolveInheritedIdentity(folderID: UUID, visited: Set<UUID>) -> SavedIdentity? {
        guard !visited.contains(folderID),
              let folder = connectionStore.folders.first(where: { $0.id == folderID }) else {
            return nil
        }
        
        switch folder.credentialMode {
        case .none, .manual:
            return nil
        case .identity:
            return connectionStore.identities.first(where: { $0.id == folder.identityID })
        case .inherit:
            guard let parentID = folder.parentFolderID else { return nil }
            var updatedVisited = visited
            updatedVisited.insert(folderID)
            return resolveInheritedIdentity(folderID: parentID, visited: updatedVisited)
        }
    }
    
    private func resolveInheritedDetails(folderID: UUID, visited: Set<UUID> = []) -> (username: String, password: String?)? {
        guard !visited.contains(folderID),
              let folder = connectionStore.folders.first(where: { $0.id == folderID }) else {
            return nil
        }
        
        switch folder.credentialMode {
        case .none:
            return nil
        case .manual:
            guard let username = folder.manualUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty else {
                return nil
            }
            return (username, self.password(for: folder))
        case .identity:
            guard let identity = connectionStore.identities.first(where: { $0.id == folder.identityID }) else { return nil }
            return (identity.username, self.password(for: identity))
        case .inherit:
            guard let parentID = folder.parentFolderID else { return nil }
            var updatedVisited = visited
            updatedVisited.insert(folderID)
            return resolveInheritedDetails(folderID: parentID, visited: updatedVisited)
        }
    }
}
