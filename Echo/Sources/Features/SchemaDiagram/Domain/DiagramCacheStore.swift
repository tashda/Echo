import CryptoKit
import EchoLocalStorage
import Foundation
import OSLog

/// Diagram payloads use the installation's encrypted record store. Project keys only read old files.
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
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Echo/DiagramCache", isDirectory: true)
    }

    private var configuration: Configuration
    private let storage: EncryptedRecordStore
    private var keyProvider: (@Sendable (UUID) async throws -> SymmetricKey)?
    private let logger = Logger(subsystem: "dev.echodb.echo", category: "local-storage")

    init(configuration: Configuration, storage: EncryptedRecordStore? = nil) {
        self.configuration = configuration
        self.storage = storage ?? (configuration.rootDirectory == Self.defaultRootDirectory() ? .shared :
            EncryptedRecordStore(configuration: .init(url: configuration.rootDirectory.appendingPathComponent("Cache.sqlite"))))
    }

    func updateKeyProvider(_ provider: @escaping @Sendable (UUID) async throws -> SymmetricKey) {
        keyProvider = provider
    }

    func updateConfiguration(_ configuration: Configuration) async {
        self.configuration = configuration
        await enforceSizeLimitIfNeeded()
    }

    func stashPayload(_ payload: DiagramCachePayload) async throws {
        let id = try await identifier(payload.key)
        try await storage.write(LocalRecord(collection: "diagrams", id: id, group: payload.key.projectID.uuidString,
            payload: try LocalRecordEncoding.encode(payload), isCache: true))
        await enforceSizeLimitIfNeeded()
    }

    func payload(for key: DiagramCacheKey) async throws -> DiagramCachePayload? {
        if let data = try await storage.read(collection: "diagrams", id: identifier(key)) {
            return try JSONDecoder().decode(DiagramCachePayload.self, from: data)
        }
        return try await importLegacy(url: cacheURL(key), projectID: key.projectID)
    }

    func removePayload(for key: DiagramCacheKey) async {
        do {
            try await storage.remove(collection: "diagrams", id: identifier(key))
            let url = cacheURL(key)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        } catch { logger.error("Couldn't remove diagram cache: \(error.localizedDescription)") }
    }

    func removeAll(for projectID: UUID) async {
        do {
            try await storage.remove(collection: "diagrams", group: projectID.uuidString)
            let url = configuration.rootDirectory.appendingPathComponent(projectID.uuidString)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        } catch { logger.error("Couldn't clear diagram cache: \(error.localizedDescription)") }
    }

    func removeAll() async {
        do {
            try await storage.remove(collection: "diagrams")
            let contents = (try? FileManager.default.contentsOfDirectory(at: configuration.rootDirectory,
                includingPropertiesForKeys: nil)) ?? []
            for url in contents where UUID(uuidString: url.lastPathComponent) != nil {
                try FileManager.default.removeItem(at: url)
            }
        } catch { logger.error("Couldn't clear diagram cache: \(error.localizedDescription)") }
    }

    func listPayloads(for projectID: UUID) async -> [DiagramCachePayload] {
        do {
            let directory = configuration.rootDirectory.appendingPathComponent(projectID.uuidString)
            let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for url in contents where url.pathExtension == "diagram" {
                _ = try await importLegacy(url: url, projectID: projectID)
            }
            return try await storage.records(collection: "diagrams", group: projectID.uuidString).map {
                try JSONDecoder().decode(DiagramCachePayload.self, from: $0.payload)
            }
        } catch {
            // Keep unreadable sources: a temporary Keychain failure is not corruption.
            logger.error("Diagram cache is unavailable: \(error.localizedDescription)")
            return []
        }
    }

    func currentUsageBytes(for projectID: UUID? = nil) async -> UInt64 {
        (try? await storage.usage(collection: "diagrams", group: projectID?.uuidString)) ?? 0
    }

    private func enforceSizeLimitIfNeeded() async {
        guard configuration.maximumBytes > 0 else { return }
        do { try await storage.prune(collection: "diagrams", limit: configuration.maximumBytes) }
        catch { logger.error("Couldn't prune diagram cache: \(error.localizedDescription)") }
    }

    private func identifier(_ key: DiagramCacheKey) async throws -> String {
        let data = try LocalRecordEncoding.encode(key)
        return try await storage.opaqueIdentifier(data.base64EncodedString())
    }

    private func cacheURL(_ key: DiagramCacheKey) -> URL {
        configuration.rootDirectory.appendingPathComponent(key.projectID.uuidString)
            .appendingPathComponent(key.canonicalFilename).appendingPathExtension("diagram")
    }

    private func importLegacy(url: URL, projectID: UUID) async throws -> DiagramCachePayload? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let keyProvider else { throw EncryptionError.missingKeyProvider }
        let key = try await keyProvider(projectID)
        let data = try Data(contentsOf: url)
        let sealed = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(sealed, using: key)
        let payload = try JSONDecoder().decode(DiagramCachePayload.self, from: plaintext)
        // Import without pruning until the source has been authenticated and removed.
        let id = try await identifier(payload.key)
        try await storage.write(LocalRecord(collection: "diagrams", id: id, group: projectID.uuidString,
            payload: plaintext, isCache: true))
        _ = try await storage.read(collection: "diagrams", id: id)
        try FileManager.default.removeItem(at: url)
        return payload
    }

    enum EncryptionError: Error { case invalidPayload, missingKeyProvider }
}
