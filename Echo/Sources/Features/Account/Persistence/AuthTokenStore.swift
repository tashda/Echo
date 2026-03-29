import Foundation
import Security

/// Persists auth tokens in the macOS Keychain and user metadata on disk.
/// Thread-safe via actor isolation.
actor AuthTokenStore {
    private let serviceName = "dk.tippr.echo.auth"
    private let userFileURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Echo", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        userFileURL = dir.appendingPathComponent("auth_user.json")
    }

    // MARK: - Tokens (Keychain)

    func saveTokens(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try deleteKeychainItem(account: "tokens")
        try addKeychainItem(account: "tokens", data: data)
    }

    func loadTokens() throws -> AuthTokens? {
        guard let data = try loadKeychainItem(account: "tokens") else { return nil }
        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func deleteTokens() throws {
        try deleteKeychainItem(account: "tokens")
    }

    // MARK: - User (Disk)

    func saveUser(_ user: AuthUser) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(user)
        try data.write(to: userFileURL, options: [.atomic])
    }

    func loadUser() throws -> AuthUser? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: userFileURL.path) else { return nil }
        let data = try Data(contentsOf: userFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthUser.self, from: data)
    }

    func deleteUser() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: userFileURL.path) {
            try fm.removeItem(at: userFileURL)
        }
    }

    /// Remove all stored auth data (tokens + user).
    func clearAll() throws {
        try deleteTokens()
        try deleteUser()
    }

    // MARK: - Keychain Helpers

    private func addKeychainItem(account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthTokenStoreError.keychainFailure(status)
        }
    }

    private func loadKeychainItem(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw AuthTokenStoreError.keychainFailure(status)
        }
        return item as? Data
    }

    private func deleteKeychainItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthTokenStoreError.keychainFailure(status)
        }
    }
}

enum AuthTokenStoreError: Error, LocalizedError {
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            return "Keychain operation failed (status \(status))."
        }
    }
}
