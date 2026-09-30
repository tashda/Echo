import Foundation
import OSLog

/// The notification history behind the toolbar bell (plan N3, round 17): every event, newest
/// first, kept across launches, with an unread count for the badge.
@MainActor @Observable
final class NotificationHistory {
    private(set) var records: [NotificationRecord] = []
    private(set) var unreadCount = 0
    /// The events that were new when the history was last opened. They stay bold, and are counted
    /// beside the title, while it is read (round 17: "bold plus the count is enough").
    private(set) var newRecordIDs: Set<UUID> = []

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

    /// Called when the history opens: the badge clears, and what was new is remembered.
    func markAllRead() {
        newRecordIDs = Set(records.prefix(unreadCount).map(\.id))
        unreadCount = 0
        save()
    }

    func clear() {
        records.removeAll()
        newRecordIDs = []
        unreadCount = 0
        save()
    }

    /// Records passing the filter, grouped by day, newest first: Today, Yesterday, then the date
    /// (round 17, "By time").
    func groupedByDay(
        _ filter: NotificationHistoryFilter,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(title: String, records: [NotificationRecord])] {
        var groups: [(title: String, records: [NotificationRecord])] = []
        for record in records where filter.includes(record) {
            let title = Self.dayTitle(for: record.date, now: now, calendar: calendar)
            if groups.last?.title == title {
                groups[groups.count - 1].records.append(record)
            } else {
                groups.append((title, [record]))
            }
        }
        return groups
    }

    static func dayTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

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
