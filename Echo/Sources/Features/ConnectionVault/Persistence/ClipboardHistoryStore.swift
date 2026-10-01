import Observation
import Foundation

/// Round 39 CB1: Echo no longer captures or persists clipboard contents. Kept only so older
/// project archives and existing copy call sites decode safely; the system clipboard does the work.
@Observable
final class ClipboardHistoryStore {
    typealias UsageBreakdown = ClipboardHistoryUsageBreakdown
    typealias Entry = ClipboardHistoryEntry
    let entries: [Entry] = []
    var lastCopiedEntryID: UUID?
    let usage = UsageBreakdown()
    let storageLimit = 0
    var isEnabled: Bool { false }

    func setEnabled(_ enabled: Bool) {}
    func clearHistory(removeFromDisk: Bool = true) {}
    func updateStorageLimit(_ value: Int) {}
    func record(_ source: Entry.Source, content: String, metadata: Entry.Metadata? = nil) {}
    func copyEntry(_ entry: Entry) { PlatformClipboard.copy(entry.content) }
    func importEntries(_ entries: [Entry]) {}
    func formattedUsageBreakdown() -> (total: String, query: String, grid: String) { ("0 B", "0 B", "0 B") }
}
