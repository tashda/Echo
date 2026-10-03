import XCTest
@testable import HatchAgent
@testable import HatchCore

final class BriefTests: XCTestCase {
    var store: HatchStore!
    var project: Project!

    override func setUpWithError() throws {
        (store, project) = try Fixture.store()
        try store.upsertSpecItems(projectId: project.id, items: [
            (code: "NOTIF-1.2", area: "Notifications", text: "A toast has 12pt padding and a 10pt corner radius.", source: nil),
            (code: "NOTIF-1.3", area: "Notifications", text: "A toast stays on screen for four seconds.", source: nil),
        ])
    }

    func brief(_ t: Ticket, kind: AgentTaskKind? = nil) throws -> String {
        try BriefBuilder.brief(store: store, ticketId: t.id, agent: "Agent on \(t.displayNumber)", kind: kind)
    }

    func testPrepareProposalSnapshot() throws {
        var t = try Fixture.ticket(store, project, status: .checking)
        let q = try store.ask(t.id, text: "Which toast kind?", suggestions: ["Success", "Error"], by: "Iris")
        try store.answer(questionId: q.id, text: "Both")
        try store.take(t.id, agent: "Agent on #151")
        t = try store.ticket(id: t.id)!
        let expected = """
        # #151 Proposal · Preparing · Toast spacing in dark mode
        You are Agent on #151. Task: prepare what the owner will judge.
        Project: Echo

        ## Ticket
        Toasts feel cramped in dark mode.

        ## Owner's answers
        - Which toast kind? -> Both

        ## Spec items (search)
        - NOTIF-1.3: A toast stays on screen for four seconds.
        - NOTIF-1.2: A toast has 12pt padding and a 10pt corner radius.

        ## Area
        Notifications (Spec NOTIF-*)
        Files: Echo/Notifications/**, Echo/Toast/*.swift
        Tests: NotificationTests

        ## Repos
        - app: tashda/echo (base dev) · build: swift build · tests: UnitTests
        - specimens: tashda/echo-specimens (base main)

        ## Docs to read
        - docs/agents.md

        ## Rules for this task
        1. Look up the area in the Spec and note the Spec IDs you change; put them in the manifest `specs` and in the summary.
        2. The first specimen is Echo today (`isEchoToday: true`), drawn from what Echo really does (read the real view, not memory).
        3. Then 2 to 4 proposals as Swift specimens in the specimens repo, same sample data in all, each with `designWidth` and `designHeight` (340 to 700 wide, up to about 620 tall). No title inside a specimen.
        4. Cover the standard scenarios (Rest, Hover, Pressed, Focus, Disabled, Empty, Error, Long text, Many items, Loading), or mark one `applicable: false` with a `notApplicableReason`.
        5. Every control with a `question`, every question and the specimen topic carries ONE recommendation and its reason: the option you would ship, not a safe middle. The reason says what the others cost.
        6. Write a question as what to do, then what to decide. Choice names are short and stable.
        7. Mark exactly one preset `isRecommended: true` so the owner can try your whole recommendation in one click.
        8. Hatch changes the status, never you. Do not edit labels, state or the database; use the commands under Next.
        9. If something blocks you and only the owner can answer, run `hatch ask` with your recommendation. Do not guess.
        10. Hand it in with `hatch offer`. Hatch runs the quality gate and builds the Stage; errors come back to you. Never move the status yourself.

        ## Next
        hatch offer #151 manifest.json     # when ready; Hatch checks it and moves the ticket
        hatch ask #151 "..."     # only if you are blocked
        hatch note #151 "..."    # context for the owner

        """
        XCTAssertEqual(try brief(t), expected)
    }

    func testBuildTweakSnapshot() throws {
        let t = try Fixture.ticket(store, project, type: .tweak, title: "Round the toast corners", body: "Corners are sharp.", status: .ready)
        try store.take(t.id, agent: "a")
        let b = try brief(try store.ticket(id: t.id)!)
        XCTAssertTrue(b.hasPrefix("# #151 Tweak · Building · Round the toast corners\nYou are Agent on #151. Task: build the change."), b)
        XCTAssertTrue(b.contains("1. Work only in your own worktree on branch `ticket/151-round-the-toast-corners`."))
        XCTAssertTrue(b.contains("hatch plan #151 --files <paths>"))
        XCTAssertTrue(b.contains("hatch ready #151"))
        XCTAssertTrue(b.contains("Make the smallest change that fixes it"))
        XCTAssertTrue(b.contains("Do not run the full suite or a full build; CI does that."))
        XCTAssertFalse(b.contains("hatch offer"))
    }

    func testBriefIsDeterministic() throws {
        let t = try Fixture.preparing(store, project)
        XCTAssertEqual(try brief(t), try brief(t))
    }

    func testEachKindHasItsOwnRules() throws {
        let t = try Fixture.preparing(store, project)
        let prepare = try brief(t, kind: .prepare), build = try brief(t, kind: .build), revise = try brief(t, kind: .revise)
        let fix = try brief(t, kind: .fix), vet = try brief(t, kind: .vet)
        XCTAssertTrue(prepare.contains("Echo today"))
        XCTAssertTrue(prepare.contains("hatch offer"))
        XCTAssertTrue(prepare.contains("Never move the status yourself"))
        XCTAssertTrue(revise.contains("Keep every earlier option"))
        XCTAssertTrue(revise.contains("addedIn: 2"))
        XCTAssertTrue(build.contains("worktree"))
        XCTAssertTrue(build.contains("Build the owner's accepted choices exactly"))
        XCTAssertTrue(fix.contains("same branch"))
        XCTAssertTrue(vet.contains("The owner decides every suggestion"))
        XCTAssertEqual(Set([prepare, build, revise, fix, vet]).count, 5)
    }

    func testSketchAndQuestionHaveTheirOwnPrepareRules() throws {
        let s = try Fixture.preparing(store, project, type: .sketch)
        let sb = try brief(s)
        XCTAssertTrue(sb.contains("2 to 4 HTML variants"))
        XCTAssertTrue(sb.contains("do not write Swift"))
        XCTAssertTrue(sb.contains("hatch offer #\(s.ghNumber!) sketch.json"))
        let q = try Fixture.preparing(store, project, type: .question)
        XCTAssertTrue(try brief(q).contains("Answer in words"))
    }

    func testLongBodyIsCutWithANote() throws {
        let t = try Fixture.ticket(store, project, body: String(repeating: "long ", count: 800), status: .ready)
        let b = try brief(t)
        XCTAssertTrue(b.contains("characters cut]"))
        XCTAssertLessThan(b.count, 9000)
    }

    func testOriginalTextShownOnlyWhenRewritten() throws {
        let t = try Fixture.ticket(store, project, status: .ready)
        XCTAssertFalse(try brief(t).contains("Original text"))
        try store.update(t.id, title: "Toast padding", body: "Padding is 8pt, should be 12pt.", actor: .agent)
        let b = try brief(try store.ticket(id: t.id)!)
        XCTAssertTrue(b.contains("Original text (the owner's own words, before the rewrite):\n  Toast spacing in dark mode\n  Toasts feel cramped in dark mode."))
    }

    func testRelatedTicketsAndSpecAreCapped() throws {
        for i in 1...10 { try Fixture.ticket(store, project, type: .bug, title: "Toast spacing problem \(i)", body: "toast spacing") }
        try store.upsertSpecItems(projectId: project.id, items: (1...12).map { (code: "TOAST-\($0)", area: nil, text: "toast spacing rule \($0)", source: nil) })
        let t = try Fixture.ticket(store, project, title: "Toast spacing", body: "toast spacing", status: .ready)
        let b = try brief(t)
        let related = b.components(separatedBy: "## Related tickets (search)\n")[1].components(separatedBy: "\n\n")[0].split(separator: "\n")
        XCTAssertEqual(related.count, BriefBuilder.relatedCap)
        let spec = b.components(separatedBy: "## Spec items (search)\n")[1].components(separatedBy: "\n\n")[0].split(separator: "\n")
        XCTAssertEqual(spec.count, BriefBuilder.specCap)
    }

    func testLinkedTicketsAreListedAndNotRepeatedAsRelated() throws {
        let other = try Fixture.ticket(store, project, type: .bug, title: "Toast spacing bug", body: "toast spacing")
        let t = try Fixture.ticket(store, project, title: "Toast spacing", body: "toast spacing", status: .ready)
        try store.link(from: t.id, to: other.id, kind: .related)
        let b = try brief(t)
        XCTAssertTrue(b.contains("## Links\n- related \(other.displayNumber) [bug, draft] Toast spacing bug"))
        XCTAssertFalse(b.contains("## Related tickets"))
    }

    func testNotesSinceTheLastAgentTurnOnly() throws {
        let t = try Fixture.preparing(store, project)
        try store.addNote(t.id, kind: .note, author: "owner", body: "Old context before the offer.")
        _ = try OfferService(store: store, agent: "A").offer(ticketId: t.id, manifest: Fixture.manifest())
        try store.addNote(t.id, kind: .note, author: "owner", body: "Remember dark mode.")
        try store.sendBackProposal(ticketId: t.id, reason: .needsMoreOptions, note: "Add a loud option.")
        try store.take(t.id, agent: "A")
        try store.setPick(ticketId: t.id, topic: "style", choice: "quiet")
        try store.setVerdict(ticketId: t.id, topic: "exhibit", option: "b", verdict: "maybe", note: "close")
        try store.addPin(ticketId: t.id, option: "a", x: 1, y: 2, scenario: "rest", appearance: "dark", corners: 10, zoom: 1, text: "too tight here")
        let b = try brief(try store.ticket(id: t.id)!)
        XCTAssertTrue(b.contains("## Since your last turn\n- [note] owner: Remember dark mode.\n- [instruction] owner: Add a loud option."), b)
        XCTAssertFalse(b.contains("Old context"))
        XCTAssertTrue(b.contains("- style = quiet"))
        XCTAssertTrue(b.contains("- exhibit/b: maybe (close)"))
        XCTAssertTrue(b.contains("[a, rest, dark, corners 10] too tight here"))
        XCTAssertTrue(b.contains("Send-back reason: needs-more-options"))
    }

    func testWorkspaceBranchAppearsInRepos() throws {
        let t = try Fixture.ticket(store, project, type: .tweak, status: .ready)
        try store.take(t.id, agent: "a")
        let app = try store.repo(projectId: project.id, role: .app)!
        try store.saveWorkspace(ticketId: t.id, repoId: app.id, path: "/work/echo-151", branch: "ticket/151-x", baseSha: nil)
        XCTAssertTrue(try brief(try store.ticket(id: t.id)!).contains("workspace: /work/echo-151 on branch ticket/151-x"))
    }

    func testUnrelatedStatusSaysNothingToDo() throws {
        let t = try Fixture.ticket(store, project, status: .draft)
        let b = try brief(t)
        XCTAssertTrue(b.contains("Task: none; this ticket is Draft"))
        XCTAssertTrue(b.contains("Nothing to do on this ticket right now."))
    }

    func testMissingTicketThrows() {
        XCTAssertThrowsError(try BriefBuilder.brief(store: store, ticketId: 9999, agent: "a"))
    }
}
