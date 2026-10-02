import Foundation
import Testing
@testable import Echo

@Suite("Connect Trail Listing")
struct ConnectTrailListingTests {
    private func entry(_ name: String, host: String = "host1", database: String = "data", folder: String? = nil) -> ConnectTrailEntry {
        ConnectTrailEntry(id: UUID(), name: name, host: host, database: database, folder: folder)
    }

    @Test func detailIsHostThenDatabase() {
        #expect(entry("a", host: "db1", database: "app").detail == "db1 · app")
        #expect(entry("a", host: "db1", database: "").detail == "db1")
    }

    @Test func connectionsInNoFolderComeFirstUnderSaved() {
        let sections = ConnectTrailListing.sections([
            entry("zeta", folder: "corporate"), entry("beta"), entry("alpha"), entry("kilo", folder: "archive"),
        ], query: "")
        #expect(sections.map(\.title) == ["Saved", "archive", "corporate"])
        #expect(sections[0].entries.map(\.name) == ["alpha", "beta"])
    }

    @Test func headingsWithoutMatchesAreLeftOut() {
        let sections = ConnectTrailListing.sections([entry("alpha"), entry("kilo", folder: "corporate")], query: "kil")
        #expect(sections.map(\.title) == ["corporate"])
    }

    @Test func searchMatchesNameAndHostAndDatabaseIgnoringCase() {
        let all = [
            entry("Test Postgres", host: "localhost", database: "postgres"),
            entry("prod", host: "db.example.com", database: "Sales"),
        ]
        #expect(ConnectTrailListing.matches(all, query: "POSTGRES").map(\.name) == ["Test Postgres"])
        #expect(ConnectTrailListing.matches(all, query: "example").map(\.name) == ["prod"])
        #expect(ConnectTrailListing.matches(all, query: "sales").map(\.name) == ["prod"])
        #expect(ConnectTrailListing.matches(all, query: "  ").count == 2)
        #expect(ConnectTrailListing.matches(all, query: "nothing").isEmpty)
    }

    @Test func returnConnectsTheFirstMatch() {
        let sections = ConnectTrailListing.sections([entry("beta"), entry("alpha", folder: "corporate"), entry("alpine")], query: "al")
        let ids = ConnectTrailListing.orderedIDs(sections)
        #expect(ids.count == 2)
        let first = ConnectTrailListing.highlight(current: nil, in: ids)
        #expect(first == sections[0].entries[0].id)
        #expect(sections[0].entries[0].name == "alpine")
    }

    @Test func highlightStaysWhileListedAndFallsBackToTheFirst() {
        let a = UUID(), b = UUID(), gone = UUID()
        #expect(ConnectTrailListing.highlight(current: b, in: [a, b]) == b)
        #expect(ConnectTrailListing.highlight(current: gone, in: [a, b]) == a)
        #expect(ConnectTrailListing.highlight(current: a, in: []) == nil)
    }

    @Test func arrowsMoveTheHighlightAndStopAtTheEnds() {
        let ids = [UUID(), UUID(), UUID()]
        #expect(ConnectTrailListing.moved(from: ids[0], in: ids, by: 1) == ids[1])
        #expect(ConnectTrailListing.moved(from: ids[2], in: ids, by: 1) == ids[2])
        #expect(ConnectTrailListing.moved(from: ids[0], in: ids, by: -1) == ids[0])
        #expect(ConnectTrailListing.moved(from: nil, in: ids, by: 1) == ids[0])
        #expect(ConnectTrailListing.moved(from: nil, in: ids, by: -1) == ids[2])
        #expect(ConnectTrailListing.moved(from: nil, in: [], by: 1) == nil)
    }
}
