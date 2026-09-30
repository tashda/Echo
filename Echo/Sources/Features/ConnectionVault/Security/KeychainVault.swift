import Foundation
import Security
import Synchronization

struct KeychainVault: Sendable {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case stringEncoding
    }

    private let serviceName = "dev.echodb.echo"

    /// Passwords already read, by account. A keychain read costs milliseconds and callers ask on
    /// the main actor (every schema load resolves its sign-in), so each account is read once.
    /// Every write in Echo goes through this type and keeps the cache current.
    private static let readPasswords = Mutex<[String: String]>([:])

    func setPassword(_ password: String, account: String) throws {
        let encoded = Data(password.utf8)

        // Delete existing item if present
        try? deletePassword(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: encoded
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        Self.readPasswords.withLock { $0[account] = password }
    }

    func getPassword(account: String) throws -> String {
        if let cached = Self.readPasswords.withLock({ $0[account] }) { return cached }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.stringEncoding
        }
        Self.readPasswords.withLock { $0[account] = string }
        return string
    }

    func deletePassword(account: String) throws {
        Self.readPasswords.withLock { _ = $0.removeValue(forKey: account) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
