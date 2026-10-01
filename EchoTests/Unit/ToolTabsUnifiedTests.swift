import Foundation
import Testing
import SQLServerKit
@testable import Echo

/// Rounds 36.2 and 37: pages for every tool, the five families, the figures on Monitor tiles and
/// the Apply bar's wording.
@MainActor
@Suite("Tool tabs: pages, families and figures")
struct ToolTabsUnifiedTests {
    // MARK: Pages (36.2)

    final class PagedTool: ToolPaged {
        enum Page: String, CaseIterable { case first = "First", second = "Second", third = "Third" }
        var selectedPage: Page = .first
        var narrowed = false
        var availablePages: [Page] { narrowed ? [.first, .second] : Page.allCases }
    }

    @Test func aPagedToolListsItsPagesAndSwitchesByTitle() {
        let tool = PagedTool()
        #expect(tool.pageTitles == ["First", "Second", "Third"])
        #expect(tool.currentPageTitle == "First")
        tool.selectPage(titled: "Third")
        #expect(tool.selectedPage == .third)
    }

    @Test func aPagedToolIgnoresPagesThisServerDoesNotHave() {
        let tool = PagedTool()
        tool.narrowed = true
        #expect(tool.pageTitles == ["First", "Second"])
        tool.selectPage(titled: "Third")
        #expect(tool.selectedPage == .first)
        tool.selectPage(titled: "Nowhere")
        #expect(tool.selectedPage == .first)
    }

    @Test func theLastPageIsRememberedPerToolAndServer() throws {
        let defaults = try #require(UserDefaults(suiteName: "ToolTabsUnifiedTests.\(UUID().uuidString)"))
        let memory = ToolPageMemory(defaults: defaults)
        let server = UUID(), other = UUID()
        #expect(memory.page(tool: "policyManagement", connectionID: server) == nil)
        memory.remember("History", tool: "policyManagement", connectionID: server)
        #expect(memory.page(tool: "policyManagement", connectionID: server) == "History")
        #expect(memory.page(tool: "policyManagement", connectionID: other) == nil)
        #expect(memory.page(tool: "errorLog", connectionID: server) == nil)
    }

    // MARK: Families (37.1)

    @Test func everyTabButTheEditorsHasAFamily() {
        #expect(WorkspaceTab.Kind.query.toolFamily == nil)
        #expect(WorkspaceTab.Kind.psql.toolFamily == nil)
        for kind in WorkspaceTab.Kind.allCases where kind != .query && kind != .psql {
            #expect(kind.toolFamily != nil, "\(kind) has no family")
        }
    }

    @Test func theFamiliesAreAsDecided() {
        #expect(WorkspaceTab.Kind.profiler.toolFamily == .monitor)
        #expect(WorkspaceTab.Kind.extendedEvents.toolFamily == .monitor)
        #expect(WorkspaceTab.Kind.policyManagement.toolFamily == .manage)
        #expect(WorkspaceTab.Kind.jobQueue.toolFamily == .manage)
        #expect(WorkspaceTab.Kind.mssqlMaintenance.toolFamily == .health)
        #expect(WorkspaceTab.Kind.errorLog.toolFamily == .health)
        #expect(WorkspaceTab.Kind.structure.toolFamily == .properties)
        #expect(WorkspaceTab.Kind.diagram.toolFamily == .canvas)
        #expect(WorkspaceTab.Kind.schemaDiff.toolFamily == .canvas)
    }

    @Test func toolTabsGetTheSharedHeaderExceptThoseThatDrawTheirOwn() {
        #expect(WorkspaceTab.Kind.structure.isToolTab)
        #expect(WorkspaceTab.Kind.diagram.isToolTab)
        #expect(!WorkspaceTab.Kind.activityMonitor.isToolTab)
        #expect(!WorkspaceTab.Kind.jobQueue.isToolTab)
        #expect(!WorkspaceTab.Kind.query.isToolTab)
        #expect(!WorkspaceTab.Kind.psql.isToolTab)
    }

    // MARK: Monitor tiles (37.4)

    private func event(_ seconds: TimeInterval, duration: Int64? = 10, cpu: Int? = 2, reads: Int64? = 5) -> SQLServerProfilerEvent {
        SQLServerProfilerEvent(eventName: "SQL:BatchCompleted", timestamp: Date(timeIntervalSinceReferenceDate: seconds),
                               textData: nil, databaseName: nil, loginName: nil,
                               duration: duration, cpu: cpu, reads: reads, writes: nil, spid: nil)
    }

    @Test func profilerEventsFallIntoTenSecondStretchesWithGapsKept() {
        let buckets = ProfilerFigures.buckets(for: [event(1_000), event(1_004, duration: 30), event(1_031)])
        #expect(buckets.count == 4)
        #expect(buckets[0].events == 2)
        #expect(buckets[0].averageDuration == 20)
        #expect(buckets[1].events == 0 && buckets[2].events == 0)
        #expect(buckets[3].events == 1)
        #expect(buckets[0].cpu == 4 && buckets[0].reads == 10)
    }

    @Test func profilerShowsAtMostThirtyStretches() {
        let events = (0..<50).map { event(Double($0) * ProfilerFigures.bucket) }
        #expect(ProfilerFigures.buckets(for: events).count == ProfilerFigures.bucketsShown)
        #expect(ProfilerFigures.buckets(for: []).isEmpty)
    }

    @Test func profilerHasFourTiles() {
        let metrics = ProfilerFigures.metrics(for: [event(1_000)])
        #expect(metrics.map(\.label) == ["Events", "Duration", "CPU", "Reads"])
        #expect(metrics[0].data.last?.value == 1)
    }

    @Test func extendedEventsCountsSessionsAndCapturedEvents() {
        let sessions = [SQLServerXESession(name: "a", createTime: nil, startupState: false, isRunning: true),
                        SQLServerXESession(name: "b", createTime: nil, startupState: false, isRunning: false)]
        let events = [SQLServerXEEventData(timestamp: Date(timeIntervalSinceReferenceDate: 0), eventName: "x", fields: [:]),
                      SQLServerXEEventData(timestamp: Date(timeIntervalSinceReferenceDate: 25), eventName: "y", fields: [:])]
        #expect(ExtendedEventsFigures.eventCounts(events).map(\.count) == [1, 0, 1])
        let metrics = ExtendedEventsFigures.metrics(sessions: sessions, events: events)
        #expect(metrics.map(\.label) == ["Sessions", "Running", "Events", "Event types"])
        #expect(metrics[0].data.last?.value == 2)
        #expect(metrics[1].data.last?.value == 1)
        #expect(metrics[3].data.last?.value == 2)
    }

    // MARK: Apply bar (37.4)

    @Test func theApplyBarCountsChanges() {
        #expect(ToolTabApplyBar.summary(count: 1) == "1 change")
        #expect(ToolTabApplyBar.summary(count: 3) == "3 changes")
    }
}
