import Foundation
import OSLog

/// The notification history behind the toolbar bell (plan N3): every event, newest first, kept
/// across launches, with an unread count for the badge.
@MainActor @Observable
final class NotificationHistory {
    private(set) var records: [NotificationRecord] = []
    private(set) var unreadCount = 0

    /// Older records are dropped past this many.
    static let capacity = 500

    @ObservationIgnored private let fileURL: URL?

    /// - Parameter fileURL: where the history is saved; nil keeps it in memory (tests, previews).
    init(fileURL: URL? = NotificationHistory.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    func append(_ record: NotificationRecord) {
        records.insert(record, at: 0)
        if records.count > Self.capacity { records.removeLast(records.count - Self.capacity) }
        unreadCount += 1
        save()
    }

    func markAllRead() {
        unreadCount = 0
        save()
    }

    func clear() {
        records.removeAll()
        unreadCount = 0
        save()
    }

    /// Records passing the filter, grouped by server (events without one last, as "Echo").
    func groupedByServer(_ filter: NotificationHistoryFilter) -> [(server: String, records: [NotificationRecord])] {
        let matching = records.filter(filter.includes)
        var order: [String] = []
        var groups: [String: [NotificationRecord]] = [:]
        for record in matching {
            let server = record.context?.serverName ?? Self.appGroupName
            if groups[server] == nil { order.append(server) }
            groups[server, default: []].append(record)
        }
        order.sort { lhs, rhs in
            if lhs == Self.appGroupName { return false }
            if rhs == Self.appGroupName { return true }
            return (groups[lhs]?.first?.date ?? .distantPast) > (groups[rhs]?.first?.date ?? .distantPast)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    static let appGroupName = "Echo"

    // MARK: - Persistence

    private struct Archive: Codable {
        var records: [NotificationRecord]
        var unreadCount: Int
    }

    nonisolated static var defaultFileURL: URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let directory = support.appendingPathComponent("Echo", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("notification-history.json")
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let archive = try? JSONDecoder().decode(Archive.self, from: data) else { return }
        records = archive.records
        unreadCount = archive.unreadCount
    }

    private func save() {
        guard let fileURL else { return }
        let archive = Archive(records: records, unreadCount: unreadCount)
        do {
            try JSONEncoder().encode(archive).write(to: fileURL, options: .atomic)
        } catch {
            Logger(subsystem: "dev.echodb.echo", category: "notifications")
                .error("Couldn't save notification history: \(error.localizedDescription)")
        }
    }
}
