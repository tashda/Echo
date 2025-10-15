import SwiftUI
import Combine
import CryptoKit

struct ClipboardHistoryUsageBreakdown: Equatable {
    var queryBytes: Int
    var gridBytes: Int

    var totalBytes: Int { queryBytes + gridBytes }
    
    init(queryBytes: Int = 0, gridBytes: Int = 0) {
        self.queryBytes = queryBytes
        self.gridBytes = gridBytes
    }
}

struct ClipboardHistoryEntry: Identifiable, Equatable, Codable {
    enum Source: Equatable {
        case queryEditor
        case resultGrid(includeHeaders: Bool)

        var iconName: String {
            switch self {
            case .queryEditor:
                return "doc.text"
            case .resultGrid(true):
                return "tablecells.fill"
            case .resultGrid(false):
                return "tablecells"
            }
        }

        var tint: Color {
            switch self {
            case .queryEditor:
                return .accentColor
            case .resultGrid(true):
                return Color.orange
            case .resultGrid(false):
                return Color.blue
            }
        }

        var caption: String {
            switch self {
            case .queryEditor:
                return "Query Editor"
            case .resultGrid(true):
                return "Grid • Headers"
            case .resultGrid(false):
                return "Grid"
            }
        }

        var usageCategory: UsageCategory {
            switch self {
            case .queryEditor:
                return .query
            case .resultGrid:
                return .grid
            }
        }
    }

    enum UsageCategory {
        case query
        case grid
    }

    struct Metadata: Equatable, Codable {
        var serverName: String?
        var databaseName: String?
        var objectName: String?
        var connectionColorHex: String?

        var hasDetails: Bool {
            let hasServer = !(serverName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasDatabase = !(databaseName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasObject = !(objectName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return hasServer || hasDatabase || hasObject
        }

        func updating(
            serverName: String? = nil,
            databaseName: String? = nil,
            objectName: String? = nil,
            connectionColorHex: String? = nil
        ) -> Metadata {
            Metadata(
                serverName: serverName ?? self.serverName,
                databaseName: databaseName ?? self.databaseName,
                objectName: objectName ?? self.objectName,
                connectionColorHex: connectionColorHex ?? self.connectionColorHex
            )
        }

        init(
            serverName: String? = nil,
            databaseName: String? = nil,
            objectName: String? = nil,
            connectionColorHex: String? = nil
        ) {
            self.serverName = serverName
            self.databaseName = databaseName
            self.objectName = objectName
            self.connectionColorHex = connectionColorHex
        }
    }

    let id: UUID
    var source: Source
    var content: String
    var timestamp: Date
    var metadata: Metadata

    init(id: UUID = UUID(), source: Source, content: String, timestamp: Date = Date(), metadata: Metadata = Metadata()) {
        self.id = id
        self.source = source
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }

    var previewText: String {
        let trimmed = content.replacingOccurrences(of: "\n", with: " ⏎ ")
        if trimmed.count <= 140 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 140)
        return String(trimmed[..<index]) + "…"
    }

    var timestampDisplay: String {
        timestamp.formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .hour(.twoDigits(amPM: .omitted))
                .minute()
        )
    }

    var estimatedSizeInBytes: Int {
        var total = content.lengthOfBytes(using: .utf8)
        if let serverName = metadata.serverName {
            total += serverName.lengthOfBytes(using: .utf8)
        }
        if let databaseName = metadata.databaseName {
            total += databaseName.lengthOfBytes(using: .utf8)
        }
        if let objectName = metadata.objectName {
            total += objectName.lengthOfBytes(using: .utf8)
        }
        if let colorHex = metadata.connectionColorHex {
            total += colorHex.lengthOfBytes(using: .utf8)
        }
        // Approximate overhead for metadata and structure
        total += 128
        return total
    }

    var formattedSize: String {
        ClipboardHistoryStore.formatByteCount(estimatedSizeInBytes)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case content
        case timestamp
        case metadata
    }
}

extension ClipboardHistoryEntry.Metadata {
    static let empty = ClipboardHistoryEntry.Metadata()
}

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    typealias UsageBreakdown = ClipboardHistoryUsageBreakdown
    typealias Entry = ClipboardHistoryEntry

    private struct EntryArchive: Codable {
        let version: Int
        var entries: [Entry]
    }

    private static let archiveVersion = 1
    private static let storageLimitDefaultsKey = "clipboardHistoryStorageLimit"
    private static let enabledDefaultsKey = "clipboardHistoryEnabled"
    private static let defaultStorageLimit = 1 * 1_024 * 1_024 * 1_024 // 1 GB
    private static let minimumStorageLimit = 256 * 1_024 * 1_024      // 256 MB
    private static let maximumStorageLimit = 10 * 1_024 * 1_024 * 1_024 // 10 GB

    private let crypto = ClipboardHistoryCrypto()
    private let historyURL: URL
    private let legacyHistoryURL: URL
    private let encryptionKey: SymmetricKey
    private let saveQueue = DispatchQueue(label: "com.fuzee.clipboardHistory.save", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?

    @Published private(set) var entries: [Entry] = []
    @Published var lastCopiedEntryID: UUID?
    @Published private(set) var usage: UsageBreakdown = UsageBreakdown()
    @Published private(set) var storageLimit: Int
    @Published var isEnabled: Bool

    init() {
        let urls = ClipboardHistoryStore.makeHistoryURLs()
        self.historyURL = urls.encrypted
        self.legacyHistoryURL = urls.legacy
        self.encryptionKey = crypto.loadOrCreateKey()
        let storedLimit = (UserDefaults.standard.object(forKey: Self.storageLimitDefaultsKey) as? Int)
        self.storageLimit = Self.clampStorageLimit(storedLimit ?? Self.defaultStorageLimit)
        let storedEnabled = (UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool)
        self.isEnabled = storedEnabled ?? true

        if isEnabled {
            loadFromDisk()
        } else {
            clearHistoryFromMemory()
            removePersistedHistory()
        }
    }

    deinit {
        pendingSaveWorkItem?.cancel()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)

        if enabled {
            loadFromDisk()
        } else {
            clearHistory(removeFromDisk: true)
        }
    }

    func clearHistory(removeFromDisk: Bool = true) {
        clearHistoryFromMemory()
        if removeFromDisk {
            removePersistedHistory()
        }
    }

    func updateStorageLimit(_ newValue: Int) {
        let clampedValue = Self.clampStorageLimit(newValue)
        guard clampedValue != storageLimit else { return }
        storageLimit = clampedValue
        persistStorageLimit()
        if enforceStorageLimit() {
            scheduleSave(needsImmediate: true)
        }
    }

    func record(_ source: Entry.Source, content: String, metadata: Entry.Metadata = Entry.Metadata()) {
        guard isEnabled else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var entry = Entry(source: source, content: content, metadata: metadata)
        let entrySize = entry.estimatedSizeInBytes

        if storageLimit > 0 && entrySize > storageLimit {
            // Entry exceeds the maximum storage allocation — skip persistence but still track copy
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
            var updated = entry
            updated.timestamp = Date()
            entries.remove(at: index)
            entries.insert(updated, at: 0)
        } else {
            var newEntry = entry
            newEntry.timestamp = Date()
            entries.insert(newEntry, at: 0)
            applyUsageDelta(for: newEntry, adding: true)
            _ = enforceStorageLimit()
        }

        lastCopiedEntryID = entries.first?.id
        scheduleSave(needsImmediate: false)
    }

    func importEntries(_ newEntries: [Entry]) {
        guard isEnabled else { return }
        guard !newEntries.isEmpty else { return }

        var didInsert = false
        for entry in newEntries {
            if entries.contains(where: { $0.id == entry.id }) { continue }
            if storageLimit > 0 && entry.estimatedSizeInBytes > storageLimit { continue }
            entries.append(entry)
            applyUsageDelta(for: entry, adding: true)
            didInsert = true
        }

        guard didInsert else { return }
        entries.sort { $0.timestamp > $1.timestamp }
        let didTrim = enforceStorageLimit()
        scheduleSave(needsImmediate: didTrim)
    }

    func formattedUsageBreakdown() -> (total: String, query: String, grid: String) {
        (
            ClipboardHistoryStore.formatByteCount(usage.totalBytes),
            ClipboardHistoryStore.formatByteCount(usage.queryBytes),
            ClipboardHistoryStore.formatByteCount(usage.gridBytes)
        )
    }

    func snapshotEntries() -> [Entry] {
        entries
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: historyURL.path) {
                let data = try Data(contentsOf: historyURL)
                if let archive = try decodeArchive(fromEncryptedData: data) {
                    entries = archive.entries.sorted { $0.timestamp > $1.timestamp }
                    recalculateUsage()
                    if enforceStorageLimit() {
                        scheduleSave(needsImmediate: true)
                    }
                    return
                }

                // Fallback: treat file as legacy plaintext if header missing or corrupt
                if let archive = try decodeArchive(fromPlainData: data) {
                    entries = archive.entries.sorted { $0.timestamp > $1.timestamp }
                    recalculateUsage()
                    scheduleSave(needsImmediate: true)
                    return
                }
            } else if fm.fileExists(atPath: legacyHistoryURL.path) {
                let data = try Data(contentsOf: legacyHistoryURL)
                if let archive = try decodeArchive(fromPlainData: data) {
                    entries = archive.entries.sorted { $0.timestamp > $1.timestamp }
                    recalculateUsage()
                    scheduleSave(needsImmediate: true)
                    try? fm.removeItem(at: legacyHistoryURL)
                    return
                }
            }
        } catch {
            print("Failed to load clipboard history: \(error)")
        }

        clearHistoryFromMemory()
    }

    private func scheduleSave(needsImmediate: Bool = false) {
        guard isEnabled else { return }
        let snapshot = entries
        let archive = EntryArchive(version: ClipboardHistoryStore.archiveVersion, entries: snapshot)
        let key = encryptionKey
        let historyURL = self.historyURL
        let crypto = self.crypto
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem {
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

        pendingSaveWorkItem = workItem
        if needsImmediate {
            saveQueue.async(execute: workItem)
        } else {
            saveQueue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
    }

    private func enforceStorageLimit() -> Bool {
        guard storageLimit > 0 else { return false }
        var didTrim = false

        while usage.totalBytes > storageLimit, let removed = entries.last {
            entries.removeLast()
            applyUsageDelta(for: removed, adding: false)
            didTrim = true
        }

        return didTrim
    }

    private func applyUsageDelta(for entry: Entry, adding: Bool) {
        let delta = entry.estimatedSizeInBytes
        var updated = usage

        switch entry.source.usageCategory {
        case .query:
            updated.queryBytes = max(0, updated.queryBytes + (adding ? delta : -delta))
        case .grid:
            updated.gridBytes = max(0, updated.gridBytes + (adding ? delta : -delta))
        }

        usage = updated
    }

    private func recalculateUsage() {
        var queryTotal = 0
        var gridTotal = 0

        for entry in entries {
            let size = entry.estimatedSizeInBytes
            switch entry.source.usageCategory {
            case .query:
                queryTotal += size
            case .grid:
                gridTotal += size
            }
        }

        usage = UsageBreakdown(queryBytes: queryTotal, gridBytes: gridTotal)
    }

    private func persistStorageLimit() {
        UserDefaults.standard.set(storageLimit, forKey: Self.storageLimitDefaultsKey)
    }

    private func clearHistoryFromMemory() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        entries = []
        usage = UsageBreakdown()
        lastCopiedEntryID = nil
    }

    private func removePersistedHistory() {
        let fm = FileManager.default
        if fm.fileExists(atPath: historyURL.path) {
            try? fm.removeItem(at: historyURL)
        }
        if fm.fileExists(atPath: legacyHistoryURL.path) {
            try? fm.removeItem(at: legacyHistoryURL)
        }
    }

    private static func clampStorageLimit(_ value: Int) -> Int {
        return min(max(value, minimumStorageLimit), maximumStorageLimit)
    }

    private func decodeArchive(fromEncryptedData data: Data) throws -> EntryArchive? {
        do {
            let decrypted = try crypto.decrypt(data, using: encryptionKey)
            let decoder = JSONDecoder()
            return try decoder.decode(EntryArchive.self, from: decrypted)
        } catch ClipboardHistoryCrypto.Error.invalidEnvelope {
            return nil
        }
    }

    private func decodeArchive(fromPlainData data: Data) throws -> EntryArchive? {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(EntryArchive.self, from: data)
        } catch {
            return nil
        }
    }

    private static func makeHistoryURLs() -> (encrypted: URL, legacy: URL) {
        let fm = FileManager.default
        do {
            let support = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let baseDir = support.appendingPathComponent("Echo", isDirectory: true)
            if !fm.fileExists(atPath: baseDir.path) {
                try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
            }

            let historyDir = baseDir.appendingPathComponent("ClipboardHistory", isDirectory: true)
            if !fm.fileExists(atPath: historyDir.path) {
                try fm.createDirectory(at: historyDir, withIntermediateDirectories: true)
            }

            let encrypted = historyDir.appendingPathComponent("history.enc")
            let legacy = historyDir.appendingPathComponent("history.json")
            return (encrypted, legacy)
        } catch {
            print("Failed to create clipboard history directory: \(error)")
            let fallbackDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            return (
                fallbackDir.appendingPathComponent("clipboard_history.enc"),
                fallbackDir.appendingPathComponent("clipboard_history.json")
            )
        }
    }

    static func formatByteCount(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .file
        formatter.isAdaptive = true
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct ClipboardHistoryCrypto {
    enum Error: Swift.Error {
        case invalidEnvelope
        case unsupportedVersion(found: UInt8)
        case missingCombinedData
    }

    private let keyAccount = "clipboardHistoryKey"
    private let keychain = KeychainHelper()

    private static let envelopeMagic = Data("ECHC".utf8)
    private static let envelopeVersion: UInt8 = 1
    private static let authenticationData = Data("EchoClipboardHistory".utf8)

    func loadOrCreateKey() -> SymmetricKey {
        if let stored = try? keychain.getPassword(account: keyAccount),
           let data = Data(base64Encoded: stored),
           data.count == 32 {
            return SymmetricKey(data: data)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        do {
            try keychain.setPassword(keyData.base64EncodedString(), account: keyAccount)
        } catch {
            print("Failed to persist clipboard history key: \(error)")
        }
        return newKey
    }

    func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: Self.authenticationData)
        guard let combined = sealed.combined else {
            throw Error.missingCombinedData
        }

        var envelope = Data()
        envelope.append(Self.envelopeMagic)
        envelope.append(Self.envelopeVersion)
        envelope.append(combined)
        return envelope
    }

    func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let headerLength = Self.envelopeMagic.count
        guard data.count > headerLength + 1 else {
            throw Error.invalidEnvelope
        }

        guard data.starts(with: Self.envelopeMagic) else {
            throw Error.invalidEnvelope
        }

        let version = data[headerLength]
        guard version == Self.envelopeVersion else {
            throw Error.unsupportedVersion(found: version)
        }

        let combined = Data(data.dropFirst(headerLength + 1))
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key, authenticating: Self.authenticationData)
    }
}

extension ClipboardHistoryStore.Entry.Source: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case includeHeaders
    }

    private enum Kind: String, Codable {
        case queryEditor
        case resultGrid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .queryEditor:
            self = .queryEditor
        case .resultGrid:
            let includeHeaders = try container.decode(Bool.self, forKey: .includeHeaders)
            self = .resultGrid(includeHeaders: includeHeaders)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .queryEditor:
            try container.encode(Kind.queryEditor, forKey: .kind)
            try container.encode(false, forKey: .includeHeaders)
        case .resultGrid(let includeHeaders):
            try container.encode(Kind.resultGrid, forKey: .kind)
            try container.encode(includeHeaders, forKey: .includeHeaders)
        }
    }
}
