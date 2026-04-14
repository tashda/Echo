import XCTest
import CryptoKit
@testable import Echo

final class ClipboardHistoryCryptoTests: XCTestCase {
    private let crypto = ClipboardHistoryCrypto()

    // MARK: - Round-Trip

    func testEncryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Hello, Echo clipboard!".utf8)

        let encrypted = try crypto.encrypt(plaintext, using: key)
        let decrypted = try crypto.decrypt(encrypted, using: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptLargeData() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data(repeating: 0xAB, count: 1_000_000)

        let encrypted = try crypto.encrypt(plaintext, using: key)
        let decrypted = try crypto.decrypt(encrypted, using: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - Wrong Key

    func testWrongKeyFailsDecryption() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let plaintext = Data("secret data".utf8)

        let encrypted = try crypto.encrypt(plaintext, using: key1)

        XCTAssertThrowsError(try crypto.decrypt(encrypted, using: key2))
    }

    // MARK: - Invalid Envelope

    func testInvalidEnvelopeMagicBytes() {
        let key = SymmetricKey(size: .bits256)
        let badData = Data("BADD\u{01}somegarbagedata".utf8)

        do {
            _ = try crypto.decrypt(badData, using: key)
            XCTFail("Expected invalidEnvelope error")
        } catch let error as ClipboardHistoryCrypto.Error {
            if case .invalidEnvelope = error {
                // Expected
            } else {
                XCTFail("Expected invalidEnvelope, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testUnsupportedVersion() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("test".utf8)

        var encrypted = try crypto.encrypt(plaintext, using: key)

        // Replace version byte (offset 4) with unsupported version
        encrypted[4] = 0xFF

        do {
            _ = try crypto.decrypt(encrypted, using: key)
            XCTFail("Expected unsupportedVersion error")
        } catch let error as ClipboardHistoryCrypto.Error {
            if case .unsupportedVersion(let found) = error {
                XCTAssertEqual(found, 0xFF)
            } else {
                XCTFail("Expected unsupportedVersion, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Empty Data

    func testTooShortDataThrowsInvalidEnvelope() {
        let key = SymmetricKey(size: .bits256)
        let shortData = Data([0x01, 0x02])

        XCTAssertThrowsError(try crypto.decrypt(shortData, using: key))
    }
}
