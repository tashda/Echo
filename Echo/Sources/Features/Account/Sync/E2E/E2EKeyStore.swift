import CryptoKit
import Foundation
import Security

/// Manages the E2E key hierarchy: Master Key in Keychain, Per-Project Keys in memory.
///
/// The Master Key is stored in the macOS Keychain (separate service from auth tokens).
/// Per-Project Keys are unwrapped from the server and cached in memory for the session.
/// On sign-out, all keys are cleared.
///
/// ## Security Invariants
/// - Master Key is NEVER transmitted to the server.
/// - Per-Project Keys are NEVER stored unwrapped on the server.
/// - All keys are zeroed on sign-out.
@MainActor
final class E2EKeyStore {
    private let keychainService = "dev.echodb.echo.e2e"
    private let masterKeyAccount = "master-key"

    /// In-memory cache of unwrapped Per-Project Keys, keyed by local project UUID.
    private var projectKeys: [UUID: SymmetricKey] = [:]

    /// Whether the user has unlocked with their Master Password this session.
    private(set) var isUnlocked: Bool = false

    // MARK: - Master Key

    /// Store the Master Key in Keychain after derivation.
    func storeMasterKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try deleteKeychainItem(account: masterKeyAccount)
        try addKeychainItem(account: masterKeyAccount, data: keyData)
        isUnlocked = true
    }

    /// Load the Master Key from Keychain (app launch, already enrolled).
    func loadMasterKey() -> SymmetricKey? {
        guard let data = try? loadKeychainItem(account: masterKeyAccount) else { return nil }
        isUnlocked = true
        return SymmetricKey(data: data)
    }

    /// Clear the Master Key from Keychain (sign-out or lock).
    func clearMasterKey() {
        try? deleteKeychainItem(account: masterKeyAccount)
        isUnlocked = false
    }

    // MARK: - Per-Project Keys

    /// Cache an unwrapped Per-Project Key for a given project.
    func setProjectKey(_ key: SymmetricKey, for projectID: UUID) {
        projectKeys[projectID] = key
    }

    /// Retrieve a cached Per-Project Key.
    func projectKey(for projectID: UUID) -> SymmetricKey? {
        projectKeys[projectID]
    }

    /// Clear all cached project keys (sign-out).
    func clearProjectKeys() {
        projectKeys.removeAll()
    }

    // MARK: - Full Reset

    /// Clear all E2E state. Called on sign-out.
    func clearAll() {
        clearMasterKey()
        clearProjectKeys()
    }

    // MARK: - Keychain Helpers

    private func addKeychainItem(account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw E2EError.enrollmentFailed("Keychain write failed: \(status)")
        }
    }

    private func loadKeychainItem(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw E2EError.enrollmentFailed("Keychain read failed: \(status)")
        }
        return item as? Data
    }

    private func deleteKeychainItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw E2EError.enrollmentFailed("Keychain delete failed: \(status)")
        }
    }
}
