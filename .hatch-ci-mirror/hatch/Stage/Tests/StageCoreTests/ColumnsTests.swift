import XCTest
@testable import StageCore

final class ColumnsTests: XCTestCase {
    func testColumnsStartWithEchoToday() throws {
        let m = try Fixtures.toast()
        let cols = StageColumns.columns(manifest: m, state: Fixtures.state(for: m))
        XCTAssertEqual(cols.map { $0.id }, ["today", "a", "b"])
        XCTAssertTrue(cols[0].isToday)
        XCTAssertFalse(cols[0].takesVerdict)
        XCTAssertTrue(cols[1].takesVerdict)
    }

    func testFilmstripFromFourOptions() {
        XCTAssertFalse(StageColumns.usesFilmstrip(optionCount: 3))
        XCTAssertTrue(StageColumns.usesFilmstrip(optionCount: 4))
    }

    func testEchoTodayDoesNotCountTowardTheFilmstrip() {
        // Echo today plus three options is four columns but only three options: still side by side (decision H2).
        var m = Fixtures.fiveOptions()
        m.specimens = Array(m.specimens.prefix(4))
        let cols = StageColumns.columns(manifest: m, state: Fixtures.state(for: m))
        XCTAssertEqual(cols.count, 4)
        XCTAssertFalse(StageColumns.usesFilmstrip(columns: cols))
        let five = Fixtures.fiveOptions()
        XCTAssertTrue(StageColumns.usesFilmstrip(columns: StageColumns.columns(manifest: five, state: Fixtures.state(for: five))))
    }

    func testStepWrapsAndSkipsEchoToday() throws {
        let m = Fixtures.fiveOptions()
        let cols = StageColumns.columns(manifest: m, state: Fixtures.state(for: m))
        XCTAssertEqual(StageColumns.step(from: "a", by: 1, in: cols), "b")
        XCTAssertEqual(StageColumns.step(from: "e", by: 1, in: cols), "a")
        XCTAssertEqual(StageColumns.step(from: "a", by: -1, in: cols), "e")
        XCTAssertEqual(StageColumns.step(from: nil, by: 1, in: cols), "a")
        XCTAssertEqual(StageColumns.step(from: "gone", by: -1, in: cols), "e")
    }

    func testShownOptionsFilterColumns() throws {
        let m = Fixtures.fiveOptions()
        var s = Fixtures.state(for: m)
        StageReducer.reduce(&s, .toggleShown("b"), manifest: m)
        StageReducer.reduce(&s, .toggleShown("d"), manifest: m)
        XCTAssertEqual(StageColumns.columns(manifest: m, state: s).map { $0.id }, ["t", "a", "c", "e"])
        StageReducer.reduce(&s, .showAllOptions, manifest: m)
        XCTAssertEqual(StageColumns.columns(manifest: m, state: s).count, 6)
    }

    func testToggleShownKeepsAtLeastOneAndResetsToNilWhenAll() throws {
        let m = Fixtures.fiveOptions()
        var s = Fixtures.state(for: m)
        for k in ["a", "b", "c", "d", "e"] { StageReducer.reduce(&s, .toggleShown(k), manifest: m) }
        XCTAssertEqual(s.shownOptions, ["e"])
        StageReducer.reduce(&s, .toggleShown("a"), manifest: m)
        StageReducer.reduce(&s, .toggleShown("b"), manifest: m)
        StageReducer.reduce(&s, .toggleShown("c"), manifest: m)
        StageReducer.reduce(&s, .toggleShown("d"), manifest: m)
        XCTAssertNil(s.shownOptions)
    }

    // MARK: Matrix

    func testMatrixDifferenceRuleIsStrictlyMoreThan14() {
        XCTAssertFalse(StageMatrix.differs(height: 64, todayHeight: 50))
        XCTAssertTrue(StageMatrix.differs(height: 64.5, todayHeight: 50))
        XCTAssertTrue(StageMatrix.differs(height: 30, todayHeight: 50))
        XCTAssertFalse(StageMatrix.differs(height: nil, todayHeight: 50))
        XCTAssertFalse(StageMatrix.differs(height: 90, todayHeight: nil))
        XCTAssertFalse(StageMatrix.differs(height: 90, todayHeight: 10, isToday: true))
    }

    func testMatrixCellsSkipNotApplicableScenarios() throws {
        let m = try Fixtures.toast()
        let cols = StageColumns.columns(manifest: m, state: Fixtures.state(for: m))
        let rows = StageMatrix.cells(columns: cols, scenarios: m.effectiveScenarios) { col, sc in
            col.isToday ? 50 : (sc == "error" ? 90 : 55)
        }
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows[0].map { $0.differs }, [false, false, false])
        let errorRow = rows.first(where: { $0[0].scenarioID == "error" })
        XCTAssertEqual(errorRow?.map { $0.differs }, [false, true, true])
        XCTAssertEqual(errorRow?[1].todayHeight, 50)
    }

    // MARK: Mix

    func testMixUsesAnswersOverPreview() throws {
        let m = try Fixtures.toast()
        var s = Fixtures.state(for: m)
        StageReducer.reduce(&s, .setControl(id: "padding", value: "p20"), manifest: m)
        XCTAssertEqual(StageColumns.mixControls(manifest: m, state: s)["padding"], "p20")
        StageReducer.reduce(&s, .answer(topic: "padding", choice: "p16"), manifest: m)
        let mix = StageColumns.mixControls(manifest: m, state: s)
        XCTAssertEqual(mix["padding"], "p16")
        XCTAssertEqual(mix["icon"], "medium")
    }

    func testPinningCreatesMix1ThenMix2WithFrozenValues() throws {
        let m = try Fixtures.toast()
        var s = Fixtures.state(for: m)
        StageReducer.reduce(&s, .answer(topic: "padding", choice: "p16"), manifest: m)
        StageReducer.reduce(&s, .pinMix, manifest: m)
        StageReducer.reduce(&s, .answer(topic: "padding", choice: "p20"), manifest: m)
        StageReducer.reduce(&s, .pinMix, manifest: m)
        XCTAssertEqual(s.pinnedMixes.map { $0.title }, ["Mix 1", "Mix 2"])
        XCTAssertEqual(s.pinnedMixes[0].controls["padding"], "p16")
        XCTAssertEqual(s.pinnedMixes[1].controls["padding"], "p20")
        let cols = StageColumns.columns(manifest: m, state: s)
        XCTAssertEqual(cols.map { $0.id }, ["today", "a", "b", "mix.1", "mix.2"])
        XCTAssertEqual(cols[3].specimenID, "b")
        XCTAssertEqual(cols[3].controls["padding"], "p16")
    }

    func testRemovedMixNumberIsReused() throws {
        let m = try Fixtures.toast()
        var s = Fixtures.state(for: m)
        StageReducer.reduce(&s, .pinMix, manifest: m)
        StageReducer.reduce(&s, .pinMix, manifest: m)
        StageReducer.reduce(&s, .removeMix("mix.1"), manifest: m)
        StageReducer.reduce(&s, .pinMix, manifest: m)
        XCTAssertEqual(s.pinnedMixes.map { $0.id }, ["mix.2", "mix.1"])
    }

    func testLiveMixColumnAppearsWhenSwitchedOn() throws {
        let m = try Fixtures.toast()
        var s = Fixtures.state(for: m)
        StageReducer.reduce(&s, .toggleLiveMix, manifest: m)
        let cols = StageColumns.columns(manifest: m, state: s)
        XCTAssertEqual(cols.last?.kind, .liveMix)
        XCTAssertEqual(cols.last?.id, StageColumns.liveMixID)
    }

    // MARK: Zoom

    func testZoomFitsAndLabels() {
        let r = StageZoom.effectiveScale(zoom: 1.0, designWidth: 300, available: 222)
        XCTAssertTrue(r.fitted)
        XCTAssertEqual(r.scale, 0.74, accuracy: 0.001)
        XCTAssertEqual(StageZoom.label(scale: r.scale), "74%")
        let ok = StageZoom.effectiveScale(zoom: 1.0, designWidth: 300, available: 400)
        XCTAssertFalse(ok.fitted)
        XCTAssertEqual(ok.scale, 1.0)
    }

    func testZoomSteps() {
        XCTAssertEqual(StageZoom.nextStep(from: 1.0, up: true), 1.25)
        XCTAssertEqual(StageZoom.nextStep(from: 1.0, up: false), 0.75)
        XCTAssertEqual(StageZoom.nextStep(from: 2.0, up: true), 2.0)
        XCTAssertEqual(StageZoom.clamp(9), 2.0)
    }
}
