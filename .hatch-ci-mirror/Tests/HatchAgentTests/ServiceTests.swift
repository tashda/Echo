import XCTest
@testable import HatchAgent
@testable import HatchCore

final class VettingServiceTests: XCTestCase {
    var store: HatchStore!
    var project: Project!
    var t: Ticket!

    override func setUpWithError() throws {
        (store, project) = try Fixture.store()
        t = try Fixture.ticket(store, project, type: .bug, title: "Toast broken", body: "It looks wrong.")
        try store.move(t.id, to: .checking, actor: .owner)
    }

    func service(_ runner: AgentRunner) -> VettingService { VettingService(store: store, runner: runner) }

    func testHappyPathAsksAndCountsTokens() throws {
        let runner = ScriptedRunner(text: #"{"questions":[{"text":"Which toast?","suggestions":["A"]}]}"#, tokensIn: 1200, tokensOut: 80)
        let outcome = try service(runner).vet(ticketId: t.id)
        guard case .vetted(let o) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(o.status, .needsAnswers)
        let totals = try store.tokenTotals(ticketId: t.id)
        XCTAssertEqual(totals.input, 1200)
        XCTAssertEqual(totals.output, 80)
        let run = try store.db.query("SELECT agent, step, outcome FROM agent_run") { ($0.string("agent")!, $0.string("step")!, $0.string("outcome")!) }
        XCTAssertEqual(run.count, 1)
        XCTAssertEqual(run[0].0, "Iris"); XCTAssertEqual(run[0].1, "vet"); XCTAssertEqual(run[0].2, "ok")
    }

    func testCleanTicketGoesStraightToReady() throws {
        let outcome = try service(ScriptedRunner(text: "Looks fine.\n```json\n{}\n```", tokensIn: 500, tokensOut: 10)).vet(ticketId: t.id)
        XCTAssertEqual(outcome, .vetted(IrisOutcome(questionsAsked: 0, suggestionStored: false, status: .ready)))
    }

    func testPromptReachesTheRunnerWithCandidates() throws {
        try Fixture.ticket(store, project, type: .bug, title: "Toast broken on dark", body: "same")
        let runner = ScriptedRunner(text: "{}")
        try service(runner).vet(ticketId: t.id)
        XCTAssertEqual(runner.prompts.count, 1)
        XCTAssertTrue(runner.prompts[0].contains("Toast broken on dark"))
    }

    func testRunnerFailureLeavesTheTicketInCheckingWithAnEvent() throws {
        let runner = ScriptedRunner(replies: [.failure(AgentRunnerError.timedOut(seconds: 30))])
        let outcome = try service(runner).vet(ticketId: t.id)
        guard case .failed(let why) = outcome else { return XCTFail() }
        XCTAssertTrue(why.contains("30 seconds"))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .checking)
        let ev = try store.events(ticketId: t.id, kinds: ["vetting-failed"])
        XCTAssertEqual(ev.count, 1)
        XCTAssertEqual(try store.tokenTotals(ticketId: t.id).input, 0)
        XCTAssertEqual(try store.db.query("SELECT outcome FROM agent_run") { $0.string("outcome")! }, ["failed"])
    }

    func testUnusableAnswerStillCountsTheTokensSpent() throws {
        let outcome = try service(ScriptedRunner(text: "I am not sure what you mean.", tokensIn: 900, tokensOut: 40)).vet(ticketId: t.id)
        guard case .failed(let why) = outcome else { return XCTFail() }
        XCTAssertTrue(why.contains("JSON"))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .checking)
        XCTAssertEqual(try store.tokenTotals(ticketId: t.id).input, 900)
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["vetting-failed"]).count, 1)
    }

    func testTokensAddUpAcrossTickets() throws {
        let t2 = try Fixture.ticket(store, project, type: .bug, title: "Other", body: "x")
        try store.move(t2.id, to: .checking, actor: .owner)
        try service(ScriptedRunner(text: "{}", tokensIn: 100, tokensOut: 10)).vet(ticketId: t.id)
        try service(ScriptedRunner(text: "{}", tokensIn: 200, tokensOut: 20)).vet(ticketId: t2.id)
        let all = try store.tokenTotals()
        XCTAssertEqual(all.input, 300); XCTAssertEqual(all.output, 30)
        XCTAssertEqual(try store.tokenTotals(ticketId: t2.id).input, 200)
    }

    func testOnlyCheckingTicketsAreVetted() throws {
        try store.move(t.id, to: .ready, actor: .hatch)
        XCTAssertThrowsError(try service(ScriptedRunner(text: "{}")).vet(ticketId: t.id))
    }

    func testOptionsReachTheRunner() throws {
        let runner = ScriptedRunner(text: "{}")
        try VettingService(store: store, runner: runner, options: AgentOptions(model: "haiku", timeout: 60)).vet(ticketId: t.id)
        XCTAssertEqual(runner.optionsSeen.first?.model, "haiku")
    }

    func testScriptedRunnerRunsOut() {
        XCTAssertThrowsError(try ScriptedRunner(replies: []).run(prompt: "x", options: AgentOptions()))
    }
}

final class OfferServiceTests: XCTestCase {
    var store: HatchStore!
    var project: Project!
    var t: Ticket!
    var offers: OfferService!

    override func setUpWithError() throws {
        (store, project) = try Fixture.store()
        t = try Fixture.preparing(store, project)
        offers = OfferService(store: store, agent: "Agent on #151")
    }

    func testHappyPathMovesToYourCallByHatchAndReleasesTheAgent() throws {
        XCTAssertEqual(t.status, .preparing)
        XCTAssertNotNil(t.takenBy)
        let result = try offers.offer(ticketId: t.id, manifest: Fixture.manifest())
        guard case .offered(let after, let rev, let warnings) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(rev, 1)
        XCTAssertEqual(warnings, [])
        XCTAssertEqual(after.status, .yourCall)
        XCTAssertNil(after.takenBy)
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["status"]).last?.actor, "hatch")
        XCTAssertEqual(try ProposalManifest.parse(json: try store.proposalManifest(ticketId: t.id)!), Fixture.manifest())
        XCTAssertEqual(try store.notes(ticketId: t.id).last?.kind, .agent)
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["offer"]).count, 1)
    }

    func testJSONEntryPoint() throws {
        let result = try offers.offer(ticketId: t.id, json: try Fixture.manifest().jsonString())
        XCTAssertTrue(result.isOffered)
    }

    func testRejectionLeavesEverythingAsItWas() throws {
        var m = Fixture.manifest(); m.specimens.removeFirst(); m.questions[0].why = nil
        let result = try offers.offer(ticketId: t.id, manifest: m)
        guard case .rejected(let issues) = result else { return XCTFail() }
        XCTAssertTrue(Set(codes(issues)).isSuperset(of: ["echo-today.missing", "question.why-missing"]))
        let after = try store.ticket(id: t.id)!
        XCTAssertEqual(after, t)
        XCTAssertNil(try store.proposalManifest(ticketId: t.id))
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["offer-rejected"]).count, 1)
        XCTAssertTrue(try store.notes(ticketId: t.id).isEmpty)
    }

    func testWarningsDoNotBlock() throws {
        var m = Fixture.manifest(); m.summary = "No ids here."
        let result = try offers.offer(ticketId: t.id, manifest: m)
        XCTAssertTrue(result.isOffered)
        XCTAssertEqual(codes(result.issues), ["summary.spec-id"])
    }

    func testBadJSONIsARejectionWithAClearMessage() throws {
        let result = try offers.offer(ticketId: t.id, json: #"{"specimens": "none"}"#)
        guard case .rejected(let issues) = result else { return XCTFail() }
        XCTAssertEqual(issues[0].code, "manifest.invalid")
        XCTAssertTrue(issues[0].message.contains("specimens"))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .preparing)
    }

    func testWrongRevisionNumberIsRejected() throws {
        var m = Fixture.manifest(); m.revision = 3
        XCTAssertTrue(codes(try offers.offer(ticketId: t.id, manifest: m).issues).contains("revision.expected"))
    }

    func testOnlyPreparingOrRevisingTicketsCanOffer() throws {
        _ = try offers.offer(ticketId: t.id, manifest: Fixture.manifest())
        XCTAssertThrowsError(try offers.offer(ticketId: t.id, manifest: Fixture.manifest())) { XCTAssertTrue("\($0)".contains("Your call")) }
    }

    func testStageCheckCanRejectAfterTheManifestPasses() throws {
        let svc = OfferService(store: store, agent: "a", stageCheck: { _, _ in [.error("stage.build", "The Stage does not compile.", "Fix the build errors in the round package.")] })
        let result = try svc.offer(ticketId: t.id, manifest: Fixture.manifest())
        XCTAssertEqual(codes(result.issues), ["stage.build"])
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .preparing)
    }

    func testRevisionKeepsOldOptionsAndRecordsTheRevision() throws {
        _ = try offers.offer(ticketId: t.id, manifest: Fixture.manifest())
        // The owner answers one topic and sends it back.
        try store.setPick(ticketId: t.id, topic: "style", choice: "quiet")
        try store.sendBackProposal(ticketId: t.id, reason: .needsMoreOptions, note: "Add a loud option.")
        try store.take(t.id, agent: "Agent on #151")

        var m2 = Fixture.manifest()
        m2.revision = 2
        m2.controls[0].choices.append(ManifestChoice(id: "loud", name: "Loud", addedIn: 2))
        let result = try offers.offer(ticketId: t.id, manifest: m2)
        guard case .offered(let after, let rev, _) = result else { return XCTFail("\(result.issues.report)") }
        XCTAssertEqual(rev, 2)
        XCTAssertEqual(after.status, .yourCall)
        XCTAssertEqual(after.revision, 2)
        let revs = try store.revisions(ticketId: t.id)
        XCTAssertEqual(revs.count, 1)
        XCTAssertEqual(revs[0].n, 2)
        XCTAssertEqual(revs[0].added, ["New option: style · Loud"])
    }

    func testRevisionThatDropsAnOptionOrRenamesAnAnsweredChoiceIsRejected() throws {
        _ = try offers.offer(ticketId: t.id, manifest: Fixture.manifest())
        try store.setPick(ticketId: t.id, topic: "style", choice: "quiet")
        try store.sendBackProposal(ticketId: t.id, reason: .changeOption, note: "Change it.")
        try store.take(t.id, agent: "a")
        var m2 = Fixture.manifest(); m2.revision = 2
        m2.specimens.removeLast()
        m2.controls[0].choices[0].name = "Calm"
        let result = try offers.offer(ticketId: t.id, manifest: m2)
        XCTAssertTrue(Set(codes(result.issues)).isSuperset(of: ["revision.removed", "revision.renamed"]))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .revising)
        XCTAssertEqual(try store.revisions(ticketId: t.id).count, 0)
    }

    func testOfferIsOnlyForProposals() throws {
        let q = try Fixture.preparing(store, project, type: .question)
        XCTAssertThrowsError(try offers.offer(ticketId: q.id, manifest: Fixture.manifest()))
    }

    // Sketch and Question

    func sketch(_ n: Int) -> SketchManifest {
        SketchManifest(summary: "Three layouts. I would pick a.", variants: (0..<n).map { .init(id: "v\($0)", title: "V\($0)", html: "v\($0).html") })
    }

    func testSketchHappyPathAndRejection() throws {
        let s = try Fixture.preparing(store, project, type: .sketch)
        let bad = try offers.offer(ticketId: s.id, sketch: sketch(1))
        XCTAssertEqual(codes(bad.issues), ["sketch.variant-count"])
        XCTAssertEqual(try store.ticket(id: s.id)?.status, .preparing)
        let ok = try offers.offer(ticketId: s.id, sketch: sketch(3))
        XCTAssertTrue(ok.isOffered)
        XCTAssertEqual(try store.ticket(id: s.id)?.status, .yourCall)
        XCTAssertNotNil(try store.proposalManifest(ticketId: s.id))
    }

    func testSketchFilesMustExistWhenAFolderIsGiven() throws {
        let s = try Fixture.preparing(store, project, type: .sketch)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sketch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "<html></html>".write(to: dir.appendingPathComponent("v0.html"), atomically: true, encoding: .utf8)
        let result = try offers.offer(ticketId: s.id, sketch: sketch(2), baseDirectory: dir)
        XCTAssertEqual(codes(result.issues), ["sketch.html-not-found"])
    }

    func testQuestionAnswerGoesToTheOwner() throws {
        let q = try Fixture.preparing(store, project, type: .question)
        XCTAssertEqual(codes(try offers.offerAnswer(ticketId: q.id, answer: "  ").issues), ["answer.empty"])
        let ok = try offers.offerAnswer(ticketId: q.id, answer: "Use 12pt. NOTIF-1.2 already says so.")
        XCTAssertTrue(ok.isOffered)
        XCTAssertEqual(try store.ticket(id: q.id)?.status, .yourCall)
        XCTAssertEqual(try store.notes(ticketId: q.id).last?.body, "Use 12pt. NOTIF-1.2 already says so.")
    }
}
