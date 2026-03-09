import Foundation
import CryptoKit
import Security

/// Manages generation and persistence of per-project diagram encryption keys.
struct DiagramEncryptionKeyStore: Sendable {
    private let keychain: KeychainVault
    private let accountPrefix = "diagram-cache-key"

    init(keychain: KeychainVault = KeychainVault()) {
        self.keychain = keychain
    }

    func symmetricKey(
        forProjectID projectID: UUID,
        generateIfNeeded: Bool = true
    ) throws -> SymmetricKey {
        let identifier = makeIdentifier(for: projectID)
        if let key = try loadKey(identifier: identifier) {
            return key
        }
        guard generateIfNeeded else {
            throw KeyError.notFound
        }
        let keyData = Self.makeRandomKeyData()
        try persist(keyData: keyData, identifier: identifier)
        return SymmetricKey(data: keyData)
    }

    func deleteKey(forProjectID projectID: UUID) {
        try? keychain.deletePassword(account: account(for: makeIdentifier(for: projectID)))
    }

    // MARK: - Private

    private func loadKey(identifier: String) throws -> SymmetricKey? {
        do {
            let base64 = try keychain.getPassword(account: account(for: identifier))
            guard let data = Data(base64Encoded: base64) else {
                try? keychain.deletePassword(account: account(for: identifier))
                return nil
            }
            return SymmetricKey(data: data)
        } catch KeychainVault.KeychainError.unexpectedStatus(let status) where status == errSecItemNotFound {
            return nil
        } catch {
            throw error
        }
    }

    private func persist(keyData: Data, identifier: String) throws {
        let base64 = keyData.base64EncodedString()
        try keychain.setPassword(base64, account: account(for: identifier))
    }

    private func makeIdentifier(for projectID: UUID) -> String {
        "\(accountPrefix).\(projectID.uuidString)"
    }

    private func account(for identifier: String) -> String {
        identifier
    }

    private static func makeRandomKeyData() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}

extension DiagramEncryptionKeyStore {
    enum KeyError: Error {
        case notFound
    }
}
