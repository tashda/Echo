import Foundation
import EchoLocalStorage

actor ResultSpooler {
    static func defaultRootDirectory() -> URL {
        let fm = FileManager.default
        #if os(macOS)
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        #else
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        #endif
        return base.appendingPathComponent("Echo", isDirectory: true).appendingPathComponent("ResultCache", isDirectory: true)
    }

    private let storage: EncryptedRecordStore
    private var configuration: ResultSpoolConfiguration
    private var handles: [UUID: ResultSpoolHandle] = [:]
    private var maintenanceTask: Task<Void, Never>?

    init(configuration: ResultSpoolConfiguration, storage: EncryptedRecordStore = .shared) {
        self.storage = storage
        self.configuration = configuration
        Self.ensureDirectoryExists(configuration.rootDirectory)
        self.maintenanceTask = nil
        Task { [weak self] in
            await self?.scheduleMaintenance()
        }
    }

    deinit {
        maintenanceTask?.cancel()
    }

    func update(configuration newConfiguration: ResultSpoolConfiguration) async {
        guard configuration != newConfiguration else { return }
        configuration = newConfiguration
        Self.ensureDirectoryExists(configuration.rootDirectory)
        scheduleMaintenance()
    }

    func makeSpoolHandle() async throws -> ResultSpoolHandle {
        let encryption = try await storage.encryptionContext()
        let id = UUID()
        let directory = configuration.rootDirectory.appendingPathComponent(id.uuidString)
        let handle = try ResultSpoolHandle(id: id, directory: directory, configuration: configuration, encryption: encryption, storage: storage)
        handles[id] = handle
        enforceSizeLimitAsync()
        return handle
    }

    func handle(for id: UUID) -> ResultSpoolHandle? {
        handles[id]
    }

    func closeHandle(for id: UUID) async {
        guard let handle = handles.removeValue(forKey: id) else { return }
        await handle.close()
    }

    func removeSpool(for id: UUID) async {
        await closeHandle(for: id)
        let directory = configuration.rootDirectory.appendingPathComponent(id.uuidString)
        try? FileManager.default.removeItem(at: directory)
        await removeArchives(id)
    }

    func clearAll() async {
        for id in handles.keys {
            await closeHandle(for: id)
        }
        handles.removeAll()
        do {
            let fm = FileManager.default
            let contents = try fm.contentsOfDirectory(at: configuration.rootDirectory, includingPropertiesForKeys: nil, options: [])
            for url in contents {
                if let id = UUID(uuidString: url.lastPathComponent) { await removeArchives(id) }
                try? fm.removeItem(at: url)
            }
        } catch {
            print("ResultSpooler: Failed to clear cache \(error)")
        }
    }

    func currentUsageBytes() -> UInt64 {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: configuration.rootDirectory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: [])) ?? []
        var total: UInt64 = 0
        for url in urls {
            total += Self.directoryTotalAllocatedSize(at: url)
        }
        return total
    }

    // MARK: - Maintenance

    private func scheduleMaintenance() {
        maintenanceTask?.cancel()
        self.maintenanceTask = Task(name: "Maintain result cache") { [weak self] in
            guard let self else { return }
            await self.performMaintenance()
        }
    }

    private func performMaintenance() async {
        await pruneExpiredSpools()
        await enforceSizeLimit()
    }

    private func pruneExpiredSpools() async {
        let retention = configuration.retentionInterval
        guard retention > 0 else { return }
        let fm = FileManager.default
        let directory = configuration.rootDirectory
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { return }
        let expirationDate = Date().addingTimeInterval(-retention)

        for url in contents {
            guard let attributes = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = attributes.contentModificationDate else { continue }
            if modified < expirationDate {
                await removeSpoolDirectory(url)
            }
        }
    }

    private func enforceSizeLimitAsync() {
        Task { [weak self] in
            await self?.enforceSizeLimit()
        }
    }

    private func enforceSizeLimit() async {
        await enforceSizeLimit(maxBytes: configuration.maximumBytes)
    }

    private func enforceSizeLimit(maxBytes: UInt64) async {
        guard maxBytes > 0 else { return }
        let fm = FileManager.default
        let directory = configuration.rootDirectory
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .contentModificationDateKey], options: .skipsHiddenFiles) else { return }
        var items: [(url: URL, size: UInt64, modified: Date)] = []
        var total: UInt64 = 0

        for url in contents {
            let size = Self.directoryTotalAllocatedSize(at: url)
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            total += size
            items.append((url, size, modified))
        }

        guard total > maxBytes else { return }
        let sorted = items.sorted { $0.modified < $1.modified }
        var bytesToFree = total - maxBytes

        for item in sorted {
            if let id = UUID(uuidString: item.url.lastPathComponent), handles[id] != nil { continue }
            await removeSpoolDirectory(item.url)
            if item.size >= bytesToFree {
                break
            } else {
                bytesToFree -= item.size
            }
        }
    }

    private func removeSpoolDirectory(_ url: URL) async {
        let id = UUID(uuidString: url.lastPathComponent)
        if let id {
            guard handles[id] == nil else { return }
            await removeArchives(id)
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func removeArchives(_ id: UUID) async {
        try? await storage.remove(collection: "result-metadata", id: id.uuidString)
        try? await storage.remove(collection: "result-stats", id: id.uuidString)
    }

    private static func ensureDirectoryExists(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            print("ResultSpooler: Failed to create cache directory \(error)")
        }
    }

    private static func directoryTotalAllocatedSize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey], options: [], errorHandler: nil) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) {
                if let value = resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize {
                    total += UInt64(value)
                }
            }
        }
        return total
    }
}
