import Foundation
import Testing
@testable import Echo

/// Round 34: Refresh only while the front tab can reload, and only its own reload; the bell shows
/// long operations but not query runs.
@MainActor
struct RefreshAndActivityTests {
    @Test func aQueryTabHasNoRefresh() {
        #expect(!TabReloader.canReload(.query))
        #expect(!WorkspaceToolbarContext(kind: .query, databaseType: .microsoftSQL).canReload)
        #expect(!WorkspaceToolbarContext(kind: nil, databaseType: nil).canReload)
    }

    @Test(arguments: [WorkspaceTab.Kind.activityMonitor, .jobQueue, .errorLog, .extendedEvents, .structure, .maintenance,
                      .mssqlMaintenance, .diagram, .profiler, .resourceGovernor, .tuningAdvisor, .policyManagement])
    func toolTabsThatReloadOfferRefresh(kind: WorkspaceTab.Kind) {
        #expect(TabReloader.canReload(kind))
        #expect(WorkspaceToolbarContext(kind: kind, databaseType: .microsoftSQL).canReload)
    }

    @Test func aReloaderStartsAtRest() {
        let reloader = TabReloader()
        #expect(reloader.phase == .idle)
        #expect(reloader.phase(for: nil) == .idle)
    }

    @Test func queryRunsStayOffTheBell() {
        let engine = ActivityEngine()
        let query = engine.begin("Executing query", showsOnBell: false)
        let backup = engine.begin("Backup shop")
        #expect(engine.bellOperations.map(\.label) == ["Backup shop"])
        backup.succeed()
        #expect(engine.bellOperations.isEmpty)
        #expect(engine.isActive)
        query.succeed()
        #expect(!engine.isActive)
    }

    @Test func theBellListsOperationsOldestFirst() {
        let engine = ActivityEngine()
        let first = engine.begin("Restore shop")
        let second = engine.begin("Rebuild indexes")
        #expect(engine.bellOperations.map(\.label) == ["Restore shop", "Rebuild indexes"])
        first.cancel()
        second.fail("timed out")
        #expect(engine.bellOperations.isEmpty)
    }

    // MARK: - A long operation says when it ends

    private func result(_ outcome: OperationResult.Outcome = .succeeded, duration: TimeInterval = 72, showsOnBell: Bool = true,
                        completedAt: Date = Date(timeIntervalSince1970: 10_000)) -> OperationResult {
        OperationResult(id: UUID(), label: "Backup shop", connectionSessionID: nil, showsOnBell: showsOnBell,
                        outcome: outcome, completedAt: completedAt, duration: duration)
    }

    @Test func theEngineReportsEveryFinish() {
        let engine = ActivityEngine()
        var finished: [OperationResult] = []
        engine.onFinish = { finished.append($0) }
        engine.begin("Executing query", showsOnBell: false).succeed()
        engine.begin("Backup shop").fail("disk full")
        #expect(finished.map(\.label) == ["Executing query", "Backup shop"])
        #expect(finished.map(\.showsOnBell) == [false, true])
        #expect(finished.last?.isFailure == true)
    }

    @Test func onlyLongBellOperationsThatEndedAreNoticed() {
        #expect(OperationFinishNotifier.isLongEnough(result()))
        #expect(OperationFinishNotifier.isLongEnough(result(.failed(message: ""))))
        #expect(!OperationFinishNotifier.isLongEnough(result(duration: 4)))
        #expect(!OperationFinishNotifier.isLongEnough(result(showsOnBell: false)))
        #expect(!OperationFinishNotifier.isLongEnough(result(.cancelled)))
    }

    @Test func anOperationsOwnNotificationIsNotDoubled() {
        let end = Date(timeIntervalSince1970: 10_000)
        let own = NotificationRecord(date: end.addingTimeInterval(0.3), category: .generalSuccess, message: "Backup of shop finished", severity: .success)
        let earlier = NotificationRecord(date: end.addingTimeInterval(-30), category: .generalInfo, message: "Connected", severity: .info)
        #expect(OperationFinishNotifier.alreadyNotified(result(completedAt: end), records: [own, earlier]))
        #expect(!OperationFinishNotifier.alreadyNotified(result(completedAt: end), records: [earlier]))
        #expect(!OperationFinishNotifier.alreadyNotified(result(completedAt: end), records: []))
    }

    @Test func theNoticeSaysHowItEnded() {
        #expect(OperationFinishNotifier.message(for: result()) == "Backup shop finished in 1:12")
        #expect(OperationFinishNotifier.message(for: result(.failed(message: "disk full"))) == "Backup shop failed: disk full")
        #expect(OperationFinishNotifier.message(for: result(.failed(message: ""), duration: 9)) == "Backup shop failed after 9 s")
        #expect(OperationFinishNotifier.message(for: result(duration: 3725)) == "Backup shop finished in 1:02:05")
    }
}
