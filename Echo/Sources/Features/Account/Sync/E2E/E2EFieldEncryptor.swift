import CryptoKit
import Foundation

/// Encrypts and decrypts individual SyncField values for E2E credential sync.
///
/// Each encrypted field uses AES-256-GCM with Additional Authenticated Data (AAD)
/// that binds the ciphertext to its document context. This prevents an attacker
/// from moving encrypted blobs between fields or documents.
///
/// AAD format: `<collection>:<documentID>:<fieldName>`
nonisolated struct E2EFieldEncryptor: Sendable {
    private let crypto = E2ECryptoService()

    /// Encrypt a plaintext string into an encrypted SyncField.
    func encryptField(
        plaintext: String,
        key: SymmetricKey,
        collection: SyncCollection,
        documentID: UUID,
        fieldName: String,
        hlc: UInt64
    ) throws -> SyncField {
        let aad = buildAAD(collection: collection, documentID: documentID, fieldName: fieldName)
        let blob = try crypto.encrypt(plaintext: Data(plaintext.utf8), key: key, aad: aad)
        return SyncField(value: blob, hlc: hlc, isEncrypted: true)
    }

    /// Decrypt an encrypted SyncField back to a plaintext string.
    /// Throws if the key is wrong or the data has been tampered with.
    func decryptField(
        field: SyncField,
        key: SymmetricKey,
        collection: SyncCollection,
        documentID: UUID,
        fieldName: String
    ) throws -> String {
        guard field.isEncrypted else {
            // Not encrypted — return raw value as string
            return String(data: field.value, encoding: .utf8) ?? ""
        }
        let aad = buildAAD(collection: collection, documentID: documentID, fieldName: fieldName)
        let plaintext = try crypto.decrypt(blob: field.value, key: key, aad: aad)
        guard let string = String(data: plaintext, encoding: .utf8) else {
            throw E2EError.invalidBlobFormat
        }
        return string
    }

    // MARK: - AAD Construction

    /// Build AAD that binds ciphertext to its exact field location.
    /// Format: `<collection>:<documentID>:<fieldName>`
    private func buildAAD(collection: SyncCollection, documentID: UUID, fieldName: String) -> Data {
        Data("\(collection.rawValue):\(documentID.uuidString):\(fieldName)".utf8)
    }
}
