import XCTest
@testable import HatchCore

final class StoreTests: XCTestCase {
    var store: HatchStore!
    var project: Project!

    override func setUpWithError() throws {
        store = try HatchStore.inMemory()
        project = try store.upsertProject(key: "echo", name: "Echo", config: ProjectConfig(name: "Echo", ticketsRepo: "acme/tickets", repos: [
            RepoConfig(role: .app, remote: "acme/app", branch: "dev", testPlans: ["UnitTests"]),
        ], areas: [AreaConfig(name: "Notifications", paths: ["Echo/Notifications/**"], specPrefix: "NOTIF")]))
    }

    func ticket(_ type: TicketType = .proposal, _ title: String = "Toast spacing") throws -> Ticket {
        try store.createTicket(projectId: project.id, type: type, title: title, body: "Toasts feel cramped in dark mode.")
    }

    func testDatabaseHasFTS5() { XCTAssertTrue(store.db.hasFTS5) }

    func testDraftsStayLocalUntilSubmitted() throws {
        let t = try ticket()
        XCTAssertEqual(t.status, .draft)
        XCTAssertEqual(t.displayNumber, "new-\(t.id)")
        XCTAssertTrue(try store.pendingSync().isEmpty, "a draft must not be queued for GitHub")
        _ = try store.move(t.id, to: .checking, actor: .owner)
        let ops = try store.pendingSync()
        XCTAssertEqual(ops.map(\.op), ["issue.create"])
        XCTAssertEqual(ops[0].payload["labels"]?.arrayValue?.compactMap(\.stringValue).sorted(), ["project:echo", "status:checking", "type:proposal"])
    }

    func testStatusChangesCoalesceIntoOneLabelUpdate() throws {
        let t = try ticket(.tweak)
        _ = try store.move(t.id, to: .checking, actor: .owner)
        try store.applyIssueCreated(ticketId: t.id, ghNumber: 151)
        try store.db.execute("UPDATE sync_log SET state = 'done'")
        _ = try store.move(t.id, to: .ready, actor: .hatch)
        _ = try store.move(t.id, to: .building, actor: .agent)
        let pending = try store.pendingSync()
        XCTAssertEqual(pending.map(\.op), ["issue.labels"], "two moves should leave a single label sync")
        XCTAssertTrue(pending[0].payload["labels"]!.arrayValue!.contains(.string("status:building")))
    }

    func testPendingCreateAbsorbsLaterEdits() throws {
        let t = try ticket()
        _ = try store.move(t.id, to: .checking, actor: .owner)
        try store.update(t.id, title: "Toast spacing in dark mode", actor: .owner)
        _ = try store.move(t.id, to: .needsAnswers, actor: .agent)
        let ops = try store.pendingSync()
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops[0].payload["title"]?.stringValue, "Toast spacing in dark mode")
        XCTAssertTrue(ops[0].payload["labels"]!.arrayValue!.contains(.string("status:needs-answers")))
    }

    func testIllegalMovesAreRefused() throws {
        let t = try ticket()
        XCTAssertThrowsError(try store.move(t.id, to: .accepted, actor: .owner))
        XCTAssertThrowsError(try store.move(t.id, to: .yourCall, actor: .agent))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .draft)
    }

    func testOriginalTextIsKept() throws {
        let t = try ticket()
        try store.update(t.id, title: "Better title", body: "Rewritten by Iris", actor: .agent)
        let after = try store.ticket(id: t.id)!
        XCTAssertEqual(after.title, "Better title")
        XCTAssertEqual(after.originalTitle, "Toast spacing")
        XCTAssertEqual(after.originalBody, "Toasts feel cramped in dark mode.")
    }

    func testTypeCanOnlyChangeBeforeWorkStarts() throws {
        let t = try ticket(.bug, "Sidebar flickers")
        let q = try store.changeType(t.id, to: .question, actor: .owner, reason: "no steps to reproduce")
        XCTAssertEqual(q.type, .question)
        _ = try store.move(t.id, to: .checking, actor: .owner)
        _ = try store.move(t.id, to: .ready, actor: .agent)
        _ = try store.move(t.id, to: .preparing, actor: .agent)
        XCTAssertThrowsError(try store.changeType(t.id, to: .sketch, actor: .owner))
    }

    func testQuestionsMoveTheTurnAndAnsweringAllMovesToReady() throws {
        let t = try ticket()
        _ = try store.move(t.id, to: .checking, actor: .owner)
        let q1 = try store.ask(t.id, text: "Also at Compact density?", suggestions: ["Yes", "No"], by: "Iris")
        let q2 = try store.ask(t.id, text: "Does this replace #118?", by: "Iris")
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .needsAnswers)
        XCTAssertEqual(try store.ticket(id: t.id)?.turn, .you)
        _ = try store.answer(questionId: q1.id, text: "Yes")
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .needsAnswers, "one question is still open")
        let done = try store.answer(questionId: q2.id, text: "No")
        XCTAssertEqual(done.status, .ready)
        XCTAssertEqual(q1.suggestions, ["Yes", "No"])
    }

    func testAskFromYourCallSendsItBackToTheAgent() throws {
        let t = try walk(ticket(), to: .yourCall)
        let n = try store.addNote(t.id, kind: .ask, author: "owner", body: "Why 16pt?")
        XCTAssertEqual(n.kind, .ask)
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .revising)
        XCTAssertEqual(try store.ticket(id: t.id)?.turn, .agent)
    }

    func testPlainNoteDoesNotMoveTheTurn() throws {
        let t = try walk(ticket(), to: .yourCall)
        _ = try store.addNote(t.id, kind: .note, author: "owner", body: "Looks tight in dark.")
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .yourCall)
    }

    func testParkAndResume() throws {
        let t = try walk(ticket(.tweak), to: .building)
        let parked = try store.move(t.id, to: .parked, actor: .owner)
        XCTAssertEqual(parked.prevStatus, .building)
        XCTAssertEqual(parked.turn, .paused)
        let back = try store.resume(t.id, actor: .owner)
        XCTAssertEqual(back.status, .building)
    }

    func testThemeCompletesWhenChildrenAreDone() throws {
        let theme = try ticket(.theme, "Toasts")
        let a = try store.createTicket(projectId: project.id, type: .tweak, title: "A", parentId: theme.id)
        let b = try store.createTicket(projectId: project.id, type: .tweak, title: "B", parentId: theme.id)
        _ = try walk(a, to: .done)
        XCTAssertEqual(try store.themeProgress(theme.id).done, 1)
        XCTAssertNotEqual(try store.ticket(id: theme.id)?.status, .done)
        _ = try walk(b, to: .done)
        XCTAssertEqual(try store.ticket(id: theme.id)?.status, .done)
    }

    func testSimilarTicketsFindRelatedWork() throws {
        _ = try store.createTicket(projectId: project.id, type: .proposal, title: "Toast stacking limit", body: "Notification toasts stack too deep")
        _ = try store.createTicket(projectId: project.id, type: .bug, title: "Sidebar flickers", body: "Connection drop causes flicker")
        let hits = try store.similarTickets(projectId: project.id, title: "Notification toast spacing", body: "")
        XCTAssertEqual(hits.first?.ticket.title, "Toast stacking limit")
        XCTAssertFalse(hits.contains { $0.ticket.title == "Sidebar flickers" })
        let found = try store.tickets(TicketFilter(projectId: project.id, text: "flick"))
        XCTAssertEqual(found.map(\.title), ["Sidebar flickers"])
    }

    func testSpecSearch() throws {
        try store.upsertSpecItems(projectId: project.id, items: [
            (code: "NOTIF-1.2", area: "Notifications", text: "Toast padding is 12pt on all sides", source: "notifications.md"),
            (code: "TABS-2.7", area: "Tabs", text: "Tab overflow shows a menu", source: "tabs.md"),
        ])
        let hits = try store.searchSpec(projectId: project.id, query: "toast padding spacing")
        XCTAssertEqual(hits.first?.code, "NOTIF-1.2")
    }

    func testClaimsQueueTheLaterTicketAndWakeItOnRelease() throws {
        let a = try walk(ticket(.tweak, "Row density"), to: .building)
        let b = try walk(ticket(.tweak, "Row hover"), to: .building)
        XCTAssertEqual(try store.claim(ticketId: a.id, repoId: nil, paths: ["Echo/Explorer/RowView.swift"]), .granted)
        let outcome = try store.claim(ticketId: b.id, repoId: nil, paths: ["Echo/Explorer/**"])
        XCTAssertEqual(outcome, .queued(behind: [a.id]))
        let blocked = try store.ticket(id: b.id)!
        XCTAssertEqual(blocked.status, .blocked)
        XCTAssertEqual(blocked.prevStatus, .building)
        // A finishes: B is released and resumes by itself.
        _ = try store.move(a.id, to: .toVerify, actor: .hatch)
        try store.releaseClaims(ticketId: a.id)
        let woken = try store.ticket(id: b.id)!
        XCTAssertEqual(woken.status, .building)
        XCTAssertEqual(try store.claims(ticketId: b.id).first?.state, "held")
    }

    func testStackLetsTheLaterTicketProceed() throws {
        let a = try walk(ticket(.tweak, "A"), to: .building)
        let b = try walk(ticket(.tweak, "B"), to: .building)
        try store.claim(ticketId: a.id, repoId: nil, paths: ["x/File.swift"])
        try store.claim(ticketId: b.id, repoId: nil, paths: ["x/File.swift"])
        try store.stack(ticketId: b.id, onto: a.id)
        XCTAssertEqual(try store.ticket(id: b.id)?.status, .building)
        XCTAssertEqual(try store.claims(ticketId: b.id).first?.state, "stacked")
    }

    func testAgentQueueRespectsSlotsAndTakesMoveTheTicket() throws {
        try store.setSetting("max_agents", "1")
        let a = try walk(ticket(.tweak, "A"), to: .ready)
        let b = try walk(ticket(.tweak, "B"), to: .ready)
        XCTAssertEqual(try store.agentWork().count, 2)
        let task = try store.take(a.id, agent: "Agent on #A")
        XCTAssertEqual(task.kind, .build)
        XCTAssertEqual(task.ticket.status, .building)
        XCTAssertEqual(task.ticket.takenBy, "Agent on #A")
        XCTAssertThrowsError(try store.take(b.id, agent: "Agent on #B"), "only one slot")
        XCTAssertThrowsError(try store.take(a.id, agent: "someone else"), "already taken")
    }

    func testVettingDoesNotUseABuildSlot() throws {
        try store.setSetting("max_agents", "0")
        let t = try ticket(.bug, "x")
        _ = try store.move(t.id, to: .checking, actor: .owner)
        XCTAssertEqual(try store.take(t.id, agent: "Iris").kind, .vet)
    }

    func testDeskGroupsWhatWaitsForTheOwner() throws {
        let a = try walk(ticket(.proposal, "A"), to: .yourCall)
        let b = try walk(ticket(.tweak, "B"), to: .toVerify)
        let c = try walk(ticket(.tweak, "C"), to: .building)
        let groups = try store.deskQueue()
        XCTAssertEqual(groups.map(\.status), [.yourCall, .toVerify])
        XCTAssertEqual(groups[0].tickets.map(\.id), [a.id])
        XCTAssertFalse(groups.flatMap(\.tickets).contains { $0.id == c.id })
        _ = b
    }

    func testSyncBackoffAndRetry() throws {
        let t = try ticket()
        _ = try store.move(t.id, to: .checking, actor: .owner)
        let op = try store.pendingSync()[0]
        try store.markSyncFailed(op.id, error: "offline")
        XCTAssertTrue(try store.pendingSync().isEmpty, "waits for its backoff")
        let log = try store.syncLog()
        XCTAssertEqual(log[0].attempt, 1)
        XCTAssertEqual(log[0].error, "offline")
        for _ in 0..<8 { try store.markSyncFailed(op.id, error: "offline") }
        XCTAssertEqual(try store.syncCounts().failed, 1)
        try store.retryFailed()
        XCTAssertEqual(try store.pendingSync().count, 1)
    }

    func testProposalStateRoundTrip() throws {
        let t = try walk(ticket(), to: .yourCall)
        try store.saveProposal(ticketId: t.id, manifestJSON: "{\"options\":[]}")
        XCTAssertEqual(try store.proposalManifest(ticketId: t.id), "{\"options\":[]}")
        try store.setPick(ticketId: t.id, topic: "spacing", choice: "B")
        try store.setPick(ticketId: t.id, topic: "spacing", choice: "A", note: "changed my mind")
        XCTAssertEqual(try store.picks(ticketId: t.id).map(\.choice), ["A"])
        try store.setVerdict(ticketId: t.id, topic: "which", option: "B", verdict: "maybe")
        XCTAssertThrowsError(try store.setVerdict(ticketId: t.id, topic: "which", option: "B", verdict: "love"))
        let n = try store.recordRevision(ticketId: t.id, summary: "Added option C", added: ["C"])
        XCTAssertEqual(n, 2)
        XCTAssertEqual(try store.revisions(ticketId: t.id).first?.added, ["C"])
    }

    func testMigrationIsIdempotent() throws {
        let path = NSTemporaryDirectory() + "hatch-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        do { let s = try HatchStore(path: path); _ = try s.upsertProject(key: "p", name: "P") }
        let again = try HatchStore(path: path)
        XCTAssertEqual(try again.projects().map(\.key), ["p"])
        XCTAssertEqual(again.db.userVersion, Schema.migrations.count)
    }

    func testResolveTicketReferences() throws {
        let t = try ticket()
        _ = try store.move(t.id, to: .checking, actor: .owner)
        try store.applyIssueCreated(ticketId: t.id, ghNumber: 151)
        XCTAssertEqual(try store.resolve("#151").id, t.id)
        XCTAssertEqual(try store.resolve("151").id, t.id)
        XCTAssertEqual(try store.resolve("new-\(t.id)").id, t.id)
        XCTAssertThrowsError(try store.resolve("#999"))
    }

    // Walks a ticket along its normal path using the actors the design assigns.
    @discardableResult
    func walk(_ t: Ticket, to target: Status) throws -> Ticket {
        var current = t
        let path = Workflow.path(for: t.type)
        guard let targetIndex = path.firstIndex(of: target) else { return current }
        for status in path.dropFirst() {
            if path.firstIndex(of: status)! > targetIndex { break }
            if status == .needsAnswers || status == .revising || status == .fixing { continue }
            let actor = [Actor.agent, .hatch, .owner].first { Workflow.isAllowed(type: t.type, from: current.status, to: status, actor: $0) }
            guard let actor else { XCTFail("no actor can move \(t.type) \(current.status) to \(status)"); return current }
            current = try store.move(t.id, to: status, actor: actor)
        }
        return current
    }
}
