import SwiftUI
import CryptoKit

@Observable
final class ClipboardHistoryStore {
    typealias UsageBreakdown = ClipboardHistoryUsageBreakdown
    typealias Entry = ClipboardHistoryEntry

    @ObservationIgnored private static let archiveVersion = 1
    @ObservationIgnored private static let storageLimitDefaultsKey = "clipboardHistoryStorageLimit"
    @ObservationIgnored private static let enabledDefaultsKey = "clipboardHistoryEnabled"
    @ObservationIgnored private static let defaultStorageLimit = 1 * 1_024 * 1_024 * 1_024 // 1 GB
    @ObservationIgnored private static let minimumStorageLimit = 256 * 1_024 * 1_024
    @ObservationIgnored private static let maximumStorageLimit = 10 * 1_024 * 1_024 * 1_024

    @ObservationIgnored private let crypto = ClipboardHistoryCrypto()
    @ObservationIgnored private let historyURL: URL
    @ObservationIgnored private let legacyHistoryURL: URL
    @ObservationIgnored private let encryptionKey: SymmetricKey
    @ObservationIgnored private let saveQueue = DispatchQueue(label: "com.fuzee.clipboardHistory.save", qos: .utility)
    @ObservationIgnored private var pendingSaveWorkItem: DispatchWorkItem?

    private(set) var entries: [Entry] = []
    var lastCopiedEntryID: UUID?
    private(set) var usage: UsageBreakdown = UsageBreakdown()
    private(set) var storageLimit: Int
    var isEnabled: Bool

    init() {
        let urls = ClipboardHistoryStore.makeHistoryURLs()
        self.historyURL = urls.encrypted
        self.legacyHistoryURL = urls.legacy
        self.encryptionKey = crypto.loadOrCreateKey()
        let storedLimit = (UserDefaults.standard.object(forKey: Self.storageLimitDefaultsKey) as? Int)
        self.storageLimit = Self.clampStorageLimit(storedLimit ?? Self.defaultStorageLimit)
        let storedEnabled = (UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool)
        self.isEnabled = storedEnabled ?? true

        if isEnabled { loadFromDisk() }
        else { clearHistoryFromMemory(); removePersistedHistory() }
    }

    deinit { pendingSaveWorkItem?.cancel() }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)
        if enabled { loadFromDisk() } else { clearHistory(removeFromDisk: true) }
    }

    func clearHistory(removeFromDisk: Bool = true) {
        clearHistoryFromMemory()
        if removeFromDisk { removePersistedHistory() }
    }

    func updateStorageLimit(_ newValue: Int) {
        let clamped = Self.clampStorageLimit(newValue)
        guard clamped != storageLimit else { return }
        storageLimit = clamped
        persistStorageLimit()
        if enforceStorageLimit() { scheduleSave(needsImmediate: true) }
    }

    func record(_ source: Entry.Source, content: String, metadata: Entry.Metadata? = nil) {
        guard isEnabled else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var entry = Entry(source: source, content: content, metadata: metadata ?? .empty)
        if storageLimit > 0 && entry.estimatedSizeInBytes > storageLimit {
            lastCopiedEntryID = entry.id
            return
        }
        entry.timestamp = Date()
        entries.insert(entry, at: 0)
        applyUsageDelta(for: entry, adding: true)
        let didTrim = enforceStorageLimit()
        lastCopiedEntryID = entry.id
        scheduleSave(needsImmediate: didTrim)
    }

    func copyEntry(_ entry: Entry) {
        guard isEnabled else { return }
        PlatformClipboard.copy(entry.content)
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            var updated = entry; updated.timestamp = Date()
            entries.remove(at: index); entries.insert(updated, at: 0)
        } else {
            var newEntry = entry; newEntry.timestamp = Date()
            entries.insert(newEntry, at: 0); applyUsageDelta(for: newEntry, adding: true)
            _ = enforceStorageLimit()
        }
        lastCopiedEntryID = entries.first?.id
        scheduleSave(needsImmediate: false)
    }

    func importEntries(_ newEntries: [Entry]) {
        guard isEnabled, !newEntries.isEmpty else { return }
        var didInsert = false
        for entry in newEntries {
            if entries.contains(where: { $0.id == entry.id }) { continue }
            if storageLimit > 0 && entry.estimatedSizeInBytes > storageLimit { continue }
            entries.append(entry); applyUsageDelta(for: entry, adding: true); didInsert = true
        }
        guard didInsert else { return }
        entries.sort { $0.timestamp > $1.timestamp }
        let didTrim = enforceStorageLimit()
        scheduleSave(needsImmediate: didTrim)
    }

    func formattedUsageBreakdown() -> (total: String, query: String, grid: String) {
        (EchoFormatters.bytes(usage.totalBytes), EchoFormatters.bytes(usage.queryBytes), EchoFormatters.bytes(usage.gridBytes))
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: historyURL.path) {
                let data = try Data(contentsOf: historyURL)
                if let archive = try decodeArchive(fromEncryptedData: data) {
                    entries = archive.entries.sorted { $0.timestamp > $1.timestamp }
                    recalculateUsage(); if enforceStorageLimit() { scheduleSave(needsImmediate: true) }
                    return
                }
                if let archive = try decodeArchive(fromPlainData: data) {
                    entries = archive.entries.sorted { $0.timestamp > $1.timestamp }
                    recalculateUsage(); scheduleSave(needsImmediate: true); return
                }
            } else if fm.fileExists(atPath: legacyHistoryURL.path) {
                let data = try Data(contentsOf: legacyHistoryURL)
                if let archive = try decodeArchive(fromPlainData: data) {
                    entries = archive.entries.sorted { $0.timestamp > $1.timestamp }
                    recalculateUsage(); scheduleSave(needsImmediate: true); try? fm.removeItem(at: legacyHistoryURL); return
                }
            }
        } catch { print("Failed to load clipboard history: \(error)") }
        clearHistoryFromMemory()
    }

    private func scheduleSave(needsImmediate: Bool = false) {
        guard isEnabled else { return }
        let archive = ClipboardHistoryArchive(version: ClipboardHistoryStore.archiveVersion, entries: entries)
        pendingSaveWorkItem?.cancel()
        let workItem = ClipboardHistoryPersistor.makeSaveWorkItem(archive: archive, key: encryptionKey, historyURL: historyURL, crypto: crypto)
        pendingSaveWorkItem = workItem
        if needsImmediate { saveQueue.async(execute: workItem) }
        else { saveQueue.asyncAfter(deadline: .now() + 0.5, execute: workItem) }
    }

    private func enforceStorageLimit() -> Bool {
        guard storageLimit > 0 else { return false }
        var didTrim = false
        while usage.totalBytes > storageLimit, let removed = entries.last {
            entries.removeLast(); applyUsageDelta(for: removed, adding: false); didTrim = true
        }
        return didTrim
    }

    private func applyUsageDelta(for entry: Entry, adding: Bool) {
        let delta = entry.estimatedSizeInBytes
        var updated = usage
        switch entry.source.usageCategory {
        case .query: updated.queryBytes = max(0, updated.queryBytes + (adding ? delta : -delta))
        case .grid: updated.gridBytes = max(0, updated.gridBytes + (adding ? delta : -delta))
        }
        usage = updated
    }

    private func recalculateUsage() {
        var queryTotal = 0, gridTotal = 0
        for entry in entries {
            let size = entry.estimatedSizeInBytes
            switch entry.source.usageCategory {
            case .query: queryTotal += size
            case .grid: gridTotal += size
            }
        }
        usage = UsageBreakdown(queryBytes: queryTotal, gridBytes: gridTotal)
    }

    private func persistStorageLimit() { UserDefaults.standard.set(storageLimit, forKey: Self.storageLimitDefaultsKey) }

    private func clearHistoryFromMemory() {
        pendingSaveWorkItem?.cancel(); pendingSaveWorkItem = nil
        entries = []; usage = UsageBreakdown(); lastCopiedEntryID = nil
    }

    private func removePersistedHistory() {
        let fm = FileManager.default
        if fm.fileExists(atPath: historyURL.path) { try? fm.removeItem(at: historyURL) }
        if fm.fileExists(atPath: legacyHistoryURL.path) { try? fm.removeItem(at: legacyHistoryURL) }
    }

    private static func clampStorageLimit(_ value: Int) -> Int { min(max(value, minimumStorageLimit), maximumStorageLimit) }

    private func decodeArchive(fromEncryptedData data: Data) throws -> ClipboardHistoryArchive? {
        do {
            let decrypted = try crypto.decrypt(data, using: encryptionKey)
            return try JSONDecoder().decode(ClipboardHistoryArchive.self, from: decrypted)
        } catch ClipboardHistoryCrypto.Error.invalidEnvelope { return nil }
    }

    private func decodeArchive(fromPlainData data: Data) throws -> ClipboardHistoryArchive? {
        try? JSONDecoder().decode(ClipboardHistoryArchive.self, from: data)
    }

    private static func makeHistoryURLs() -> (encrypted: URL, legacy: URL) {
        let fm = FileManager.default
        do {
            let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let baseDir = support.appendingPathComponent("Echo/ClipboardHistory", isDirectory: true)
            if !fm.fileExists(atPath: baseDir.path) { try fm.createDirectory(at: baseDir, withIntermediateDirectories: true) }
            return (baseDir.appendingPathComponent("history.enc"), baseDir.appendingPathComponent("history.json"))
        } catch {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            return (fallback.appendingPathComponent("clipboard_history.enc"), fallback.appendingPathComponent("clipboard_history.json"))
        }
    }

}
