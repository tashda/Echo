import CryptoKit
import _CryptoExtras
import Foundation

/// Bridge to Scrypt KDF from swift-crypto's _CryptoExtras.
///
/// Scrypt is a memory-hard KDF that resists GPU/ASIC brute-force attacks.
/// Parameters: N=131072 (2^17), r=8, p=1 → ~128MB memory per derivation.
/// Isolated in its own file to contain the underscore-prefixed import.
enum KDFScryptBridge: Sendable {
    static func derive(
        password: Data, salt: Data, outputByteCount: Int,
        rounds: Int, blockSize: Int, parallelism: Int
    ) throws -> SymmetricKey {
        try KDF.Scrypt.deriveKey(
            from: password,
            salt: salt,
            outputByteCount: outputByteCount,
            rounds: rounds,
            blockSize: blockSize,
            parallelism: parallelism
        )
    }
}
