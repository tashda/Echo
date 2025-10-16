import Foundation

actor ResultSpoolManager {
    static func defaultRootDirectory() -> URL {
        let fm = FileManager.default
        #if os(macOS)
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        #else
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        #endif
        return base.appendingPathComponent("Echo", isDirectory: true).appendingPathComponent("ResultCache", isDirectory: true)
    }

    private var configuration: ResultSpoolConfiguration
    private var handles: [UUID: ResultSpoolHandle] = [:]
    private let maintenanceQueue = DispatchQueue(label: "com.fuzee.resultSpool.maintenance", qos: .utility)
    private var maintenanceTask: Task<Void, Never>?

    init(configuration: ResultSpoolConfiguration) {
        self.configuration = configuration
        Self.ensureDirectoryExists(configuration.rootDirectory)
        maintenanceTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.performMaintenance()
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

    func makeSpoolHandle() throws -> ResultSpoolHandle {
        let id = UUID()
        let directory = configuration.rootDirectory.appendingPathComponent(id.uuidString)
        let handle = try ResultSpoolHandle(id: id, directory: directory, configuration: configuration)
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
                try? fm.removeItem(at: url)
            }
        } catch {
            print("ResultSpoolManager: Failed to clear cache \(error)")
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
        maintenanceTask = Task.detached { [weak self] in
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
        maintenanceQueue.async { [weak self] in
            Task { await self?.enforceSizeLimit() }
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
            await closeHandle(for: id)
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func ensureDirectoryExists(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("ResultSpoolManager: Failed to create cache directory \(error)")
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
