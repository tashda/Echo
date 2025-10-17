import Foundation

final class SQLAutoCompletionHistoryStore {
    struct Entry {
        var suggestion: SQLAutoCompletionSuggestion
        var lastUsed: Date
        var usageCount: Int
    }

    static let shared = SQLAutoCompletionHistoryStore()

    private var storage: [String: [Entry]] = [:]
    private let queue = DispatchQueue(label: "com.fuzee.sqlautocompletion.history", attributes: .concurrent)
    private let maxEntriesPerContext = 20
    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 1.0
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let persistenceVersion = 1

    private init() {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)) ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let baseDir = support.appendingPathComponent("Echo", isDirectory: true)
        if !fm.fileExists(atPath: baseDir.path) {
            try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
        let historyDir = baseDir.appendingPathComponent("AutocompleteHistory", isDirectory: true)
        if !fm.fileExists(atPath: historyDir.path) {
            try? fm.createDirectory(at: historyDir, withIntermediateDirectories: true)
        }
        fileURL = historyDir.appendingPathComponent("history.json")
        encoder.outputFormatting = [.prettyPrinted]
        queue.sync(flags: .barrier) {
            loadFromDiskLocked()
        }
    }

    struct Snapshot: Codable {
        var version: Int
        var entriesByContext: [String: [PersistedEntry]]
    }

    struct PersistedEntry: Codable {
        var suggestion: SQLAutoCompletionSuggestion
        var lastUsed: Date
        var usageCount: Int

        init(entry: Entry) {
            var storedSuggestion = entry.suggestion
            storedSuggestion = storedSuggestion.withSource(.history)
            self.suggestion = storedSuggestion
            self.lastUsed = entry.lastUsed
            self.usageCount = entry.usageCount
        }

        func makeEntry() -> Entry {
            Entry(suggestion: suggestion.withSource(.history),
                  lastUsed: lastUsed,
                  usageCount: max(usageCount, 1))
        }
    }

    func record(_ suggestion: SQLAutoCompletionSuggestion,
                context: SQLEditorCompletionContext?) {
        guard shouldPersist(suggestion: suggestion) else { return }
        let key = contextKey(for: context)
        let now = Date()

        queue.async(flags: .barrier) {
            var entries = self.storage[key] ?? []
            let storedSuggestion = suggestion.withSource(.history)
            if let index = entries.firstIndex(where: { $0.suggestion.id == suggestion.id }) {
                entries[index].suggestion = storedSuggestion
                entries[index].lastUsed = now
                entries[index].usageCount += 1
            } else {
                entries.append(Entry(suggestion: storedSuggestion,
                                     lastUsed: now,
                                     usageCount: 1))
            }
            if entries.count > self.maxEntriesPerContext {
                entries.sort { $0.lastUsed > $1.lastUsed }
                entries = Array(entries.prefix(self.maxEntriesPerContext))
            }
            self.storage[key] = entries
            self.scheduleSaveLocked()
        }
    }

    func suggestions(matching prefix: String,
                     context: SQLEditorCompletionContext?,
                     limit: Int) -> [SQLAutoCompletionSuggestion] {
        let key = contextKey(for: context)
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result: [SQLAutoCompletionSuggestion] = []

        queue.sync {
            guard let entries = storage[key] else { return }
            let now = Date()
            let filtered = entries
                .sorted { lhs, rhs in
                    Self.score(for: lhs, now: now) > Self.score(for: rhs, now: now)
                }
                .compactMap { entry -> SQLAutoCompletionSuggestion? in
                    let titleLower = entry.suggestion.title.lowercased()
                    if normalizedPrefix.isEmpty || titleLower.hasPrefix(normalizedPrefix) {
                        return entry.suggestion.withSource(.history)
                    }
                    return nil
                }
            result = Array(filtered.prefix(limit))
        }

        return result
    }

    func weight(for suggestion: SQLAutoCompletionSuggestion,
                context: SQLEditorCompletionContext?) -> Double {
        let key = contextKey(for: context)
        var weight: Double = 0
        queue.sync {
            guard let entries = storage[key],
                  let match = entries.first(where: { $0.suggestion.id == suggestion.id }) else { return }
            weight = Self.score(for: match, now: Date())
        }
        return weight
    }

    private static func score(for entry: Entry, now: Date) -> Double {
        let recency = now.timeIntervalSince(entry.lastUsed)
        let recencyDecay = max(0, 3600 - recency) / 10.0
        let frequencyBoost = Double(entry.usageCount) * 45.0
        return frequencyBoost + recencyDecay
    }

    func snapshot() -> Snapshot? {
        var snapshot: Snapshot?
        queue.sync {
            guard !storage.isEmpty else { return }
            snapshot = makeSnapshotLocked()
        }
        return snapshot
    }

    func importSnapshot(_ snapshot: Snapshot, merge: Bool = true) {
        queue.async(flags: .barrier) {
            guard snapshot.version == self.persistenceVersion else { return }
            if !merge {
                self.storage.removeAll()
            }

            for (context, entries) in snapshot.entriesByContext {
                var existing = self.storage[context] ?? []
                for persisted in entries {
                    let entry = persisted.makeEntry()
                    if let index = existing.firstIndex(where: { $0.suggestion.id == entry.suggestion.id }) {
                        existing[index].suggestion = entry.suggestion
                        existing[index].lastUsed = max(existing[index].lastUsed, entry.lastUsed)
                        existing[index].usageCount = max(existing[index].usageCount, entry.usageCount)
                    } else {
                        existing.append(entry)
                    }
                }
                existing.sort { $0.lastUsed > $1.lastUsed }
                if existing.count > self.maxEntriesPerContext {
                    existing = Array(existing.prefix(self.maxEntriesPerContext))
                }
                self.storage[context] = existing
            }

            self.scheduleSaveLocked()
        }
    }

    func currentUsageBytes() -> UInt64 {
        var size: UInt64 = 0
        queue.sync {
            let fm = FileManager.default
            if let attributes = try? fm.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? NSNumber {
                size = fileSize.uint64Value
            }
        }
        return size
    }

    func flush() {
        queue.sync(flags: .barrier) {
            saveWorkItem?.cancel()
            saveWorkItem = nil
            persistImmediatelyLocked()
        }
    }

    private func shouldPersist(suggestion: SQLAutoCompletionSuggestion) -> Bool {
        switch suggestion.kind {
        case .table, .view, .materializedView, .column, .function, .join, .snippet:
            return true
        default:
            return false
        }
    }

    private func contextKey(for context: SQLEditorCompletionContext?) -> String {
        guard let context else { return "global" }
        let database = context.selectedDatabase ?? "default"
        let schema = context.defaultSchema ?? "default"
        return "\(context.databaseType.rawValue)|\(database)|\(schema)"
    }

    func reset() {
        queue.sync(flags: .barrier) {
            saveWorkItem?.cancel()
            saveWorkItem = nil
            self.storage.removeAll()
            removePersistedLocked()
        }
    }

    private func scheduleSaveLocked() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.queue.async(flags: .barrier) {
                self?.persistImmediatelyLocked()
            }
        }
        saveWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    private func makeSnapshotLocked() -> Snapshot {
        let entries = storage.mapValues { contextEntries in
            contextEntries.map { PersistedEntry(entry: $0) }
        }
        return Snapshot(version: persistenceVersion, entriesByContext: entries)
    }

    private func persistImmediatelyLocked() {
        let snapshot = makeSnapshotLocked()
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to persist autocomplete history: \(error)")
        }
    }

    private func loadFromDiskLocked() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            guard snapshot.version == persistenceVersion else { return }
            var restored: [String: [Entry]] = [:]
            for (context, entries) in snapshot.entriesByContext {
                let mapped = entries.map { $0.makeEntry() }
                if !mapped.isEmpty {
                    restored[context] = mapped
                }
            }
            storage = restored
        } catch {
            try? fm.removeItem(at: fileURL)
        }
    }

    private func removePersistedLocked() {
        let fm = FileManager.default
        saveWorkItem?.cancel()
        saveWorkItem = nil
        if fm.fileExists(atPath: fileURL.path) {
            try? fm.removeItem(at: fileURL)
        }
    }
}
