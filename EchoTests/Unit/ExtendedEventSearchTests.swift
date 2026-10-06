import Testing
import SQLServerKit
@testable import Echo

@Suite("Extended event search")
struct ExtendedEventSearchTests {
    private let events = [
        SQLServerXEEvent(packageName: "sqlserver", eventName: "sql_statement_completed", description: nil),
        SQLServerXEEvent(packageName: "sqlserver", eventName: "rpc_completed", description: nil),
        SQLServerXEEvent(packageName: "sqlos", eventName: "wait_completed", description: nil),
        SQLServerXEEvent(packageName: "XtpEngine", eventName: "xtp_transaction_abort", description: nil),
    ]

    @Test func noQueryListsEverythingGroupedByPackage() {
        let search = ExtendedEventSearch(events: events, query: "")
        #expect(search.groups.map(\.packageName) == ["XtpEngine", "sqlos", "sqlserver"])
        #expect(search.groups.last?.events.map(\.eventName) == ["rpc_completed", "sql_statement_completed"])
        #expect(search.count == 4)
    }

    @Test func aQueryMatchesTheEventNameIgnoringCase() {
        let search = ExtendedEventSearch(events: events, query: "SQL_STAT")
        #expect(search.groups.flatMap(\.events).map(\.id) == ["sqlserver.sql_statement_completed"])
    }

    @Test func wordsMayNameThePackageAndTheEvent() {
        #expect(ExtendedEventSearch(events: events, query: "sqlserver completed").count == 2)
        #expect(ExtendedEventSearch(events: events, query: "sqlos.wait").first?.id == "sqlos.wait_completed")
    }

    @Test func aQueryThatMatchesNothingLeavesNoGroups() {
        let search = ExtendedEventSearch(events: events, query: "zzz")
        #expect(search.groups.isEmpty)
        #expect(search.first == nil)
    }

    @Test func aLongListIsGroupedQuickly() {
        let many = (0..<5000).map { SQLServerXEEvent(packageName: "package\($0 % 40)", eventName: "event_\($0)", description: nil) }
        let search = ExtendedEventSearch(events: many, query: "event_49")
        #expect(search.count == 111)
    }
}
