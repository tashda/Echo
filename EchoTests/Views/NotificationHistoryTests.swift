import Foundation
import Testing
@testable import Echo

@Suite("Notification history")
@MainActor
struct NotificationHistoryTests {
    private func record(_ message: String, _ category: NotificationCategory = .generalInfo, server: String? = nil, severity: NotificationRecord.Severity = .info) -> NotificationRecord {
        NotificationRecord(category: category, message: message, severity: severity, context: server.map { NotificationContext(serverName: $0) })
    }

    @Test func newestFirstWithUnreadCount() {
        let history = NotificationHistory(fileURL: nil)
        history.append(record("one"))
        history.append(record("two"))
        #expect(history.records.map(\.message) == ["two", "one"])
        #expect(history.unreadCount == 2)
        history.markAllRead()
        #expect(history.unreadCount == 0)
    }

    @Test func keepsOnlyTheCapacity() {
        let history = NotificationHistory(fileURL: nil)
        for index in 0...NotificationHistory.capacity { history.append(record("\(index)")) }
        #expect(history.records.count == NotificationHistory.capacity)
        #expect(history.records.last?.message == "1")
    }

    @Test func groupsByDayNewestFirst() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let history = NotificationHistory(fileURL: nil)
        history.append(NotificationRecord(date: now.addingTimeInterval(-3 * 86_400), category: .generalInfo, message: "old", severity: .info))
        history.append(NotificationRecord(date: now.addingTimeInterval(-86_400), category: .generalInfo, message: "yesterday", severity: .info))
        history.append(NotificationRecord(date: now, category: .generalInfo, message: "today", severity: .info))
        let groups = history.groupedByDay(.all, now: now, calendar: calendar)
        #expect(groups.map(\.records.count) == [1, 1, 1])
        #expect(Array(groups.map(\.title).prefix(2)) == ["Today", "Yesterday"])
    }

    @Test func filtersErrorsAndQueries() {
        let history = NotificationHistory(fileURL: nil)
        history.append(record("ok"))
        history.append(record("failed", .queryFailed, severity: .error))
        #expect(history.groupedByDay(.errors).flatMap(\.records).map(\.message) == ["failed"])
        #expect(history.groupedByDay(.queries).flatMap(\.records).map(\.message) == ["failed"])
    }

    @Test func openingRemembersWhatWasNew() {
        let history = NotificationHistory(fileURL: nil)
        history.append(record("seen"))
        history.markAllRead()
        history.append(record("new one"))
        history.append(record("new two"))
        history.markAllRead()
        #expect(history.unreadCount == 0)
        #expect(Set(history.records.filter { history.newRecordIDs.contains($0.id) }.map(\.message)) == ["new one", "new two"])
    }

    @Test func splitsTheHeadlineFromTheDetail() {
        let failed = record("Query 1 failed: relation \"x\" does not exist")
        #expect(failed.headline == "Query 1 failed")
        #expect(failed.detail == "relation \"x\" does not exist")
        let plain = record("Connected to Test MSSQL")
        #expect(plain.headline == "Connected to Test MSSQL")
        #expect(plain.detail == nil)
    }

    @Test func survivesRelaunch() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notification-history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = NotificationHistory(fileURL: url)
        first.append(record("kept", server: "alpha"))
        let second = NotificationHistory(fileURL: url)
        #expect(second.records.map(\.message) == ["kept"])
        #expect(second.unreadCount == 1)
    }
}

@Suite("Toast stack")
@MainActor
struct StatusToastPresenterTests {
    @Test func repeatsCountUpInsteadOfStacking() {
        let presenter = StatusToastPresenter()
        presenter.show(icon: "bolt", message: "Connected")
        presenter.show(icon: "bolt", message: "Connected")
        #expect(presenter.toasts.count == 1)
        #expect(presenter.toasts.first?.count == 2)
    }

    @Test func showsAtMostThreeNewestFirst() {
        let presenter = StatusToastPresenter()
        for message in ["a", "b", "c", "d"] { presenter.show(icon: "bolt", message: message) }
        #expect(presenter.toasts.map(\.message) == ["d", "c", "b"])
    }

    @Test func errorsStayUntilDismissed() {
        let presenter = StatusToastPresenter()
        presenter.show(icon: "xmark", message: "Failed", style: .error)
        #expect(presenter.toasts.first?.staysUntilDismissed == true)
        presenter.dismiss()
        #expect(presenter.toasts.isEmpty)
    }
}

@Suite("Query error location")
struct QueryErrorLocationTests {
    @Test func readsEachDatabasesLine() {
        #expect(QueryErrorLocation.line(in: "Msg 208, Level 16, State 1, Line 3\nInvalid object name 'x'.") == 3)
        #expect(QueryErrorLocation.line(in: "ERROR: syntax error at or near \"FROM\"\nLINE 12: SELECT FROM") == 12)
        #expect(QueryErrorLocation.line(in: "You have an error in your SQL syntax near 'x' at line 1") == 1)
    }

    @Test func noLineMeansNil() {
        #expect(QueryErrorLocation.line(in: "no such table: users") == nil)
        #expect(QueryErrorLocation.line(in: "Pipeline failed") == nil)
    }
}
