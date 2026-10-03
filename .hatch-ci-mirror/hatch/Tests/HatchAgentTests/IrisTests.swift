import XCTest
@testable import HatchAgent
@testable import HatchCore

final class IrisParseTests: XCTestCase {
    let json = ##"{"questions":[{"text":"Which toast?","suggestions":["Success","Error"]}],"rewrite":{"title":"Toast spacing","body":"Steps: ...","changes":["Added steps"]},"typeSuggestion":{"type":"Question","reason":"No steps."},"related":["#12",13],"specTouches":["NOTIF-1.2"],"duplicateOf":"#9"}"##

    func check(_ r: VettingResult, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(r.questions, [.init(text: "Which toast?", suggestions: ["Success", "Error"])], file: file, line: line)
        XCTAssertEqual(r.rewrite?.title, "Toast spacing", file: file, line: line)
        XCTAssertEqual(r.rewrite?.changes, ["Added steps"], file: file, line: line)
        XCTAssertEqual(r.typeSuggestion?.type, .question, file: file, line: line)
        XCTAssertEqual(r.related, ["#12", "#13"], file: file, line: line)
        XCTAssertEqual(r.specTouches, ["NOTIF-1.2"], file: file, line: line)
        XCTAssertEqual(r.duplicateOf, "#9", file: file, line: line)
    }

    func testPlainJSON() throws { check(try IrisResult.parse(json)) }
    func testCodeFence() throws { check(try IrisResult.parse("```json\n\(json)\n```")) }
    func testLeadingAndTrailingProse() throws { check(try IrisResult.parse("Sure! Here is my check:\n\n\(json)\n\nLet me know if you need more.")) }
    func testBracesInProseBeforeTheObject() throws { check(try IrisResult.parse("I looked at {the toast} and {} found this: \(json)")) }
    func testBracesInsideStrings() throws {
        let r = try IrisResult.parse(#"{"rewrite":{"title":"T","body":"Use {x} and \"} quotes\"","changes":[]}}"#)
        XCTAssertEqual(r.rewrite?.body, #"Use {x} and "} quotes""#)
    }
    func testSnakeCaseKeys() throws {
        let r = try IrisResult.parse(#"{"type_suggestion":{"type":"sketch","reason":"layout"},"spec_touches":["A-1"],"duplicate_of":7}"#)
        XCTAssertEqual(r.typeSuggestion?.type, .sketch)
        XCTAssertEqual(r.specTouches, ["A-1"])
        XCTAssertEqual(r.duplicateOf, "#7")
    }
    func testEmptyObjectIsAValidCleanResult() throws {
        let r = try IrisResult.parse("{}")
        XCTAssertEqual(r, VettingResult())
    }
    func testNullsAreLeftOut() throws {
        let r = try IrisResult.parse(#"{"rewrite":null,"typeSuggestion":null,"duplicateOf":null,"questions":[]}"#)
        XCTAssertEqual(r, VettingResult())
    }
    func testQuestionsAsPlainStringsAndBlanksDropped() throws {
        let r = try IrisResult.parse(#"{"questions":["What size?",{"text":"  "},{"text":"Which?","suggestions":["a","","b"]}]}"#)
        XCTAssertEqual(r.questions, [.init(text: "What size?"), .init(text: "Which?", suggestions: ["a", "b"])])
    }
    func testQuestionsAreCapped() throws {
        let qs = (1...9).map { #"{"text":"Q\#($0)"}"# }.joined(separator: ",")
        XCTAssertEqual(try IrisResult.parse("{\"questions\":[\(qs)]}").questions.count, IrisPrompt.maxQuestions)
    }
    func testNoJSONIsAnError() {
        XCTAssertThrowsError(try IrisResult.parse("I could not find anything wrong.")) { XCTAssertEqual($0 as? IrisError, .noJSON) }
        XCTAssertThrowsError(try IrisResult.parse("{ broken"))
    }
    func testUnknownTypeIsAnError() {
        XCTAssertThrowsError(try IrisResult.parse(#"{"typeSuggestion":{"type":"epic","reason":"x"}}"#)) { XCTAssertTrue("\($0)".contains("epic")) }
    }
    func testRewriteWithoutTextIsAnError() {
        XCTAssertThrowsError(try IrisResult.parse(#"{"rewrite":{"changes":["x"]}}"#))
        XCTAssertThrowsError(try IrisResult.parse(#"{"rewrite":"just text"}"#))
    }
    func testObjectWithKnownKeysBeatsAnEarlierObject() throws {
        let r = try IrisResult.parse(#"Example: {"foo": 1} Real: {"specTouches":["X-1"]}"#)
        XCTAssertEqual(r.specTouches, ["X-1"])
    }
}

final class IrisPromptTests: XCTestCase {
    func testPromptDemandsJSONAndIncludesTheCandidates() throws {
        let (store, p) = try Fixture.store()
        let other = try Fixture.ticket(store, p, title: "Toast padding too small", body: "Padding on toasts.")
        try store.upsertSpecItems(projectId: p.id, items: [(code: "NOTIF-1.2", area: "Notifications", text: "A toast has 12pt padding.", source: nil)])
        let t = try Fixture.ticket(store, p, title: "Toast spacing in dark mode", body: "Toasts feel cramped.")
        let prompt = IrisPrompt.make(try VettingRequest.build(store: store, ticketId: t.id))
        XCTAssertTrue(prompt.contains("ONE JSON object"))
        XCTAssertTrue(prompt.contains(other.displayNumber + " [proposal"))
        XCTAssertTrue(prompt.contains("NOTIF-1.2: A toast has 12pt padding."))
        XCTAssertTrue(prompt.contains("Notifications (NOTIF)"))
        XCTAssertFalse(prompt.contains("\(t.displayNumber) [proposal"), "the ticket is not its own candidate")
    }
    func testLongBodiesAreCut() throws {
        let (store, p) = try Fixture.store()
        let t = try Fixture.ticket(store, p, body: String(repeating: "word ", count: 1000))
        let prompt = IrisPrompt.make(try VettingRequest.build(store: store, ticketId: t.id))
        XCTAssertTrue(prompt.contains("characters cut"))
        XCTAssertLessThan(prompt.count, 5000)
    }
}

final class IrisApplierTests: XCTestCase {
    var store: HatchStore!
    var project: Project!
    var t: Ticket!

    override func setUpWithError() throws {
        (store, project) = try Fixture.store()
        t = try Fixture.ticket(store, project, type: .bug, title: "Toast broken", body: "It looks wrong.", status: .draft)
        try store.move(t.id, to: .checking, actor: .owner)
    }

    func status() throws -> Status { try store.ticket(id: t.id)!.status }

    func testQuestionsGoToTheOwner() throws {
        let out = try IrisApplier.apply(VettingResult(questions: [.init(text: "Which toast?", suggestions: ["A", "B"]), .init(text: "Which OS?")]), to: t.id, store: store)
        XCTAssertEqual(out.questionsAsked, 2)
        XCTAssertEqual(try status(), .needsAnswers)
        let qs = try store.questions(ticketId: t.id)
        XCTAssertEqual(qs.map(\.askedBy), ["Iris", "Iris"])
        XCTAssertEqual(qs[0].suggestions, ["A", "B"])
    }

    func testNothingToSayMovesToReadyByHatch() throws {
        let out = try IrisApplier.apply(VettingResult(), to: t.id, store: store)
        XCTAssertEqual(out.status, .ready)
        let move = try store.events(ticketId: t.id, kinds: ["status"]).last!
        XCTAssertEqual(move.actor, "hatch")
    }

    func testRewriteAndTypeAreOnlySuggestedNotApplied() throws {
        let r = VettingResult(rewrite: .init(title: "Toast clipped", body: "Steps...", changes: ["structure"]), typeSuggestion: .init(type: .question, reason: "no steps"))
        let out = try IrisApplier.apply(r, to: t.id, store: store)
        XCTAssertTrue(out.suggestionStored)
        let after = try store.ticket(id: t.id)!
        XCTAssertEqual(after.title, "Toast broken")
        XCTAssertEqual(after.body, "It looks wrong.")
        XCTAssertEqual(after.type, .bug)
        XCTAssertEqual(after.status, .needsAnswers, "a suggestion without questions still waits for the owner")
        let s = try store.pendingSuggestion(ticketId: t.id)
        XCTAssertEqual(s?.rewrite?.title, "Toast clipped")
        XCTAssertEqual(s?.typeSuggestion?.type, .question)
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["vetting"]).count, 1)
    }

    func testSuggestionThatChangesNothingIsDropped() throws {
        let r = VettingResult(rewrite: .init(title: "Toast broken", body: "It looks wrong."), typeSuggestion: .init(type: .bug, reason: "same"))
        let out = try IrisApplier.apply(r, to: t.id, store: store)
        XCTAssertFalse(out.suggestionStored)
        XCTAssertEqual(out.status, .ready)
    }

    func testAcceptAppliesRewriteAndKeepsTheOriginal() throws {
        try IrisApplier.apply(VettingResult(rewrite: .init(title: "Toast clipped", body: "Steps..."), typeSuggestion: .init(type: .question, reason: "r")), to: t.id, store: store)
        let after = try IrisApplier.accept(ticketId: t.id, store: store)
        XCTAssertEqual(after.title, "Toast clipped")
        XCTAssertEqual(after.body, "Steps...")
        XCTAssertEqual(after.originalTitle, "Toast broken")
        XCTAssertEqual(after.originalBody, "It looks wrong.")
        XCTAssertEqual(after.type, .bug, "the type changes only when the owner accepts it")
        XCTAssertEqual(after.status, .ready)
        XCTAssertNil(try store.pendingSuggestion(ticketId: t.id))
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["edit"]).last?.actor, "agent")
    }

    func testAcceptWithTypeChangesTheType() throws {
        try IrisApplier.apply(VettingResult(typeSuggestion: .init(type: .question, reason: "no steps")), to: t.id, store: store)
        let after = try IrisApplier.accept(ticketId: t.id, store: store, applyType: true)
        XCTAssertEqual(after.type, .question)
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["type"]).last?.payload["reason"]?.stringValue, "no steps")
    }

    func testKeepMineChangesNothing() throws {
        try IrisApplier.apply(VettingResult(rewrite: .init(title: "Other", body: "Other body"), typeSuggestion: .init(type: .tweak, reason: "r")), to: t.id, store: store)
        let after = try IrisApplier.keepMine(ticketId: t.id, store: store)
        XCTAssertEqual(after.title, "Toast broken")
        XCTAssertEqual(after.type, .bug)
        XCTAssertEqual(after.status, .ready)
        XCTAssertNil(try store.pendingSuggestion(ticketId: t.id))
    }

    func testEditAppliesTheOwnersText() throws {
        try IrisApplier.apply(VettingResult(rewrite: .init(title: "Other", body: "Other body")), to: t.id, store: store)
        let after = try IrisApplier.edit(ticketId: t.id, title: "My title", body: "My body", store: store)
        XCTAssertEqual(after.title, "My title")
        XCTAssertEqual(after.originalBody, "It looks wrong.")
    }

    func testOpenQuestionsKeepTheTicketWaitingAfterTheDecision() throws {
        try IrisApplier.apply(VettingResult(questions: [.init(text: "Q?")], rewrite: .init(title: "N", body: "B")), to: t.id, store: store)
        let after = try IrisApplier.accept(ticketId: t.id, store: store)
        XCTAssertEqual(after.status, .needsAnswers)
        try store.answer(questionId: try store.questions(ticketId: t.id)[0].id, text: "yes")
        XCTAssertEqual(try status(), .ready)
    }

    func testDuplicateLinkOnlyWhenTheOwnerConfirms() throws {
        let other = try Fixture.ticket(store, project, type: .bug, title: "Toast clipped", body: "x", status: .draft)
        let result = VettingResult(duplicateOf: "new-\(other.id)")
        try IrisApplier.apply(result, to: t.id, store: store)
        XCTAssertEqual(try store.pendingSuggestion(ticketId: t.id)?.duplicateOf, other.id)
        XCTAssertTrue(try store.links(ticketId: t.id).isEmpty, "nothing is linked yet")
        try IrisApplier.keepMine(ticketId: t.id, store: store)
        XCTAssertTrue(try store.links(ticketId: t.id).isEmpty, "Keep separate does not link")

        // A second ticket where the owner confirms.
        let t2 = try Fixture.ticket(store, project, type: .bug, title: "Toast clipped again", body: "y", status: .draft)
        try store.move(t2.id, to: .checking, actor: .owner)
        try IrisApplier.apply(VettingResult(duplicateOf: "new-\(other.id)"), to: t2.id, store: store)
        try IrisApplier.keepMine(ticketId: t2.id, store: store, linkDuplicate: true)
        XCTAssertEqual(try store.links(ticketId: t2.id).map { $0.link.kind }, [.duplicates])
    }

    func testUnknownDuplicateIsIgnored() throws {
        let out = try IrisApplier.apply(VettingResult(duplicateOf: "#99999"), to: t.id, store: store)
        XCTAssertFalse(out.suggestionStored)
    }

    func testApplyingToATicketNotInCheckingFails() throws {
        try store.move(t.id, to: .ready, actor: .hatch)
        XCTAssertThrowsError(try IrisApplier.apply(VettingResult(), to: t.id, store: store))
    }

    func testDecisionWithoutSuggestionFails() {
        XCTAssertThrowsError(try IrisApplier.accept(ticketId: t.id, store: store))
    }
}
