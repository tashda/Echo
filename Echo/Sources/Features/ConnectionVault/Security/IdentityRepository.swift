import Foundation

@MainActor
final class IdentityRepository: IdentityRepositoryProtocol, @unchecked Sendable {
    private let keychain = KeychainVault()
    
    // Identities are looked up in the connection store.
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
    
    func deletePassword(for connection: SavedConnection) {
        ConnectionKeyPasswordStore.setPassword(nil, for: connection.id)
        if let identifier = connection.keychainIdentifier {
            try? keychain.deletePassword(account: identifier)
        }
    }
    
    func deletePassword(for identity: SavedIdentity) {
        if let identifier = identity.keychainIdentifier {
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
        guard var configuration = resolveSignIn(for: connection, overridePassword: overridePassword) else { return nil }
        if connection.databaseType == .postgresql, connection.sslCertPath != nil {
            configuration.sslKeyPassword = ConnectionKeyPasswordStore.password(for: connection.id)
        }
        return configuration
    }

    private func resolveSignIn(for connection: SavedConnection, overridePassword: String?) -> DatabaseAuthenticationConfiguration? {
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

            let trimmedIdentityDomain = identity.domain?.trimmingCharacters(in: .whitespacesAndNewlines)
            let identityDomain = (trimmedIdentityDomain?.isEmpty == false) ? trimmedIdentityDomain : nil

            return DatabaseAuthenticationConfiguration(
                method: identity.authenticationMethod,
                username: username,
                password: password,
                domain: identityDomain
            )
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
}
