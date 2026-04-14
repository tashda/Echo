import Foundation
import CryptoKit

/// Handles encrypted persistence and retrieval of diagram cache payloads.
actor DiagramCacheStore {
    struct Configuration: Equatable, Sendable {
        var rootDirectory: URL
        var maximumBytes: UInt64

        init(rootDirectory: URL, maximumBytes: UInt64 = 512 * 1_024 * 1_024) {
            self.rootDirectory = rootDirectory
            self.maximumBytes = maximumBytes
        }
    }
    
    static func defaultRootDirectory() -> URL {
        let fm = FileManager.default
        #if os(macOS)
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        #else
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        #endif
        return base.appendingPathComponent("Echo", isDirectory: true).appendingPathComponent("DiagramCache", isDirectory: true)
    }

    private var configuration: Configuration
    private var keyProvider: (@Sendable (UUID) async throws -> SymmetricKey)?
    private let fileManager = FileManager.default

    init(configuration: Configuration) {
        self.configuration = configuration
        Self.ensureDirectoryExists(at: configuration.rootDirectory, using: fileManager)
    }

    func updateKeyProvider(_ provider: @escaping @Sendable (UUID) async throws -> SymmetricKey) {
        keyProvider = provider
    }

    func updateConfiguration(_ configuration: Configuration) {
        guard self.configuration != configuration else { return }
        self.configuration = configuration
        Self.ensureDirectoryExists(at: configuration.rootDirectory, using: fileManager)
        Task { await self.enforceSizeLimitIfNeeded() }
    }

    func stashPayload(_ payload: DiagramCachePayload) async throws {
        let url = cacheURL(for: payload.key)
        Self.ensureDirectoryExists(at: url.deletingLastPathComponent(), using: fileManager)

        let json = try await MainActor.run {
            try JSONEncoder().encode(payload)
        }
        guard let keyProvider else { throw EncryptionError.missingKeyProvider }
        let key = try await keyProvider(payload.key.projectID)
        let encrypted = try encrypt(json, with: key)

        try encrypted.write(to: url, options: .atomic)
        await enforceSizeLimitIfNeeded()
    }

    func payload(for key: DiagramCacheKey) async throws -> DiagramCachePayload? {
        let url = cacheURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let keyProvider else { throw EncryptionError.missingKeyProvider }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let symmetricKey = try await keyProvider(key.projectID)
        let decrypted = try decrypt(data, with: symmetricKey)
        return try await MainActor.run {
            try JSONDecoder().decode(DiagramCachePayload.self, from: decrypted)
        }
    }

    func removePayload(for key: DiagramCacheKey) {
        let url = cacheURL(for: key)
        try? fileManager.removeItem(at: url)
    }

    func removeAll(for projectID: UUID) {
        let directory = projectDirectory(for: projectID)
        try? fileManager.removeItem(at: directory)
    }

    func removeAll() {
        try? fileManager.removeItem(at: configuration.rootDirectory)
        Self.ensureDirectoryExists(at: configuration.rootDirectory, using: fileManager)
    }

    func listPayloads(for projectID: UUID) async -> [DiagramCachePayload] {
        let directory = projectDirectory(for: projectID)
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        guard let keyProvider, let encryptionKey = try? await keyProvider(projectID) else { return [] }
        var results: [DiagramCachePayload] = []
        for url in contents where url.pathExtension == Self.cacheExtension {
            do {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                let decrypted = try decrypt(data, with: encryptionKey)
                let payload = try await MainActor.run {
                    try JSONDecoder().decode(DiagramCachePayload.self, from: decrypted)
                }
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
        while let next = enumerator.nextObject() as? URL {
            total += Self.fileSize(for: next)
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

        while let next = enumerator.nextObject() as? URL {
            guard next.pathExtension == Self.cacheExtension else { continue }
            let size = Self.fileSize(for: next)
            let modified = (try? next.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            total += size
            items.append((next, size, modified))
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
        Self.ensureDirectoryExists(at: directory, using: fileManager)
        return directory
    }

    private static func ensureDirectoryExists(at url: URL, using fileManager: FileManager) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func totalSize(at directory: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total: UInt64 = 0
        while let next = enumerator.nextObject() as? URL {
            guard next.pathExtension == Self.cacheExtension else { continue }
            total += Self.fileSize(for: next)
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

extension DiagramCacheStore {
    enum EncryptionError: Error {
        case invalidPayload
        case missingKeyProvider
    }

    private static let cacheExtension = "diagram"
}
