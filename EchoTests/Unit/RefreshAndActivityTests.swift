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
}
