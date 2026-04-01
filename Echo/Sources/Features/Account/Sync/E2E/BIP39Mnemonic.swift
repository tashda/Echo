import CryptoKit
import Foundation

/// BIP-39 mnemonic generation and validation for recovery keys.
///
/// Generates a 24-word recovery phrase from 256 bits of entropy.
/// The mnemonic can be converted back to entropy for key derivation.
enum BIP39Mnemonic: Sendable {

    /// Generate a 24-word mnemonic from 256 bits of cryptographic entropy.
    static func generate() -> (words: [String], entropy: Data) {
        // 1. Generate 256 bits of entropy
        var entropy = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, 32, &entropy)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        let entropyData = Data(entropy)

        // 2. Compute SHA-256 checksum
        let hash = SHA256.hash(data: entropyData)
        let checksumByte = Array(hash)[0] // First byte = 8 bits of checksum for 256-bit entropy

        // 3. Combine entropy (256 bits) + checksum (8 bits) = 264 bits = 24 × 11-bit words
        var bits = [Bool]()
        for byte in entropy {
            for i in (0..<8).reversed() {
                bits.append((byte >> i) & 1 == 1)
            }
        }
        for i in (0..<8).reversed() {
            bits.append((checksumByte >> i) & 1 == 1)
        }

        // 4. Split into 24 groups of 11 bits and map to wordlist
        var words: [String] = []
        for i in 0..<24 {
            var index = 0
            for j in 0..<11 {
                if bits[i * 11 + j] {
                    index |= (1 << (10 - j))
                }
            }
            words.append(wordlist[index])
        }

        return (words, entropyData)
    }

    /// Validate a mnemonic and extract the 256-bit entropy.
    /// Returns nil if the mnemonic is invalid (wrong word count, unknown word, or bad checksum).
    static func toEntropy(_ words: [String]) -> Data? {
        guard words.count == 24 else { return nil }

        // Convert words to 11-bit indices
        var bits = [Bool]()
        for word in words {
            guard let index = wordlist.firstIndex(of: word.lowercased()) else { return nil }
            for i in (0..<11).reversed() {
                bits.append((index >> i) & 1 == 1)
            }
        }

        // 264 bits = 256 entropy + 8 checksum
        guard bits.count == 264 else { return nil }

        // Extract entropy bytes
        var entropy = [UInt8]()
        for i in 0..<32 {
            var byte: UInt8 = 0
            for j in 0..<8 {
                if bits[i * 8 + j] {
                    byte |= UInt8(1 << (7 - j))
                }
            }
            entropy.append(byte)
        }

        // Extract checksum bits
        var checksumByte: UInt8 = 0
        for j in 0..<8 {
            if bits[256 + j] {
                checksumByte |= UInt8(1 << (7 - j))
            }
        }

        // Verify checksum
        let entropyData = Data(entropy)
        let hash = SHA256.hash(data: entropyData)
        let expectedChecksum = Array(hash)[0]
        guard checksumByte == expectedChecksum else { return nil }

        return entropyData
    }

    /// Format a word list as a display string (4 columns × 6 rows).
    static func formatForDisplay(_ words: [String]) -> String {
        var lines: [String] = []
        for row in 0..<6 {
            var columns: [String] = []
            for col in 0..<4 {
                let idx = row * 4 + col
                columns.append("\(idx + 1). \(words[idx])")
            }
            lines.append(columns.joined(separator: "    "))
        }
        return lines.joined(separator: "\n")
    }
}
