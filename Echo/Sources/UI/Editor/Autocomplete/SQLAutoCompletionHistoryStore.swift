import Foundation

final class SQLAutoCompletionHistoryStore {
    struct Entry {
        let suggestion: SQLAutoCompletionSuggestion
        var lastUsed: Date
    }

    static let shared = SQLAutoCompletionHistoryStore()

    private var storage: [String: [Entry]] = [:]
    private let queue = DispatchQueue(label: "com.fuzee.sqlautocompletion.history", attributes: .concurrent)
    private let maxEntriesPerContext = 20

    private init() {}

    func record(_ suggestion: SQLAutoCompletionSuggestion,
                context: SQLEditorCompletionContext?) {
        guard shouldPersist(suggestion: suggestion) else { return }
        let key = contextKey(for: context)
        let now = Date()

        queue.async(flags: .barrier) {
            var entries = self.storage[key] ?? []
            if let index = entries.firstIndex(where: { $0.suggestion.id == suggestion.id }) {
                entries[index].lastUsed = now
            } else {
                entries.append(Entry(suggestion: suggestion, lastUsed: now))
            }
            if entries.count > self.maxEntriesPerContext {
                entries.sort { $0.lastUsed > $1.lastUsed }
                entries = Array(entries.prefix(self.maxEntriesPerContext))
            }
            self.storage[key] = entries
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
            let filtered = entries
                .sorted { $0.lastUsed > $1.lastUsed }
                .compactMap { entry -> SQLAutoCompletionSuggestion? in
                    let titleLower = entry.suggestion.title.lowercased()
                    if normalizedPrefix.isEmpty || titleLower.hasPrefix(normalizedPrefix) {
                        return entry.suggestion
                    }
                    return nil
                }
            result = Array(filtered.prefix(limit))
        }

        return result
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
}
