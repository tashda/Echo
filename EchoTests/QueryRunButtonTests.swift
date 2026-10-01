import Foundation
import Testing
@testable import Echo

@Suite("Run button words (round 20)")
struct QueryRunButtonTests {
    // MARK: Tooltip (U1, T1, J1, ⌘↩ toggle)

    @Test func readyTooltipSaysWhereItRuns() {
        #expect(QueryRunButtonText.help(.ready(runsSelection: false), database: "employees", server: "Prod SQL")
                == "Run in employees on Prod SQL (⌘↩)")
        #expect(QueryRunButtonText.help(.ready(runsSelection: true), database: "employees", server: "Prod SQL")
                == "Run Selection in employees on Prod SQL (⌘↩)")
    }

    @Test func readyTooltipLeavesOutWhatItDoesNotKnow() {
        #expect(QueryRunButtonText.help(.ready(runsSelection: false), database: nil, server: "Prod SQL") == "Run on Prod SQL (⌘↩)")
        #expect(QueryRunButtonText.help(.ready(runsSelection: false), database: "employees", server: "  ") == "Run in employees (⌘↩)")
        #expect(QueryRunButtonText.help(.ready(runsSelection: false), database: "", server: nil) == "Run (⌘↩)")
    }

    @Test func otherStatesSayWhatAClickDoes() {
        #expect(QueryRunButtonText.help(.nothingToRun, database: "employees", server: "Prod SQL") == "Type a query to run")
        #expect(QueryRunButtonText.help(.running, database: "employees", server: "Prod SQL") == "Stop (⌘↩)")
        #expect(QueryRunButtonText.help(.stopping, database: "employees", server: "Prod SQL") == "Stopping")
    }

    // MARK: Timer (K1)

    @Test(arguments: [
        (0.0, "0 s"), (4.9, "4 s"), (59.99, "59 s"), (60, "1:00"), (65, "1:05"),
        (3599, "59:59"), (3600, "1:00:00"), (3725, "1:02:05"), (-3, "0 s"),
    ])
    func elapsedTime(seconds: Double, expected: String) {
        #expect(ElapsedTimeText.format(seconds) == expected)
    }

    // MARK: Long query notification (N1)

    @Test func notifiesOnlyForLongQueriesWhileAway() {
        #expect(LongQueryNotice.shouldNotify(duration: 30, echoIsActive: false))
        #expect(LongQueryNotice.shouldNotify(duration: 125, echoIsActive: false))
        #expect(!LongQueryNotice.shouldNotify(duration: 29.9, echoIsActive: false))
        #expect(!LongQueryNotice.shouldNotify(duration: 125, echoIsActive: true))
        #expect(!LongQueryNotice.shouldNotify(duration: nil, echoIsActive: false))
    }

    @Test func noticeNamesTheTabAndTheTime() {
        #expect(LongQueryNotice.title(succeeded: true) == "Query finished")
        #expect(LongQueryNotice.title(succeeded: false) == "Query failed")
        #expect(LongQueryNotice.body(tabTitle: "Query 1", succeeded: true, duration: 134) == "Query 1 finished in 2:14")
        #expect(LongQueryNotice.body(tabTitle: "Query 2", succeeded: false, duration: 45) == "Query 2 failed after 45 s")
    }
}

/// Run widens for the time only once a query has run 3 s (owner, after round 31).
@Suite("Run button time reveal")
struct QueryRunTimeRevealTests {
    @Test func theTimeWaitsThreeSecondsFromTheStart() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        #expect(QueryRunTimeReveal.wait(since: start, now: start) == 3)
        #expect(QueryRunTimeReveal.wait(since: start, now: start.addingTimeInterval(1)) == 2)
        #expect(QueryRunTimeReveal.wait(since: start, now: start.addingTimeInterval(5)) == 0)
    }

    @Test func anUnknownStartWaitsTheWholeTime() {
        #expect(QueryRunTimeReveal.wait(since: nil) == 3)
    }
}
