import Foundation
import CryptoKit

enum ClipboardHistoryPersistor {
    static func makeSaveWorkItem(
        archive: ClipboardHistoryArchive,
        key: SymmetricKey,
        historyURL: URL,
        crypto: ClipboardHistoryCrypto
    ) -> DispatchWorkItem {
        DispatchWorkItem {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted]
                let plain = try encoder.encode(archive)
                let encrypted = try crypto.encrypt(plain, using: key)
                try encrypted.write(to: historyURL, options: .atomic)
            } catch {
                print("Failed to persist clipboard history: \(error)")
            }
        }
    }
}

struct ClipboardHistoryCrypto {
    enum Error: Swift.Error {
        case invalidEnvelope
        case unsupportedVersion(found: UInt8)
        case missingCombinedData
    }

    private static let envelopeMagic = Data("ECHC".utf8)
    private static let envelopeVersion: UInt8 = 1
    private static let authenticationData = Data("EchoClipboardHistory".utf8)

    func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: Self.authenticationData)
        guard let combined = sealed.combined else { throw Error.missingCombinedData }

        var envelope = Data()
        envelope.append(Self.envelopeMagic)
        envelope.append(Self.envelopeVersion)
        envelope.append(combined)
        return envelope
    }

    func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let headerLength = Self.envelopeMagic.count
        guard data.count > headerLength + 1, data.starts(with: Self.envelopeMagic) else { throw Error.invalidEnvelope }

        let version = data[headerLength]
        guard version == Self.envelopeVersion else { throw Error.unsupportedVersion(found: version) }

        let combined = Data(data.dropFirst(headerLength + 1))
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key, authenticating: Self.authenticationData)
    }
}
