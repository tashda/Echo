import Foundation

actor ObjectBrowserCacheStore {
    struct Configuration: Sendable {
        let rootDirectory: URL
    }

    private let configuration: Configuration
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: Configuration) {
        self.configuration = configuration
        if !fileManager.fileExists(atPath: configuration.rootDirectory.path) {
            try? fileManager.createDirectory(
                at: configuration.rootDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    static func defaultRootDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("Echo", isDirectory: true)
            .appendingPathComponent("ObjectBrowserCache", isDirectory: true)
    }

    func entry(for connection: SavedConnection) async -> ObjectBrowserCacheEntry? {
        let url = cacheURL(for: ObjectBrowserCacheKey(connectionID: connection.id))
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let entry = try? decoder.decode(ObjectBrowserCacheEntry.self, from: data),
              entry.schemaVersion == ObjectBrowserCacheEntry.currentSchemaVersion,
              entry.connectionFingerprint == connection.objectBrowserCacheFingerprint else {
            return nil
        }
        return entry
    }

    func migrateLegacyCacheIfNeeded(
        from connection: SavedConnection,
        limitBytes: Int
    ) async {
        guard let legacyStructure = connection.cachedStructure else { return }
        if await entry(for: connection) != nil {
            return
        }
        let entry = ObjectBrowserCacheEntry(
            key: ObjectBrowserCacheKey(connectionID: connection.id),
            connectionFingerprint: connection.objectBrowserCacheFingerprint,
            updatedAt: connection.cachedStructureUpdatedAt ?? Date(),
            structure: legacyStructure
        )
        try? await write(entry, limitBytes: limitBytes)
    }

    func stashStructure(
        _ structure: DatabaseStructure,
        for connection: SavedConnection,
        limitBytes: Int
    ) async throws {
        let entry = ObjectBrowserCacheEntry(
            key: ObjectBrowserCacheKey(connectionID: connection.id),
            connectionFingerprint: connection.objectBrowserCacheFingerprint,
            structure: structure
        )
        try await write(entry, limitBytes: limitBytes)
    }

    func currentUsageBytes() async -> UInt64 {
        let urls = cacheFileURLs()
        return urls.reduce(into: UInt64(0)) { total, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += UInt64(values?.fileSize ?? 0)
        }
    }

    func removeAll() async {
        for url in cacheFileURLs() {
            try? fileManager.removeItem(at: url)
        }
    }

    func pruneToLimit(_ limitBytes: Int) async {
        let normalizedLimit = max(limitBytes, 64 * 1_024 * 1_024)
        var entries: [(url: URL, updatedAt: Date, size: Int)] = cacheFileURLs().compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let entry = try? decoder.decode(ObjectBrowserCacheEntry.self, from: data) else {
                return nil
            }
            return (url, entry.updatedAt, data.count)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > normalizedLimit else { return }

        entries.sort { $0.updatedAt < $1.updatedAt }
        for entry in entries where total > normalizedLimit {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private func write(_ entry: ObjectBrowserCacheEntry, limitBytes: Int) async throws {
        if !fileManager.fileExists(atPath: configuration.rootDirectory.path) {
            try fileManager.createDirectory(
                at: configuration.rootDirectory,
                withIntermediateDirectories: true
            )
        }
        let data = try encoder.encode(entry)
        try data.write(to: cacheURL(for: entry.key), options: [.atomic])
        await pruneToLimit(limitBytes)
    }

    private func cacheURL(for key: ObjectBrowserCacheKey) -> URL {
        configuration.rootDirectory
            .appendingPathComponent(key.connectionID.uuidString)
            .appendingPathExtension("json")
    }

    private func cacheFileURLs() -> [URL] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: configuration.rootDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { $0.pathExtension == "json" }
    }
}
