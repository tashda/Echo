import XCTest
@testable import StageCore

final class RevisionAndMergeTests: XCTestCase {
    /// Revision 2 of a Proposal: option C, a choice "20" of Padding and the scenario "Loading" were added in revision 2.
    private func rev2() -> StageManifest {
        var m = StageManifest(revision: 2)
        m.specimens = [
            StageSpecimen(id: "t", title: "Echo today", isEchoToday: true),
            StageSpecimen(id: "a", title: "A"),
            StageSpecimen(id: "b", title: "B"),
            StageSpecimen(id: "c", title: "C", addedIn: 2),
        ]
        m.controls = [StageControl(id: "pad", title: "Padding",
                                   choices: [StageChoice(id: "12", name: "12"), StageChoice(id: "16", name: "16"), StageChoice(id: "20", name: "20", addedIn: 2)],
                                   defaultChoice: "12", question: "Which?", recommend: "20", why: "Roomy.")]
        m.exhibitTopic = StageTopic(id: "which", title: "Which?", question: "Pick.", recommended: "c", why: "Best.")
        m.scenarios = [StageScenario(id: "rest", title: "Rest"), StageScenario(id: "loading", title: "Loading", addedIn: 2)]
        m.presets = [StagePreset(id: "p2", name: "Roomy", values: ["pad": "20"], isRecommended: true, addedIn: 2)]
        return m
    }

    func testAtRevisionDropsWhatCameLater() {
        let old = rev2().atRevision(1)
        XCTAssertEqual(old.revision, 1)
        XCTAssertEqual(old.specimens.map { $0.id }, ["t", "a", "b"])
        XCTAssertEqual(old.controls[0].choices.map { $0.id }, ["12", "16"])
        XCTAssertNil(old.controls[0].recommend)
        XCTAssertNil(old.exhibitTopic?.recommended)
        XCTAssertEqual(old.scenarios.map { $0.id }, ["rest"])
        XCTAssertTrue(old.presets.isEmpty)
        XCTAssertTrue(old.newItems.isEmpty)
        XCTAssertEqual(rev2().atRevision(2), rev2())
        XCTAssertEqual(rev2().atRevision(9), rev2())
    }

    func testAdditionsAfterListsLaterChanges() {
        let items = rev2().additions(after: 1)
        XCTAssertTrue(items.contains("New option: C"))
        XCTAssertTrue(items.contains("New choice in Padding: 20"))
        XCTAssertTrue(items.contains("New scenario: Loading"))
        XCTAssertTrue(rev2().additions(after: 2).isEmpty)
    }

    func testSwitchingRevisionKeepsStateValid() {
        let full = rev2()
        var s = StageState(manifest: full)
        s.selected = "c"
        s.scenario = "loading"
        s.controlValues["pad"] = "20"
        let r = StageReducer.apply(&s, .setViewRevision(1), full: full)
        XCTAssertEqual(s.viewRevision, 1)
        XCTAssertEqual(r.viewed.revision, 1)
        XCTAssertEqual(s.selected, "a")
        XCTAssertEqual(s.scenario, "rest")
        XCTAssertEqual(s.controlValues["pad"], "12")
        // Back to the latest, either as nil or as the latest number: stored as nil.
        _ = StageReducer.apply(&s, .setViewRevision(2), full: full)
        XCTAssertNil(s.viewRevision)
    }

    func testEarlierPicksSurviveTheRevisionSwitch() {
        let full = rev2()
        var s = StageState(manifest: full)
        _ = StageReducer.apply(&s, .answer(topic: "which", choice: "a"), full: full)
        _ = StageReducer.apply(&s, .setViewRevision(1), full: full)
        XCTAssertEqual(s.answers["which"], "a")
        XCTAssertEqual(s.verdicts["a"], .pick)
    }

    func testMarkRevisionSeen() {
        let full = rev2()
        var s = StageState(manifest: full)
        _ = StageReducer.apply(&s, .markRevisionSeen, full: full)
        XCTAssertEqual(s.seenRevision, 2)
    }

    func testStateSavedBeforeTheNewFieldsStillLoads() throws {
        var s = StageState()
        s.generalNote = "kept"
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        for k in ["viewRevision", "seenRevision", "hiddenPinKeys"] { json[k] = nil }
        let back = try JSONDecoder().decode(StageState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.generalNote, "kept")
        XCTAssertNil(back.viewRevision)
    }

    // MARK: Merge

    func testHatchAnswersReplaceTheRememberedOnesWhenNothingIsPending() {
        let m = rev2()
        var s = StageState(manifest: m)
        s.answers = ["pad": "12", "which": "a"]
        s.verdicts = ["a": .pick, "b": .maybe]
        let snap = StageHatchSnapshot(
            picks: [.init(topic: "which", choice: "c", note: "calmest"), .init(topic: "pad", choice: "16", note: "tight")],
            verdicts: [.init(topic: "which", option: "b", verdict: "no", note: "loud")])
        StageMerge.apply(snap, to: &s, manifest: m, hasPendingWrites: false)
        XCTAssertEqual(s.answers, ["which": "c", "pad": "16"])
        XCTAssertEqual(s.verdicts, ["c": .pick, "b": .no])
        XCTAssertEqual(s.optionNotes["c"], "calmest")
        XCTAssertEqual(s.optionNotes["b"], "loud")
        XCTAssertEqual(s.topicNotes["pad"], "tight")
    }

    func testPendingWritesKeepTheLocalAnswers() {
        let m = rev2()
        var s = StageState(manifest: m)
        s.answers = ["pad": "12"]
        let snap = StageHatchSnapshot(picks: [.init(topic: "pad", choice: "16"), .init(topic: "which", choice: "b")])
        StageMerge.apply(snap, to: &s, manifest: m, hasPendingWrites: true)
        XCTAssertEqual(s.answers["pad"], "12")
        XCTAssertEqual(s.answers["which"], "b")
    }

    func testNotesTypedHereAreNotOverwritten() {
        let m = rev2()
        var s = StageState(manifest: m)
        s.topicNotes["pad"] = "mine"
        StageMerge.apply(StageHatchSnapshot(picks: [.init(topic: "pad", choice: "16", note: "theirs")]), to: &s, manifest: m, hasPendingWrites: false)
        XCTAssertEqual(s.topicNotes["pad"], "mine")
    }

    func testPinsFromHatchAreAddedOnceAndNumbered() {
        let m = rev2()
        var s = StageState(manifest: m)
        _ = StageReducer.reduce(&s, .addPin(text: "icon too close", option: "a", x: 0.1, y: 0.2), manifest: m)
        let snap = StageHatchSnapshot(pins: [
            .init(id: 1, text: "icon too close", option: "a", x: 0.1, y: 0.2, scenario: "rest", appearance: "light", corners: 10, zoom: 1),
            .init(id: 2, text: "edge too hard", option: "b", x: 0.5, y: 0.5, scenario: "loading", appearance: "dark", corners: 26, zoom: 1.5),
        ])
        StageMerge.apply(snap, to: &s, manifest: m, hasPendingWrites: false)
        StageMerge.apply(snap, to: &s, manifest: m, hasPendingWrites: false)
        XCTAssertEqual(s.pins.count, 2)
        let added = s.pins[1]
        XCTAssertEqual(added.number, 2)
        XCTAssertEqual(added.appearance, .dark)
        XCTAssertEqual(added.corners, 26)
        XCTAssertEqual(added.scenario, "loading")
    }

    func testARemovedPinIsNotBroughtBack() {
        let m = rev2()
        var s = StageState(manifest: m)
        let snap = StageHatchSnapshot(pins: [.init(id: 7, text: "wrong", option: "a")])
        StageMerge.apply(snap, to: &s, manifest: m, hasPendingWrites: false)
        let id = s.pins[0].id
        _ = StageReducer.reduce(&s, .removePin(id), manifest: m)
        StageMerge.apply(snap, to: &s, manifest: m, hasPendingWrites: false)
        XCTAssertTrue(s.pins.isEmpty)
        // Writing the same note again is allowed.
        _ = StageReducer.reduce(&s, .addPin(text: "wrong", option: "a", x: nil, y: nil), manifest: m)
        XCTAssertEqual(s.pins.count, 1)
    }

    // MARK: Data source

    func testAskCarriesTheScreenshotAndOthersDoNot() async throws {
        let m = rev2()
        let source = InMemoryStageDataSource(manifest: m)
        _ = try await source.perform(.note(kind: "ask", body: "Why 16?"), screenshot: Data([1, 2, 3]))
        _ = try await source.perform(.note(kind: "note", body: "FYI"), screenshot: Data([1, 2, 3]))
        let notes = source.events.filter { $0.kind == .note }
        XCTAssertEqual(notes[0].fields["screenshotBytes"], "3")
        XCTAssertNil(notes[1].fields["screenshotBytes"])
    }

    func testHeartbeatAndSnapshotAreAnsweredByTheDemoSource() async {
        let source = InMemoryStageDataSource(manifest: rev2())
        let none = await source.heartbeat(revision: 2, state: "running")
        XCTAssertNil(none)
        source.heartbeatReply = StageHeartbeatReply(latestRevision: 3, reload: true)
        let reply = await source.heartbeat(revision: 2, state: "running")
        XCTAssertEqual(reply?.reload, true)
        XCTAssertEqual(source.heartbeats, ["running", "running"])
        source.hatchSnapshot = StageHatchSnapshot(pins: [.init(id: 1, text: "x")])
        let snap = await source.loadSnapshot()
        XCTAssertEqual(snap?.pins.count, 1)
        source.hatchAway = true
        let away = await source.loadSnapshot()
        XCTAssertNil(away)
    }
}
