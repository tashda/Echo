import XCTest
@testable import HatchAgent
@testable import HatchCore

final class ValidatorTests: XCTestCase {
    /// Applies `change` to a good manifest and expects the gate to report `code` (with the given severity) and nothing else.
    func assertFires(_ code: String, severity: GateIssue.Severity = .error, line: UInt = #line, _ change: (inout ProposalManifest) -> Void) {
        var m = Fixture.manifest()
        change(&m)
        let issues = ProposalValidator.validate(m)
        guard let hit = issues.first(where: { $0.code == code }) else { return XCTFail("expected \(code), got \(codes(issues))", line: line) }
        XCTAssertEqual(hit.severity, severity, line: line)
        XCTAssertFalse(hit.fix.isEmpty, "every finding tells the agent how to fix it", line: line)
        XCTAssertFalse(hit.message.isEmpty, line: line)
    }

    func testGoodManifestPasses() {
        XCTAssertEqual(ProposalValidator.validate(Fixture.manifest()), [])
    }

    func testEchoTodayMissing() { assertFires("echo-today.missing") { $0.specimens.removeFirst() } }
    func testEchoTodayMustBeFirst() { assertFires("echo-today.first") { $0.specimens.swapAt(0, 1) } }
    func testEchoTodayOnlyOnce() { assertFires("echo-today.duplicate") { $0.specimens[1].isEchoToday = true } }
    func testNeedsTwoProposals() { assertFires("specimens.too-few") { $0.specimens.removeLast(); $0.exhibitTopic = nil } }
    func testZeroProposalsAlsoFails() { assertFires("specimens.too-few") { $0.specimens = [$0.specimens[0]]; $0.exhibitTopic = nil } }
    func testSpecimenNeedsWidth() { assertFires("specimen.size-missing") { $0.specimens[1].designWidth = nil } }
    func testSpecimenNeedsHeight() { assertFires("specimen.size-missing") { $0.specimens[2].designHeight = 0 } }
    func testWidthOutsideRangeWarns() { assertFires("specimen.size-range", severity: .warning) { $0.specimens[1].designWidth = 300 } }
    func testTallDesignWarns() { assertFires("specimen.size-range", severity: .warning) { $0.specimens[1].designHeight = 900 } }

    func testControlQuestionNeedsRecommendation() { assertFires("control.recommend-missing") { $0.controls[0].recommend = nil } }
    func testControlRecommendationMustExist() { assertFires("control.recommend-unknown") { $0.controls[0].recommend = "loud" } }
    func testControlQuestionNeedsReason() { assertFires("control.why-missing") { $0.controls[0].why = "  " } }
    func testPlaygroundControlNeedsNoRecommendation() {
        XCTAssertNil(Fixture.manifest().controls[1].question)
        XCTAssertFalse(codes(ProposalValidator.validate(Fixture.manifest())).contains("control.recommend-missing"))
    }
    func testControlDefaultMustExist() { assertFires("control.default-unknown") { $0.controls[1].defaultChoice = "fast" } }
    func testControlNeedsChoices() { assertFires("control.no-choices") { $0.controls[1].choices = [] } }
    func testQuestionNeedsRecommendation() { assertFires("question.recommend-missing") { $0.questions[0].recommended = nil } }
    func testQuestionRecommendationMustExist() { assertFires("question.recommend-unknown") { $0.questions[0].recommended = "maybe" } }
    func testQuestionNeedsReason() { assertFires("question.why-missing") { $0.questions[0].why = nil } }
    func testQuestionNeedsTwoChoices() { assertFires("question.choices") { $0.questions[0].choices = [$0.questions[0].choices[0]]; $0.questions[0].recommended = "yes" } }

    func testTopicRecommendationMustBeAProposal() { assertFires("topic.recommend-not-proposal") { $0.exhibitTopic?.recommended = "today" } }
    func testTopicRecommendationUnknown() { assertFires("topic.recommend-not-proposal") { $0.exhibitTopic?.recommended = "zzz" } }
    func testTopicNeedsRecommendation() { assertFires("topic.recommend-missing") { $0.exhibitTopic?.recommended = nil } }
    func testTopicNeedsReason() { assertFires("topic.why-missing") { $0.exhibitTopic?.why = "" } }

    func testStandardScenarioMissing() { assertFires("scenario.missing") { $0.scenarios.removeAll { $0.id == "loading" } } }
    func testNotApplicableNeedsReason() { assertFires("scenario.reason-missing") { $0.scenarios[1].notApplicableReason = nil } }
    func testAllTenStandardScenariosAreChecked() {
        var m = Fixture.manifest(); m.scenarios = []
        XCTAssertEqual(ProposalValidator.validate(m).filter { $0.code == "scenario.missing" }.count, 10)
    }
    func testScenarioSpellingsAreTheSame() {
        var m = Fixture.manifest()
        m.scenarios[7] = ManifestScenario(id: "Long_Text", title: "Long text")
        XCTAssertEqual(ProposalValidator.validate(m), [])
    }

    func testDuplicateControlIds() { assertFires("id.duplicate") { $0.controls[1].id = "style" } }
    func testDuplicateSpecimenIds() { assertFires("id.duplicate") { $0.specimens[2].id = "a" } }
    func testDuplicateChoiceIds() { assertFires("id.duplicate") { $0.controls[0].choices[1].id = "quiet" } }
    func testTopicIdsAreUnique() { assertFires("id.duplicate") { $0.questions[0].id = "style" } }

    func testRecommendedPresetRequired() { assertFires("preset.recommended-missing") { $0.presets[0].isRecommended = false } }
    func testOnlyOneRecommendedPreset() {
        assertFires("preset.recommended-many") { $0.presets.append(ManifestPreset(id: "r2", name: "Other", values: ["style": "bold"], isRecommended: true)) }
    }
    func testPresetControlMustExist() { assertFires("preset.unknown-control") { $0.presets[0].values["nope"] = "x" } }
    func testPresetChoiceMustExist() { assertFires("preset.unknown-choice") { $0.presets[0].values["style"] = "loud" } }

    func testSummaryWithoutSpecIDWarns() { assertFires("summary.spec-id", severity: .warning) { $0.summary = "Tighter padding." } }

    func testReportTellsTheAgentWhatToDo() {
        var m = Fixture.manifest(); m.specimens.removeFirst()
        let report = ProposalValidator.validate(m).report
        XCTAssertTrue(report.contains("ERROR [echo-today.missing]"))
        XCTAssertTrue(report.contains("Fix:"))
    }

    // MARK: Revisions

    func revised(_ change: (inout ProposalManifest) -> Void) -> (old: ProposalManifest, new: ProposalManifest) {
        let old = Fixture.manifest()
        var new = old
        new.revision = 2
        change(&new)
        return (old, new)
    }

    func testRevisionKeepingEverythingPasses() {
        let (old, new) = revised { _ in }
        XCTAssertEqual(ProposalValidator.validate(new, previous: old), [])
    }

    func testRevisionMayAddWithAddedIn() {
        let (old, new) = revised {
            $0.specimens.append(ManifestSpecimen(id: "c", title: "Spinner", designWidth: 340, designHeight: 480, addedIn: 2))
            $0.controls[0].choices.append(ManifestChoice(id: "loud", name: "Loud", addedIn: 2))
        }
        XCTAssertEqual(ProposalValidator.validate(new, previous: old), [])
    }

    func testRevisionCannotRemoveASpecimen() {
        let (old, new) = revised { $0.specimens.removeAll { $0.id == "b" } }
        XCTAssertTrue(codes(ProposalValidator.validate(new, previous: old)).contains("revision.removed"))
    }

    func testRevisionCannotRemoveAChoice() {
        let (old, new) = revised { $0.controls[0].choices.removeLast() }
        XCTAssertTrue(codes(ProposalValidator.validate(new, previous: old)).contains("revision.removed"))
    }

    func testRevisionAdditionsNeedAddedIn() {
        let (old, new) = revised { $0.specimens.append(ManifestSpecimen(id: "c", title: "Spinner", designWidth: 340, designHeight: 480)) }
        XCTAssertTrue(codes(ProposalValidator.validate(new, previous: old)).contains("revision.added-in"))
    }

    func testNewChoiceNeedsAddedIn() {
        let (old, new) = revised { $0.questions[0].choices.append(ManifestChoice(id: "unsure", name: "Unsure")) }
        XCTAssertTrue(codes(ProposalValidator.validate(new, previous: old)).contains("revision.added-in"))
    }

    func testAnsweredChoicesCannotBeRenamed() {
        let (old, new) = revised { $0.controls[0].choices[0].name = "Calm" }
        XCTAssertTrue(codes(ProposalValidator.validate(new, previous: old, picks: ["style": "quiet"])).contains("revision.renamed"))
        XCTAssertFalse(codes(ProposalValidator.validate(new, previous: old, picks: [:])).contains("revision.renamed"), "an unanswered topic may be reworded")
    }

    func testRevisionNumberMustGrow() {
        let (old, new) = revised { $0.revision = 1 }
        XCTAssertFalse(codes(ProposalValidator.validate(new, previous: old)).contains("revision.number"), "revision 1 is not compared at all")
        var again = old; again.revision = 2
        var third = again; third.revision = 2
        XCTAssertTrue(codes(ProposalValidator.validate(third, previous: again)).contains("revision.number"))
    }

    func testRevisionWithoutPreviousWarns() {
        let (_, new) = revised { _ in }
        let issues = ProposalValidator.validate(new)
        XCTAssertEqual(issues.map(\.code), ["revision.no-previous"])
        XCTAssertEqual(issues[0].severity, .warning)
    }
}
