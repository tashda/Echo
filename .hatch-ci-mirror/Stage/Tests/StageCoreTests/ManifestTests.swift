import XCTest
@testable import StageCore

final class ManifestTests: XCTestCase {
    func testSampleManifestDecodes() throws {
        let m = try Fixtures.toast()
        XCTAssertEqual(m.revision, 2)
        XCTAssertEqual(m.specimens.count, 3)
        XCTAssertEqual(m.echoToday?.id, "today")
        XCTAssertEqual(m.proposalSpecimens.map { $0.id }, ["a", "b"])
        XCTAssertEqual(m.controls.count, 3)
        XCTAssertEqual(m.decisionControls.map { $0.id }, ["padding", "icon"])
        XCTAssertEqual(m.playgroundControls.map { $0.id }, ["timeout"])
        XCTAssertEqual(m.controls[0].defaultChoice, "p12")
        XCTAssertNotNil(m.conformance)
        XCTAssertEqual(m.mixSpecimenID, "b")
    }

    func testExhibitsKeyIsAcceptedForSpecimens() throws {
        let m = try StageManifest.parse(json: #"{"exhibits":[{"id":"x","title":"X"}]}"#)
        XCTAssertEqual(m.specimens.map { $0.id }, ["x"])
    }

    func testEmptyJSONIsForgiving() throws {
        let m = try StageManifest.parse(json: "{}")
        XCTAssertEqual(m.revision, 1)
        XCTAssertTrue(m.specimens.isEmpty)
        XCTAssertEqual(m.effectiveScenarios.map { $0.id }, ["rest"])
    }

    func testBrokenJSONThrowsReadableError() {
        XCTAssertThrowsError(try StageManifest.parse(json: "{nope")) { error in
            XCTAssertTrue("\(error)".contains("not valid JSON"))
        }
    }

    func testRoundTrip() throws {
        let m = try Fixtures.toast()
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(StageManifest.self, from: data)
        XCTAssertEqual(m, back)
    }

    func testDecisionsOrderControlsQuestionsTopic() throws {
        let m = try Fixtures.toast()
        XCTAssertEqual(m.decisions.map { $0.id }, ["padding", "icon", "actions", "option"])
        XCTAssertEqual(m.decision("option")?.choices.map { $0.id }, ["a", "b"])
        XCTAssertEqual(m.decision("option")?.source, .specimens)
        XCTAssertEqual(m.decision("padding")?.choiceName("p16"), "16 pt")
    }

    func testScenariosApplicability() throws {
        let m = try Fixtures.toast()
        XCTAssertEqual(m.applicableScenarios.map { $0.id }, ["rest", "hover", "error", "long-text", "many-items"])
        let pressed = m.effectiveScenarios.first(where: { $0.id == "pressed" })
        XCTAssertEqual(pressed?.applicable, false)
        XCTAssertNotNil(pressed?.notApplicableReason)
    }

    func testRecommendedControlValuesUsePreset() throws {
        let m = try Fixtures.toast()
        XCTAssertEqual(m.recommendedControlValues["padding"], "p16")
        XCTAssertEqual(m.recommendedControlValues["icon"], "medium")
        XCTAssertEqual(m.recommendedControlValues["timeout"], "4")
    }

    func testRecommendedValuesFallBackToControlRecommendations() {
        var m = Fixtures.fiveOptions()
        m.presets = []
        XCTAssertEqual(m.recommendedControlValues["pad"], "16")
    }

    func testNewBadgeNeedsRevisionAbove1() throws {
        let m = try Fixtures.toast()
        XCTAssertTrue(m.isNew(addedIn: 2))
        XCTAssertFalse(m.isNew(addedIn: 1))
        XCTAssertFalse(m.isNew(addedIn: nil))
        var first = m
        first.revision = 1
        XCTAssertFalse(first.isNew(addedIn: 1))
    }

    func testNewItemsListWhatRevisionAdded() throws {
        let m = try Fixtures.toast()
        XCTAssertEqual(m.newItems, ["New choice in Padding, Option B: 20 pt"])
        var first = m
        first.revision = 1
        XCTAssertTrue(first.newItems.isEmpty)
    }

    func testStandardScenarioNormalize() {
        XCTAssertEqual(StandardScenarios.normalize("Long text"), "long-text")
        XCTAssertEqual(StandardScenarios.normalize("long_text"), "long-text")
        XCTAssertEqual(StandardScenarios.all.count, 10)
    }

    func testEmbeddedManifestInRoundMatchesSampleFile() throws {
        let json = try Fixtures.sampleManifestText()
        let swift = Fixtures.packageRoot.appendingPathComponent("Sources/Rounds/ToastR18/ToastManifest.swift")
        let text = try String(contentsOf: swift, encoding: .utf8)
        XCTAssertTrue(text.contains(json), "ToastManifest.swift must embed manifest.sample.json verbatim.")
    }
}
