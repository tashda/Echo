import CryptoKit
import Foundation

/// Core cryptographic operations for E2E credential sync.
///
/// All encryption uses AES-256-GCM. Key derivation uses Scrypt with enterprise-grade
/// parameters. This service is stateless — it performs operations and returns results.
///
/// ## Security Invariants
/// - Master Password is NEVER stored or transmitted.
/// - Plaintext credentials NEVER leave the device.
/// - Every nonce is unique (12 bytes from SecRandomCopyBytes).
/// - AAD binds ciphertext to its document/field context.
/// - GCM tag verification failure aborts immediately.
nonisolated struct E2ECryptoService: Sendable {

    /// Current encrypted blob format version.
    static let blobVersion: UInt8 = 0x01

    // MARK: - Key Derivation (Scrypt)

    /// Enterprise-grade Scrypt parameters.
    /// N=2^17 (131072), r=8, p=1 → ~128MB memory, ~0.5-1.5s on Apple Silicon.
    struct KDFParams: Sendable {
        let rounds: Int        // N (cost factor, must be power of 2)
        let blockSize: Int     // r
        let parallelism: Int   // p

        static let standard = KDFParams(rounds: 131_072, blockSize: 8, parallelism: 1)
    }

    /// Derive a 256-bit key from a password and salt using Scrypt.
    func deriveKey(password: String, salt: Data, params: KDFParams = .standard) throws -> SymmetricKey {
        let passwordData = Data(password.utf8)
        return try KDFScryptBridge.derive(
            password: passwordData,
            salt: salt,
            outputByteCount: 32,
            rounds: params.rounds,
            blockSize: params.blockSize,
            parallelism: params.parallelism
        )
    }

    /// Generate a cryptographically random salt.
    func generateSalt(byteCount: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return Data(bytes)
    }

    // MARK: - AES-256-GCM Encryption

    /// Encrypt plaintext data with AES-256-GCM.
    ///
    /// Returns a versioned blob: `[1B version][12B nonce][NB ciphertext][16B tag]`
    ///
    /// - Parameters:
    ///   - plaintext: The data to encrypt.
    ///   - key: 256-bit symmetric key.
    ///   - aad: Additional Authenticated Data — binds ciphertext to context.
    func encrypt(plaintext: Data, key: SymmetricKey, aad: Data) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)

        // Build versioned blob
        var blob = Data(capacity: 1 + 12 + sealed.ciphertext.count + 16)
        blob.append(Self.blobVersion)
        blob.append(contentsOf: nonce)
        blob.append(sealed.ciphertext)
        blob.append(sealed.tag)
        return blob
    }

    /// Decrypt a versioned blob with AES-256-GCM.
    ///
    /// Verifies the GCM tag and blob version. Throws on any failure — never returns partial data.
    func decrypt(blob: Data, key: SymmetricKey, aad: Data) throws -> Data {
        guard blob.count >= 1 + 12 + 16 else {
            throw E2EError.invalidBlobFormat
        }

        let version = blob[blob.startIndex]
        guard version == Self.blobVersion else {
            throw E2EError.unsupportedBlobVersion(version)
        }

        let nonceRange = blob.index(blob.startIndex, offsetBy: 1)..<blob.index(blob.startIndex, offsetBy: 13)
        let nonce = try AES.GCM.Nonce(data: blob[nonceRange])

        let ciphertextRange = blob.index(blob.startIndex, offsetBy: 13)..<blob.index(blob.endIndex, offsetBy: -16)
        let ciphertext = blob[ciphertextRange]

        let tagRange = blob.index(blob.endIndex, offsetBy: -16)..<blob.endIndex
        let tag = blob[tagRange]

        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key, authenticating: aad)
    }

    // MARK: - Key Wrapping

    /// Wrap (encrypt) an inner key with an outer key.
    /// Returns the sealed blob containing the wrapped key material.
    func wrapKey(_ innerKey: SymmetricKey, with outerKey: SymmetricKey) throws -> Data {
        let keyData = innerKey.withUnsafeBytes { Data($0) }
        let aad = Data("key-wrap".utf8)
        return try encrypt(plaintext: keyData, key: outerKey, aad: aad)
    }

    /// Unwrap (decrypt) an inner key using an outer key.
    /// Throws if the outer key is wrong (GCM tag verification failure).
    func unwrapKey(_ wrappedBlob: Data, with outerKey: SymmetricKey) throws -> SymmetricKey {
        let aad = Data("key-wrap".utf8)
        let keyData = try decrypt(blob: wrappedBlob, key: outerKey, aad: aad)
        return SymmetricKey(data: keyData)
    }

    // MARK: - Random Key Generation

    /// Generate a random 256-bit symmetric key.
    func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

}

// MARK: - E2E Errors

enum E2EError: Error, LocalizedError {
    case invalidBlobFormat
    case unsupportedBlobVersion(UInt8)
    case wrongPassword
    case notEnrolled
    case notUnlocked
    case enrollmentFailed(String)
    case recoveryFailed(String)
    case invalidMnemonic

    var errorDescription: String? {
        switch self {
        case .invalidBlobFormat: "Invalid encrypted data format."
        case .unsupportedBlobVersion(let v): "Unsupported encryption format version: \(v)."
        case .wrongPassword: "Incorrect master password."
        case .notEnrolled: "Credential sync has not been set up."
        case .notUnlocked: "Enter your master password to access encrypted credentials."
        case .enrollmentFailed(let msg): "Credential sync setup failed: \(msg)"
        case .recoveryFailed(let msg): "Recovery failed: \(msg)"
        case .invalidMnemonic: "Invalid recovery key. Please check the words and try again."
        }
    }
}
