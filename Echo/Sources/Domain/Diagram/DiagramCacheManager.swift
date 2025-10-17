import Foundation
import CryptoKit

/// Handles encrypted persistence and retrieval of diagram cache payloads.
actor DiagramCacheManager {
    struct Configuration: Equatable, Sendable {
        var rootDirectory: URL
        var maximumBytes: UInt64

        init(rootDirectory: URL, maximumBytes: UInt64 = 512 * 1_024 * 1_024) {
            self.rootDirectory = rootDirectory
            self.maximumBytes = maximumBytes
        }
    }

    private var configuration: Configuration
    private let keyProvider: @Sendable (UUID) throws -> SymmetricKey
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: Configuration, keyProvider: @escaping @Sendable (UUID) throws -> SymmetricKey) {
        self.configuration = configuration
        self.keyProvider = keyProvider
        ensureDirectoryExists(at: configuration.rootDirectory)
    }

    func updateConfiguration(_ configuration: Configuration) {
        guard self.configuration != configuration else { return }
        self.configuration = configuration
        ensureDirectoryExists(at: configuration.rootDirectory)
        Task { await self.enforceSizeLimitIfNeeded() }
    }

    func stashPayload(_ payload: DiagramCachePayload) async throws {
        let url = cacheURL(for: payload.key)
        ensureDirectoryExists(at: url.deletingLastPathComponent())

        let json = try encoder.encode(payload)
        let key = try keyProvider(payload.key.projectID)
        let encrypted = try encrypt(json, with: key)

        try encrypted.write(to: url, options: .atomic)
        await enforceSizeLimitIfNeeded()
    }

    func payload(for key: DiagramCacheKey) async throws -> DiagramCachePayload? {
        let url = cacheURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let symmetricKey = try keyProvider(key.projectID)
        let decrypted = try decrypt(data, with: symmetricKey)
        return try decoder.decode(DiagramCachePayload.self, from: decrypted)
    }

    func removePayload(for key: DiagramCacheKey) {
        let url = cacheURL(for: key)
        try? fileManager.removeItem(at: url)
    }

    func removeAll(for projectID: UUID) {
        let directory = projectDirectory(for: projectID)
        try? fileManager.removeItem(at: directory)
    }

    func listPayloads(for projectID: UUID) -> [DiagramCachePayload] {
        let directory = projectDirectory(for: projectID)
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        guard let encryptionKey = try? keyProvider(projectID) else { return [] }

        var results: [DiagramCachePayload] = []
        for url in contents where url.pathExtension == Self.cacheExtension {
            do {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                let decrypted = try decrypt(data, with: encryptionKey)
                let payload = try decoder.decode(DiagramCachePayload.self, from: decrypted)
                results.append(payload)
            } catch {
                // Best effort: remove corrupt entries.
                try? fileManager.removeItem(at: url)
            }
        }
        return results
    }

    func currentUsageBytes(for projectID: UUID? = nil) -> UInt64 {
        if let projectID {
            return totalSize(at: projectDirectory(for: projectID))
        }

        guard let enumerator = fileManager.enumerator(at: configuration.rootDirectory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total: UInt64 = 0
        for case let url as URL in enumerator {
            total += Self.fileSize(for: url)
        }
        return total
    }

    // MARK: - Helpers

    private func enforceSizeLimitIfNeeded() async {
        await enforceSizeLimit(maxBytes: configuration.maximumBytes)
    }

    private func enforceSizeLimit(maxBytes: UInt64) async {
        guard maxBytes > 0 else { return }
        guard let enumerator = fileManager.enumerator(
            at: configuration.rootDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var items: [(url: URL, size: UInt64, modified: Date)] = []
        var total: UInt64 = 0

        for case let url as URL in enumerator where url.pathExtension == Self.cacheExtension {
            let size = Self.fileSize(for: url)
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            total += size
            items.append((url, size, modified))
        }

        guard total > maxBytes else { return }

        let sorted = items.sorted { lhs, rhs in
            lhs.modified < rhs.modified
        }

        var remaining = total
        for item in sorted {
            try? fileManager.removeItem(at: item.url)
            if remaining <= maxBytes {
                break
            }
            if item.size >= remaining {
                remaining = 0
            } else {
                remaining -= item.size
            }
        }
    }

    private func cacheURL(for key: DiagramCacheKey) -> URL {
        projectDirectory(for: key.projectID)
            .appendingPathComponent(key.canonicalFilename)
            .appendingPathExtension(Self.cacheExtension)
    }

    private func projectDirectory(for projectID: UUID) -> URL {
        let directory = configuration.rootDirectory.appendingPathComponent(projectID.uuidString, isDirectory: true)
        ensureDirectoryExists(at: directory)
        return directory
    }

    private func ensureDirectoryExists(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func totalSize(at directory: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total: UInt64 = 0
        for case let url as URL in enumerator where url.pathExtension == Self.cacheExtension {
            total += Self.fileSize(for: url)
        }
        return total
    }

    private static func fileSize(for url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        if let allocated = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize {
            return UInt64(allocated)
        }
        return 0
    }

    private func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
        var result = Data()
        result.append(nonce.withUnsafeBytes { Data($0) })
        result.append(sealed.ciphertext)
        result.append(sealed.tag)
        return result
    }

    private func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        guard data.count > 12 + 16 else {
            throw EncryptionError.invalidPayload
        }

        let nonceRange = 0..<12
        let tagRange = (data.count - 16)..<data.count
        let ciphertextRange = 12..<(data.count - 16)

        let nonceData = data[nonceRange]
        let ciphertext = data[ciphertextRange]
        let tag = data[tagRange]

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealed, using: key)
    }
}

extension DiagramCacheManager {
    enum EncryptionError: Error {
        case invalidPayload
    }

    private static let cacheExtension = "diagram"
}
