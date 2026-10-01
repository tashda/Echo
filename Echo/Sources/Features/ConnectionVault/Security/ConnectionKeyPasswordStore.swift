import Foundation

/// The password of a connection's encrypted client key or .p12 file, kept in the Keychain like the
/// connection's password (Echo Labs round 23, client key: KK1). One item per connection.
enum ConnectionKeyPasswordStore {
    private static let vault = KeychainVault()

    static func account(for connectionID: UUID) -> String { "echo.sslkey.\(connectionID.uuidString)" }

    static func password(for connectionID: UUID) -> String? {
        try? vault.getPassword(account: account(for: connectionID))
    }

    /// Saves the password; nil or empty removes it.
    static func setPassword(_ password: String?, for connectionID: UUID) {
        guard let password, !password.isEmpty else {
            try? vault.deletePassword(account: account(for: connectionID))
            return
        }
        try? vault.setPassword(password, account: account(for: connectionID))
    }
}
