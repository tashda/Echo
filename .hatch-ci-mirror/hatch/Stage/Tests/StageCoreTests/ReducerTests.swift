import XCTest
@testable import StageCore

final class ReducerTests: XCTestCase {
    private func make() throws -> (StageManifest, StageState) {
        let m = try Fixtures.toast()
        return (m, Fixtures.state(for: m))
    }

    // MARK: Keyboard map

    func testSpaceFlipsAndSwitchesToFlipMode() throws {
        let (m, start) = try make()
        var s = start
        XCTAssertEqual(s.mode, .side)
        StageReducer.reduce(&s, .key(.space), manifest: m)
        XCTAssertEqual(s.mode, .flip)
        XCTAssertTrue(s.flipSide)
        StageReducer.reduce(&s, .key(.space), manifest: m)
        XCTAssertFalse(s.flipSide)
    }

    func testDigitsChooseCompareMode() throws {
        let (m, start) = try make()
        var s = start
        let expected: [(Int, StageMode)] = [(1, .side), (2, .overlay), (3, .flip), (4, .wipe), (5, .matrix)]
        for (d, mode) in expected {
            StageReducer.reduce(&s, .key(.digit(d)), manifest: m)
            XCTAssertEqual(s.mode, mode)
        }
        StageReducer.reduce(&s, .key(.digit(9)), manifest: m)
        XCTAssertEqual(s.mode, .matrix)
    }

    func testLettersAppearanceRedlinesScenario() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .key(.character("d")), manifest: m)
        XCTAssertEqual(s.appearance, .dark)
        StageReducer.reduce(&s, .key(.character("L")), manifest: m)
        XCTAssertEqual(s.appearance, .light)
        StageReducer.reduce(&s, .key(.character("r")), manifest: m)
        XCTAssertTrue(s.redlines)
        StageReducer.reduce(&s, .key(.character("R")), manifest: m)
        XCTAssertFalse(s.redlines)
        XCTAssertEqual(s.scenario, "rest")
        StageReducer.reduce(&s, .key(.character("s")), manifest: m)
        XCTAssertEqual(s.scenario, "hover")
    }

    func testNextScenarioSkipsNotApplicableAndWraps() throws {
        let (m, start) = try make()
        var s = start
        s.scenario = "hover"
        StageReducer.reduce(&s, .nextScenario, manifest: m)
        XCTAssertEqual(s.scenario, "error")
        s.scenario = "many-items"
        StageReducer.reduce(&s, .nextScenario, manifest: m)
        XCTAssertEqual(s.scenario, "rest")
    }

    func testSettingNotApplicableScenarioIsIgnored() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setScenario("pressed"), manifest: m)
        XCTAssertEqual(s.scenario, "rest")
        StageReducer.reduce(&s, .setScenario("error"), manifest: m)
        XCTAssertEqual(s.scenario, "error")
    }

    func testArrowsSwitchSelectedOption() throws {
        let (m, start) = try make()
        var s = start
        XCTAssertEqual(s.selected, "a")
        StageReducer.reduce(&s, .key(.right), manifest: m)
        XCTAssertEqual(s.selected, "b")
        StageReducer.reduce(&s, .key(.right), manifest: m)
        XCTAssertEqual(s.selected, "a")
        StageReducer.reduce(&s, .key(.left), manifest: m)
        XCTAssertEqual(s.selected, "b")
    }

    func testCommandReturnOpensAcceptAndShiftOpensSendBack() throws {
        let (m, start) = try make()
        var s = start
        let fx = StageReducer.reduce(&s, .key(.commandReturn), manifest: m)
        XCTAssertEqual(s.sheet, .accept)
        XCTAssertTrue(fx.isEmpty, "A key must never start a build")
        StageReducer.reduce(&s, .dismissSheet, manifest: m)
        StageReducer.reduce(&s, .key(.commandShiftReturn), manifest: m)
        XCTAssertEqual(s.sheet, .sendBack)
    }

    func testKeysAreIgnoredWhileASheetIsOpenExceptHelp() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .key(.character("?")), manifest: m)
        XCTAssertEqual(s.sheet, .help)
        StageReducer.reduce(&s, .key(.character("d")), manifest: m)
        XCTAssertEqual(s.appearance, .light)
        StageReducer.reduce(&s, .key(.character("?")), manifest: m)
        XCTAssertNil(s.sheet)
        s.sheet = .accept
        StageReducer.reduce(&s, .key(.character("?")), manifest: m)
        XCTAssertEqual(s.sheet, .accept)
    }

    // MARK: Decisions

    func testUseRecommendationAnswersWithRecommendedChoice() throws {
        let (m, start) = try make()
        var s = start
        let fx = StageReducer.reduce(&s, .useRecommendation(topic: "padding"), manifest: m)
        XCTAssertEqual(s.answers["padding"], "p16")
        XCTAssertEqual(fx, [.pick(topic: "padding", choice: "p16", note: nil)])
    }

    func testUseAllRecommendationsSkipsAlreadyRecommended() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .useRecommendation(topic: "icon"), manifest: m)
        let fx = StageReducer.reduce(&s, .useAllRecommendations, manifest: m)
        XCTAssertEqual(fx.count, 3)
        XCTAssertEqual(s.answers["option"], "b")
        XCTAssertEqual(s.answers["actions"], "hover")
    }

    func testUsePreviewTakesControlValueAndSelectedOption() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setControl(id: "padding", value: "p20"), manifest: m)
        StageReducer.reduce(&s, .usePreview(topic: "padding"), manifest: m)
        XCTAssertEqual(s.answers["padding"], "p20")
        StageReducer.reduce(&s, .selectOption("b"), manifest: m)
        StageReducer.reduce(&s, .usePreview(topic: "option"), manifest: m)
        XCTAssertEqual(s.answers["option"], "b")
        XCTAssertEqual(s.verdicts["b"], .pick)
        let none = StageReducer.reduce(&s, .usePreview(topic: "actions"), manifest: m)
        XCTAssertTrue(none.isEmpty)
    }

    func testUseAllPreviewSkipsUnchanged() throws {
        let (m, start) = try make()
        var s = start
        let fx = StageReducer.reduce(&s, .useAllPreview, manifest: m)
        // padding, icon and the option topic (selected "a") are answerable; the free question is not.
        XCTAssertEqual(fx.count, 3)
        let again = StageReducer.reduce(&s, .useAllPreview, manifest: m)
        XCTAssertTrue(again.isEmpty)
    }

    func testNeedsMoreIsClearedByAnAnswer() throws {
        let (m, start) = try make()
        var s = start
        let fx = StageReducer.reduce(&s, .setNeedsMore(topic: "icon", on: true), manifest: m)
        XCTAssertTrue(s.needsMore.contains("icon"))
        XCTAssertEqual(fx.count, 1)
        StageReducer.reduce(&s, .answer(topic: "icon", choice: "small"), manifest: m)
        XCTAssertFalse(s.needsMore.contains("icon"))
    }

    func testTopicNoteTravelsWithPickOrAsNote() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setTopicNote(topic: "icon", text: "  too big at Large  "), manifest: m)
        let asNote = StageReducer.reduce(&s, .commitTopicNote(topic: "icon"), manifest: m)
        XCTAssertEqual(asNote, [.note(kind: "note", body: "[Icon size, Option B] too big at Large")])
        StageReducer.reduce(&s, .answer(topic: "icon", choice: "small"), manifest: m)
        let withPick = StageReducer.reduce(&s, .commitTopicNote(topic: "icon"), manifest: m)
        XCTAssertEqual(withPick, [.pick(topic: "icon", choice: "small", note: "too big at Large")])
    }

    // MARK: Verdicts

    func testPickMaybeNoAndToggleOff() throws {
        let (m, start) = try make()
        var s = start
        var fx = StageReducer.reduce(&s, .setVerdict(option: "a", verdict: .maybe), manifest: m)
        XCTAssertEqual(fx, [.verdict(topic: "option", option: "a", verdict: "maybe", note: nil)])
        fx = StageReducer.reduce(&s, .setVerdict(option: "a", verdict: .maybe), manifest: m)
        XCTAssertNil(s.verdicts["a"])
        XCTAssertEqual(fx, [.verdict(topic: "option", option: "a", verdict: "none", note: nil)])
        fx = StageReducer.reduce(&s, .setVerdict(option: "b", verdict: .no), manifest: m)
        XCTAssertEqual(s.verdicts["b"], .no)
    }

    func testOnlyOnePickAndItIsTheAnswer() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setVerdict(option: "a", verdict: .pick), manifest: m)
        XCTAssertEqual(s.answers["option"], "a")
        let fx = StageReducer.reduce(&s, .setVerdict(option: "b", verdict: .pick), manifest: m)
        XCTAssertEqual(fx, [.pick(topic: "option", choice: "b", note: nil)])
        XCTAssertNil(s.verdicts["a"])
        XCTAssertEqual(s.answers["option"], "b")
        StageReducer.reduce(&s, .setVerdict(option: "b", verdict: .no), manifest: m)
        XCTAssertNil(s.answers["option"])
    }

    func testOptionNoteCommit() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setOptionNote(option: "a", text: "barely different"), manifest: m)
        let first = StageReducer.reduce(&s, .commitOptionNote(option: "a"), manifest: m)
        XCTAssertEqual(first, [.note(kind: "note", body: "[Option A · Quiet] barely different")])
        StageReducer.reduce(&s, .setVerdict(option: "a", verdict: .maybe), manifest: m)
        let second = StageReducer.reduce(&s, .commitOptionNote(option: "a"), manifest: m)
        XCTAssertEqual(second, [.verdict(topic: "option", option: "a", verdict: "maybe", note: "barely different")])
    }

    // MARK: Pins

    func testPinCapturesStateAndOpeningRestoresIt() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setScenario("error"), manifest: m)
        StageReducer.reduce(&s, .setAppearance(.dark), manifest: m)
        StageReducer.reduce(&s, .setCorners(26), manifest: m)
        StageReducer.reduce(&s, .setZoom(1.5), manifest: m)
        s.pinMode = true
        let fx = StageReducer.reduce(&s, .addPin(text: "Too tight", option: "b", x: 0.4, y: 0.2), manifest: m)
        XCTAssertEqual(s.pins.count, 1)
        XCTAssertFalse(s.pinMode)
        guard case .pin(let pin) = fx.first else { return XCTFail("expected a pin effect") }
        XCTAssertEqual(pin.scenario, "error")
        XCTAssertEqual(pin.appearance, .dark)
        XCTAssertEqual(pin.corners, 26)
        XCTAssertEqual(pin.zoom, 1.5)
        XCTAssertEqual(pin.number, 1)
        // change everything, then open the pin
        StageReducer.reduce(&s, .setScenario("rest"), manifest: m)
        StageReducer.reduce(&s, .setAppearance(.light), manifest: m)
        StageReducer.reduce(&s, .setCorners(10), manifest: m)
        StageReducer.reduce(&s, .setZoom(1.0), manifest: m)
        StageReducer.reduce(&s, .openPin(pin.id), manifest: m)
        XCTAssertEqual(s.scenario, "error")
        XCTAssertEqual(s.appearance, .dark)
        XCTAssertEqual(s.corners, 26)
        XCTAssertEqual(s.zoom, 1.5)
        XCTAssertEqual(s.selected, "b")
    }

    func testEmptyPinIsIgnoredAndNumbersIncrease() throws {
        let (m, start) = try make()
        var s = start
        XCTAssertTrue(StageReducer.reduce(&s, .addPin(text: "   ", option: nil, x: nil, y: nil), manifest: m).isEmpty)
        StageReducer.reduce(&s, .addPin(text: "one", option: nil, x: nil, y: nil), manifest: m)
        StageReducer.reduce(&s, .addPin(text: "two", option: nil, x: nil, y: nil), manifest: m)
        XCTAssertEqual(s.pins.map { $0.number }, [1, 2])
    }

    // MARK: Accept, Send back, Ask

    func testSendBackRequiresANote() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .requestSendBack, manifest: m)
        let none = StageReducer.reduce(&s, .confirmSendBack, manifest: m)
        XCTAssertTrue(none.isEmpty)
        XCTAssertNotNil(s.formError)
        XCTAssertEqual(s.sheet, .sendBack)
        StageReducer.reduce(&s, .setSendBackReason(.needsMoreOptions), manifest: m)
        StageReducer.reduce(&s, .setSendBackNote("Add a flat variant."), manifest: m)
        XCTAssertNil(s.formError)
        let fx = StageReducer.reduce(&s, .confirmSendBack, manifest: m)
        XCTAssertEqual(fx, [.sendBack(reason: "needs-more-options", note: "Add a flat variant.")])
        XCTAssertNil(s.sheet)
    }

    func testAcceptSendsAnswers() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .useRecommendation(topic: "padding"), manifest: m)
        StageReducer.reduce(&s, .requestAccept, manifest: m)
        let fx = StageReducer.reduce(&s, .confirmAccept, manifest: m)
        XCTAssertEqual(fx, [.accept(choices: ["padding": "p16"])])
        XCTAssertNil(s.sheet)
        XCTAssertNotNil(s.outcome)
    }

    func testAcceptSummaryListsChoicesUndecidedAndPlan() throws {
        var (m, s) = try make()
        StageReducer.reduce(&s, .useRecommendation(topic: "padding"), manifest: m)
        StageReducer.reduce(&s, .answer(topic: "icon", choice: "small"), manifest: m)
        let sum = StageAcceptSummary.make(manifest: m, state: s)
        XCTAssertEqual(sum.lines.map { $0.title }, ["Padding, Option B", "Icon size, Option B"])
        XCTAssertEqual(sum.lines.map { $0.isRecommended }, [true, false])
        XCTAssertEqual(sum.undecided, ["Actions", "Which toast?"])
        XCTAssertEqual(sum.repos.first?.branch, "ticket/151-toast-spacing")
        XCTAssertEqual(sum.tokenEstimate, 60000)
        XCTAssertEqual(StageAcceptSummary.formatTokens(60000), "about 60k tokens")
        m.plan = nil
        let noPlan = StageAcceptSummary.make(manifest: m, state: s)
        XCTAssertEqual(noPlan.tokenEstimate, StageAcceptSummary.heuristicTokens(decisions: 2, repos: 0))
    }

    func testAskCarriesTheStateInWords() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .setScenario("error"), manifest: m)
        StageReducer.reduce(&s, .setAskDraft("Why 16?"), manifest: m)
        let fx = StageReducer.reduce(&s, .sendAsk, manifest: m)
        guard case .note(let kind, let body) = fx.first else { return XCTFail("expected a note") }
        XCTAssertEqual(kind, "ask")
        XCTAssertTrue(body.hasPrefix("Why 16?"))
        XCTAssertTrue(body.contains("Scenario: Error"))
        XCTAssertTrue(body.contains("Padding, Option B = 12 pt"))
    }

    // MARK: Controls, presets, panels, load

    func testPresetsAndReset() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .applyPreset("airy"), manifest: m)
        XCTAssertEqual(s.controlValues["padding"], "p20")
        XCTAssertEqual(s.controlValues["icon"], "large")
        StageReducer.reduce(&s, .applyRecommendedPreset, manifest: m)
        XCTAssertEqual(s.controlValues["padding"], "p16")
        StageReducer.reduce(&s, .resetControls, manifest: m)
        XCTAssertEqual(s.controlValues["padding"], "p12")
    }

    func testAutoFoldOncePerNarrowWindow() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .autoFold(width: 900), manifest: m)
        XCTAssertTrue(s.isFolded(.controls))
        XCTAssertTrue(s.isFolded(.decision))
        StageReducer.reduce(&s, .toggleFold(.decision), manifest: m)
        StageReducer.reduce(&s, .autoFold(width: 2000), manifest: m)
        XCTAssertFalse(s.isFolded(.decision), "the owner's choice stands")
        var wide = Fixtures.state(for: m)
        StageReducer.reduce(&wide, .autoFold(width: 1600), manifest: m)
        XCTAssertFalse(wide.isFolded(.controls))
        XCTAssertFalse(wide.isFolded(.decision))
        XCTAssertTrue(wide.isFolded(.playground))
    }

    func testReconcileDropsStaleScenarioAndSelection() throws {
        let (m, _) = try make()
        var s = StageState()
        s.scenario = "pressed"
        s.selected = "zzz"
        s.sheet = .accept
        s.transport.playing = true
        StageReducer.reconcile(&s, manifest: m)
        XCTAssertEqual(s.scenario, "rest")
        XCTAssertEqual(s.selected, "a")
        XCTAssertNil(s.sheet)
        XCTAssertFalse(s.transport.playing)
        XCTAssertEqual(s.controlValues["padding"], "p12")
    }

    func testStateRoundTripsThroughJSON() throws {
        let (m, start) = try make()
        var s = start
        StageReducer.reduce(&s, .answer(topic: "icon", choice: "large"), manifest: m)
        StageReducer.reduce(&s, .pinMix, manifest: m)
        StageReducer.reduce(&s, .addPin(text: "x", option: "a", x: 0.1, y: 0.2), manifest: m)
        StageReducer.reduce(&s, .setVerdict(option: "a", verdict: .maybe), manifest: m)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(StageState.self, from: data)
        XCTAssertEqual(s, back)
    }

    // MARK: Transport

    func testTransportLoopsAndStops() {
        var t = StageTransport(playing: true, time: 5.5, speed: 1, loop: true)
        t.advance(by: 1.0, duration: 6)
        XCTAssertEqual(t.time, 0.5, accuracy: 0.0001)
        XCTAssertTrue(t.playing)
        t.loop = false
        t.time = 5.5
        t.advance(by: 1.0, duration: 6)
        XCTAssertEqual(t.time, 6)
        XCTAssertFalse(t.playing)
    }

    func testTransportIsEngagedOnlyAfterTheOwnerUsesIt() {
        var t = StageTransport()
        XCTAssertFalse(t.engaged)
        t.togglePlay(duration: 6)
        XCTAssertTrue(t.engaged)
        var u = StageTransport()
        u.scrub(to: 0, duration: 6)
        XCTAssertTrue(u.engaged)
    }

    func testTransportSpeedScrubAndStep() {
        var t = StageTransport(playing: true, time: 0, speed: 0.25, loop: true)
        t.advance(by: 2, duration: 6)
        XCTAssertEqual(t.time, 0.5, accuracy: 0.0001)
        t.step(frames: 3, duration: 6)
        XCTAssertFalse(t.playing)
        XCTAssertEqual(t.time, 0.6, accuracy: 0.0001)
        t.step(frames: -100, duration: 6)
        XCTAssertEqual(t.time, 0)
        t.scrub(to: 99, duration: 6)
        XCTAssertEqual(t.time, 6)
        t.togglePlay(duration: 6)
        XCTAssertEqual(t.time, 0, "Play at the end restarts")
        XCTAssertTrue(t.playing)
    }

    // MARK: Data source

    func testEffectsReachTheInMemorySource() async throws {
        let (m, start) = try make()
        var s = start
        let source = InMemoryStageDataSource(manifest: m)
        var effects = StageReducer.reduce(&s, .useRecommendation(topic: "padding"), manifest: m)
        effects += StageReducer.reduce(&s, .setVerdict(option: "a", verdict: .no), manifest: m)
        effects += StageReducer.reduce(&s, .addPin(text: "hi", option: "a", x: nil, y: nil), manifest: m)
        for e in effects { try await source.perform(e) }
        XCTAssertEqual(source.events.map { $0.kind }, [.pick, .verdict, .pin])
        XCTAssertEqual(source.events[0].fields["choice"], "p16")
    }

    func testAwaySourceQueuesWritesButRefusesAccept() async throws {
        let (m, _) = try make()
        let source = InMemoryStageDataSource(manifest: m)
        source.hatchAway = true
        let d = try await source.postPick(topic: "t", choice: "c", note: nil)
        XCTAssertEqual(d, .queued)
        let pending = await source.pendingCount()
        XCTAssertEqual(pending, 1)
        do {
            try await source.accept(choices: [:])
            XCTFail("Accept must not queue")
        } catch {
            XCTAssertTrue(error is StageDataSourceError)
        }
    }

    func testSourceKeepsState() async throws {
        let (m, start) = try make()
        var s = start
        s.zoom = 1.5
        let source = InMemoryStageDataSource(manifest: m)
        let none = try await source.loadState()
        XCTAssertNil(none)
        await source.saveState(s)
        let loaded = try await source.loadState()
        XCTAssertEqual(loaded?.zoom, 1.5)
    }
}
