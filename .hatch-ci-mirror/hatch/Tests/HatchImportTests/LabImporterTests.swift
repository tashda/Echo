import XCTest
import HatchCore
@testable import HatchImport

final class LabImporterTests: XCTestCase {
    var store: HatchStore!
    var project: Project!

    override func setUpWithError() throws { (store, project) = try makeStore() }

    private func realState() throws -> [String: JSONValue] {
        try requireEcho()
        let root = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: Paths.labState))
        return root.objectValue!
    }

    private func importReal(catalog: Bool = false, enqueue: Bool = false) throws -> ImportReport {
        try requireEcho()
        let cat = catalog ? LabCatalog.load(echoLabSources: Paths.labSources) : .empty
        return try LabImporter.importState(file: Paths.labState, project: project, store: store, options: ImportOptions(enqueueSync: enqueue, catalog: cat))
    }

    // MARK: Real data

    func testEveryRealPageImports() throws {
        let state = try realState()
        let report = try importReal()
        XCTAssertEqual(report.pagesSeen, state.count)
        XCTAssertEqual(report.created, state.count)
        XCTAssertEqual(report.skipped, [])
        XCTAssertEqual(try store.tickets(TicketFilter(projectId: project.id)).count, state.count)
        XCTAssertTrue(try store.tickets(TicketFilter(projectId: project.id)).allSatisfy { $0.type == .proposal })
    }

    func testRealStatusesMap() throws {
        let state = try realState()
        let report = try importReal()
        // The real file holds 42 In Echo, 3 Accepted and 1 Judging.
        for (id, page) in state {
            let expected = LabImporter.hatchStatus(forLabStatus: page["status"]!.stringValue!)!
            let ticket = try store.ticket(id: report.ticketIds[id]!)!
            XCTAssertEqual(ticket.status, expected, id)
            XCTAssertEqual(ticket.turn, expected.turn, id)
        }
        XCTAssertEqual(report.byStatus["merged"], 42)
        XCTAssertEqual(report.byStatus["accepted"], 3)
        XCTAssertEqual(report.byStatus["your-call"], 1)
    }

    func testRealPicksAndVerdictsRoundTrip() throws {
        let state = try realState()
        let report = try importReal()
        var pickCount = 0, verdictCount = 0
        for (id, page) in state {
            let tid = report.ticketIds[id]!
            let picks = Dictionary(uniqueKeysWithValues: try store.picks(ticketId: tid).map { ($0.topic, $0.choice) })
            let expected = page["picks"]!.objectValue!.mapValues { $0.stringValue! }
            XCTAssertEqual(picks, expected, id)
            pickCount += expected.count
            let verdicts = try store.verdicts(ticketId: tid)
            let expectedVerdicts = page["verdicts"]!.objectValue!
            XCTAssertEqual(verdicts.count, expectedVerdicts.count, id)
            for v in verdicts { XCTAssertEqual(expectedVerdicts["\(v.topic)/\(v.option)"]?.stringValue, v.verdict, id) }
            verdictCount += expectedVerdicts.count
        }
        XCTAssertEqual(report.picks, pickCount)
        XCTAssertEqual(report.verdicts, verdictCount)
        XCTAssertGreaterThan(pickCount, 300)
    }

    func testPickNoteIsKeptOnThePickAndAsNote() throws {
        let report = try importReal()
        let tid = report.ticketIds["ongoing.editor-caret-line-r28"]!
        let pick = try store.picks(ticketId: tid).first { $0.topic == "selectionShape" }
        XCTAssertEqual(pick?.choice, "Rounded 3pt")
        XCTAssertTrue(pick?.note?.hasPrefix("I need more options") ?? false)
        let note = try store.notes(ticketId: tid).first { $0.context?["source"]?.stringValue == "pickNote" }
        XCTAssertEqual(note?.context?["topic"]?.stringValue, "selectionShape")
    }

    func testCommentsKeepOriginalTimesAndAuthor() throws {
        let state = try realState()
        let report = try importReal()
        let id = "ongoing.content-during-slide-r26"
        let notes = try store.notes(ticketId: report.ticketIds[id]!)
        let comment = try XCTUnwrap(notes.first { $0.kind == .comment })
        XCTAssertEqual(comment.author, "owner")
        XCTAssertEqual(comment.at, iso("2026-10-01T09:54:10Z"))
        XCTAssertTrue(comment.body.hasPrefix("Review of Tab content while the tree slides"))
        XCTAssertTrue(notes.contains { $0.kind == .note && $0.context?["source"]?.stringValue == "generalNote" })
        let totalComments = state.values.map { $0["comments"]!.arrayValue!.count }.reduce(0, +)
        let imported = try store.tickets(TicketFilter(projectId: project.id)).flatMap { try store.notes(ticketId: $0.id) }.filter { $0.context?["source"]?.stringValue == "lab-comment" }
        XCTAssertEqual(imported.count, totalComments)
    }

    func testHistoryEventsAreDatedAndOrdered() throws {
        let state = try realState()
        let report = try importReal()
        let id = "ongoing.editor-caret-line-r28"
        let events = try store.events(ticketId: report.ticketIds[id]!)
        let history = events.filter { $0.kind == "history" }
        XCTAssertEqual(history.map(\.at), [iso("2026-10-01T11:01:39Z"), iso("2026-10-01T11:40:00Z")])
        XCTAssertEqual(history.first?.payload["text"]?.stringValue, "Accepted with picks")
        XCTAssertEqual(events.first?.kind, "created")
        XCTAssertEqual(events.first?.at, iso("2026-10-01T11:01:39Z"))
        XCTAssertEqual(events.filter { $0.kind == "imported" }.count, 1)
        // Every history line in the file is an event.
        let total = state.values.map { $0["history"]!.arrayValue!.count }.reduce(0, +)
        let imported = try store.tickets(TicketFilter(projectId: project.id)).flatMap { try store.events(ticketId: $0.id, kinds: ["history"]) }
        XCTAssertEqual(imported.count, total)
        // Ticket times follow the history, not the import time.
        XCTAssertEqual(try store.ticket(id: report.ticketIds[id]!)?.updatedAt, iso("2026-10-01T11:40:00Z"))
    }

    func testRevisionsKeepTheirNumbers() throws {
        let state = try realState()
        let report = try importReal()
        let id = "ongoing.content-during-slide-r26"
        let revisions = try store.revisions(ticketId: report.ticketIds[id]!)
        XCTAssertEqual(revisions.map(\.n), [2])
        XCTAssertEqual(revisions[0].at, iso("2026-10-01T10:09:20Z"))
        XCTAssertEqual(revisions[0].added.count, 1)
        XCTAssertEqual(try store.ticket(id: report.ticketIds[id]!)?.revision, 2)
        XCTAssertEqual(report.revisions, state.values.map { $0["revisions"]!.arrayValue!.count }.reduce(0, +))
    }

    func testNeedsMoreAndTakenBy() throws {
        let report = try importReal()
        let tid = report.ticketIds["ongoing.server-header-look-r30"]!
        let note = try store.notes(ticketId: tid).first { $0.context?["source"]?.stringValue == "needsMore" }
        XCTAssertEqual(note?.body, "Needs more options: style")
        let lane = report.ticketIds["ongoing.editor-gutter-lane-r28"]!
        XCTAssertTrue(try store.events(ticketId: lane, kinds: ["taken"]).contains { $0.actor == "lane-agent" })
        XCTAssertNil(try store.ticket(id: lane)?.takenBy, "a Merged ticket is not held by an agent")
    }

    func testImportingTwiceChangesNothing() throws {
        let first = try importReal()
        func snapshot() throws -> [Int] {
            let ts = try store.tickets(TicketFilter(projectId: project.id))
            return [ts.count, try ts.map { try store.notes(ticketId: $0.id).count }.reduce(0, +),
                    try ts.map { try store.events(ticketId: $0.id).count }.reduce(0, +),
                    try ts.map { try store.picks(ticketId: $0.id).count }.reduce(0, +)]
        }
        let before = try snapshot()
        let second = try importReal()
        XCTAssertEqual(second.created, 0)
        XCTAssertEqual(second.alreadyImported, first.created)
        XCTAssertEqual(second.ticketIds, first.ticketIds)
        XCTAssertEqual(try snapshot(), before)
    }

    func testNothingIsQueuedForGitHubByDefault() throws {
        _ = try importReal()
        XCTAssertEqual(try store.pendingSync().count, 0)
        XCTAssertEqual(try store.db.query("SELECT COUNT(*) AS n FROM sync_log") { $0.int("n")! }.first, 0)
    }

    func testEnqueueSyncQueuesOneCreatePerTicket() throws {
        let report = try importReal(enqueue: true)
        let ops = try store.pendingSync()
        XCTAssertEqual(ops.filter { $0.op == "issue.create" }.count, report.created)
    }

    func testBodyEndsWithTheMarker() throws {
        let report = try importReal()
        let id = "ongoing.editor-gutter-r28"
        let t = try store.ticket(id: report.ticketIds[id]!)!
        XCTAssertEqual(t.body.split(separator: "\n").last.map(String.init), "lab-page: \(id)")
        XCTAssertEqual(t.title, "Editor gutter")
        XCTAssertNil(t.area)
    }

    func testCatalogGivesTitlesAreasAndRoundText() throws {
        try requireEcho(Paths.labSources)
        let report = try importReal(catalog: true)
        let t = try store.ticket(id: report.ticketIds["ongoing.editor-caret-line-r28"]!)!
        XCTAssertEqual(t.title, "Editor: caret, current line and selection")
        XCTAssertEqual(t.area, "Editor and running")
        XCTAssertTrue(t.body.contains("**Round 28"), t.body)
        let areas = Set(try store.tickets(TicketFilter(projectId: project.id)).compactMap(\.area))
        XCTAssertGreaterThanOrEqual(areas.count, 5)
        XCTAssertEqual(try store.tickets(TicketFilter(projectId: project.id)).filter { $0.area == nil }.count, 0, "every real page has a group")
    }

    // MARK: Small synthetic data

    private let synthetic = """
    {
      "decided.one-r5": {"status": "Decided", "comments": [], "generalNote": "Go with A, see TABS-2.7 and TABS-2.8",
         "history": [{"date": "2026-09-01T10:00:00Z", "text": "Confirmed in Echo"}], "revisions": [], "picks": {"look": "A"},
         "pickNotes": {}, "optionNotes": {"look/a": "nice"}, "verdicts": {"look/a": "pick", "look/b": "no", "look/c": "bogus"}, "needsMore": []},
      "ongoing.two-r6": {"status": "New feedback", "comments": [{"date": "2026-09-02T10:00:00.250Z", "id": "x", "text": "More please"}],
         "history": [], "revisions": [], "picks": {}, "verdicts": {}},
      "ongoing.three-r7": {"status": "Accepted", "comments": [{"date": "yesterday", "text": "odd date"}], "picks": {"n": 3}},
      "ongoing.four-r8": {"status": "Wibble"},
      "ongoing.five-r9": {"comments": []},
      "ongoing.six-r10": 42
    }
    """

    func testSyntheticPagesCoverEveryStatusAndOddInput() throws {
        let report = try LabImporter.importState(data: Data(synthetic.utf8), project: project, store: store)
        XCTAssertEqual(report.pagesSeen, 6)
        XCTAssertEqual(report.created, 3)
        XCTAssertEqual(report.skipped.count, 3)
        XCTAssertTrue(report.skipped.contains { $0.contains("Wibble") })
        XCTAssertTrue(report.warnings.contains { $0.contains("yesterday") })
        XCTAssertTrue(report.warnings.contains { $0.contains("verdict") })
        func ticket(_ id: String) throws -> Ticket { try store.ticket(id: report.ticketIds[id]!)! }
        XCTAssertEqual(try ticket("decided.one-r5").status, .done)
        XCTAssertEqual(try ticket("ongoing.two-r6").status, .revising)
        XCTAssertEqual(try ticket("ongoing.three-r7").status, .accepted)
        XCTAssertEqual(try store.picks(ticketId: report.ticketIds["ongoing.three-r7"]!).first?.choice, "3")
    }

    func testDecidedPageGetsADecisionRow() throws {
        let report = try LabImporter.importState(data: Data(synthetic.utf8), project: project, store: store)
        let decisions = try store.decisions(projectId: project.id)
        XCTAssertEqual(decisions.count, 1)
        XCTAssertEqual(report.decisions, 1)
        XCTAssertEqual(decisions[0].summary, "Go with A, see TABS-2.7 and TABS-2.8")
        XCTAssertEqual(decisions[0].specCodes, ["TABS-2.7", "TABS-2.8"])
        XCTAssertEqual(decisions[0].at, iso("2026-09-01T10:00:00Z"))
        XCTAssertEqual(decisions[0].ticket.status, .done)
    }

    func testFractionalSecondsAndOptionNotes() throws {
        let report = try LabImporter.importState(data: Data(synthetic.utf8), project: project, store: store)
        let two = try store.notes(ticketId: report.ticketIds["ongoing.two-r6"]!)
        XCTAssertEqual(two.first?.at.timeIntervalSince1970 ?? 0, iso("2026-09-02T10:00:00Z").timeIntervalSince1970 + 0.25, accuracy: 0.01)
        let one = try store.notes(ticketId: report.ticketIds["decided.one-r5"]!)
        let option = one.first { $0.context?["source"]?.stringValue == "optionNote" }
        XCTAssertEqual(option?.context?["option"]?.stringValue, "a")
        XCTAssertEqual(option?.body, "nice")
    }

    func testIdsThatShareAPrefixDoNotCollide() throws {
        let json = #"{"a.b": {"status": "Judging"}, "a.b-c": {"status": "Judging"}}"#
        let r1 = try LabImporter.importState(data: Data(json.utf8), project: project, store: store)
        XCTAssertEqual(r1.created, 2)
        let r2 = try LabImporter.importState(data: Data(json.utf8), project: project, store: store)
        XCTAssertEqual(r2.created, 0)
        XCTAssertEqual(r2.alreadyImported, 2)
        XCTAssertNotEqual(r2.ticketIds["a.b"], r2.ticketIds["a.b-c"])
    }

    func testBrokenFilesThrowInsteadOfCrashing() {
        XCTAssertThrowsError(try LabImporter.importState(data: Data("nope".utf8), project: project, store: store))
        XCTAssertThrowsError(try LabImporter.importState(data: Data("[1,2]".utf8), project: project, store: store))
        XCTAssertThrowsError(try LabImporter.importState(file: URL(fileURLWithPath: "/nonexistent/lab-state.json"), project: project, store: store))
    }

    func testRevisionNumbersThatSkipAreKept() throws {
        let json = #"{"p.x": {"status": "Judging", "revisions": [{"number": 4, "summary": "Four", "changes": ["a", "b"], "date": "2026-09-03T10:00:00Z"}]}}"#
        let report = try LabImporter.importState(data: Data(json.utf8), project: project, store: store)
        XCTAssertEqual(try store.revisions(ticketId: report.ticketIds["p.x"]!).map(\.n), [4])
    }

    func testHumanTitle() {
        XCTAssertEqual(LabImporter.humanTitle("ongoing.content-during-slide-r26"), "Content during slide")
        XCTAssertEqual(LabImporter.humanTitle("decided.window-canvas-and-cards"), "Window canvas and cards")
        XCTAssertEqual(LabImporter.humanTitle("plain"), "Plain")
        XCTAssertEqual(LabImporter.humanTitle("ongoing.r28"), "ongoing.r28")
    }

    func testStatusMapping() {
        XCTAssertEqual(LabImporter.hatchStatus(forLabStatus: "Judging"), .yourCall)
        XCTAssertEqual(LabImporter.hatchStatus(forLabStatus: "New feedback"), .revising)
        XCTAssertEqual(LabImporter.hatchStatus(forLabStatus: "Accepted"), .accepted)
        XCTAssertEqual(LabImporter.hatchStatus(forLabStatus: " in echo "), .merged)
        XCTAssertEqual(LabImporter.hatchStatus(forLabStatus: "Decided"), .done)
        XCTAssertNil(LabImporter.hatchStatus(forLabStatus: "Archived"))
    }

    // MARK: Catalog

    func testRoundInfoParsesTheRealFile() throws {
        try requireEcho(Paths.labSources)
        let text = try String(contentsOf: Paths.labSources.appendingPathComponent("Rounds/LabRounds.swift"), encoding: .utf8)
        let rounds = LabCatalog.parseRounds(text)
        XCTAssertEqual(rounds.count, 37)
        let r34 = try XCTUnwrap(rounds.first { $0.id == "r34" })
        XCTAssertEqual(r34.title, "Refresh and the activity signal")
        XCTAssertTrue(r34.asked.hasPrefix("After a query runs"))
        XCTAssertEqual(r34.pageIDs, ["ongoing.refresh-and-activity-r34"])
        XCTAssertTrue(rounds.allSatisfy { !$0.pageIDs.isEmpty })
    }

    func testRoundInfoToleratesOddLines() {
        let source = """
        Info(id: "r1", label: "Round 1", title: "Fine", date: "1 Oct", asked: "a" + "b", outcome: "ok", pageIDs: ["p.one"]),
        Info(id: "r2", title: "No pages and \\(interpolated)"),
        Info(title: "no id"),
        Info(id: "r3", title: "Unterminated,
        Info(
        // Info(id: "commented", title: "x")
        """
        let rounds = LabCatalog.parseRounds(source)
        XCTAssertEqual(rounds.first?.asked, "ab")
        XCTAssertTrue(rounds.contains { $0.id == "r2" })
        XCTAssertFalse(rounds.contains { $0.id == "commented" })
        XCTAssertEqual(LabCatalog.parseRounds("").count, 0)
        XCTAssertEqual(LabCatalog.parsePages("round(id: ").count, 0)
        XCTAssertEqual(LabCatalog.load(echoLabSources: URL(fileURLWithPath: "/nonexistent")).pages.count, 0)
    }

    func testPageCatalogDropsRoundSuffixFromTitles() {
        let source = #"static let x = LabPage.round(id: "ongoing.a-r1", group: "Tabs", title: "Tab bar · round 1", symbol: "x", summary: "S")"#
        let pages = LabCatalog.parsePages(source)
        XCTAssertEqual(pages.first, LabCatalog.Page(id: "ongoing.a-r1", group: "Tabs", title: "Tab bar", summary: "S"))
    }
}
