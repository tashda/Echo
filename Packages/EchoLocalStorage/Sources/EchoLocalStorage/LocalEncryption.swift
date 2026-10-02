import CryptoKit
import Foundation
import Security

public struct LocalEncryption: Sendable {
    private let key: SymmetricKey
    private static let header = Data([0x45, 0x43, 0x48, 0x4C, 1])

    public init(key: SymmetricKey) { self.key = key }

    /// Never create a replacement when the Keychain is locked, access is denied, or data exists.
    public static func load(service: String = "dev.echodb.echo.local-storage",
                            account: String = "installation-key", allowCreation: Bool) throws -> LocalEncryption {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: account]
        var readQuery = query
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data, data.count == 32 else { throw LocalStorageError.invalidKey }
            return LocalEncryption(key: SymmetricKey(data: data))
        }
        guard status == errSecItemNotFound else { throw LocalStorageError.keychain(status) }
        guard allowCreation else { throw LocalStorageError.missingKey }
        let key = SymmetricKey(size: .bits256)
        var addQuery = query
        addQuery[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        let added = SecItemAdd(addQuery as CFDictionary, nil)
        if added == errSecDuplicateItem {
            return try load(service: service, account: account, allowCreation: false)
        }
        guard added == errSecSuccess else { throw LocalStorageError.keychain(added) }
        return LocalEncryption(key: key)
    }

    public func seal(_ plaintext: Data, context: String) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key,
                                    authenticating: Self.header + Data(context.utf8))
        guard let combined = sealed.combined else { throw LocalStorageError.invalidEnvelope }
        return Self.header + combined
    }

    public func open(_ envelope: Data, context: String) throws -> Data {
        guard envelope.count >= Self.header.count + 28,
              envelope.prefix(4) == Self.header.prefix(4) else { throw LocalStorageError.invalidEnvelope }
        guard envelope[4] == 1 else { throw LocalStorageError.unsupportedVersion }
        let sealed = try AES.GCM.SealedBox(combined: envelope.dropFirst(Self.header.count))
        return try AES.GCM.open(sealed, using: key, authenticating: Self.header + Data(context.utf8))
    }

    public func identifier(for value: String) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: key)
            .map { String(format: "%02x", $0) }.joined()
    }

    func digest(_ value: Data) -> Data { Data(HMAC<SHA256>.authenticationCode(for: value, using: key)) }
}
