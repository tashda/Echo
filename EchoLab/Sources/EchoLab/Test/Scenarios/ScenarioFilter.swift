import EchoSenseScenarios
import SwiftUI

/// What a scenario's run says, in the owner's terms: it does what it should, or it doesn't.
/// A known issue is still wrong; it only carries a badge.
enum ScenarioOutcome: String, CaseIterable, Hashable {
    case wrong, right, noExpectation, couldNotRun

    init(_ result: ScenarioResult?) {
        guard let result else { self = .noExpectation; return }
        if case .error = result.verdict { self = .couldNotRun }
        else if result.isFailing { self = .wrong }
        else if result.isPass { self = .right }
        else { self = .noExpectation }
    }

    var title: String {
        switch self {
        case .wrong: "Wrong"
        case .right: "Right"
        case .noExpectation: "No expectation yet"
        case .couldNotRun: "Could not run"
        }
    }

    var symbol: String {
        switch self {
        case .wrong: "xmark.circle.fill"
        case .right: "checkmark.circle.fill"
        case .noExpectation: "questionmark.circle"
        case .couldNotRun: "exclamationmark.octagon"
        }
    }

    var tint: Color {
        switch self {
        case .wrong: ColorTokens.Status.error
        case .right: ColorTokens.Status.success
        case .noExpectation: ColorTokens.Text.secondary
        case .couldNotRun: ColorTokens.Status.warning
        }
    }
}

extension ScenarioReview {
    /// The owner's answer to "is this what should happen?".
    var title: String {
        switch self {
        case .imported: "Not reviewed"
        case .approved: "You said right"
        case .flagged: "You said wrong"
        }
    }

    var symbol: String {
        switch self {
        case .imported: "circle.dashed"
        case .approved: "hand.thumbsup"
        case .flagged: "flag"
        }
    }
}

/// The left column's three filters, combined: a result, a review state and an area (nil = all).
/// Remembered between launches.
struct ScenarioFilters: Equatable {
    var outcome: ScenarioOutcome?
    var review: ScenarioReview?
    var area: String?

    /// Where the owner starts: everything not reviewed yet.
    static let reviewQueue = ScenarioFilters(outcome: nil, review: .imported, area: nil)

    func admits(_ scenario: CompletionScenario, outcome scenarioOutcome: ScenarioOutcome) -> Bool {
        (outcome == nil || outcome == scenarioOutcome) && (review == nil || review == scenario.review) && (area == nil || area == scenario.group)
    }
}

extension ScenarioStore {
    func outcome(for id: String) -> ScenarioOutcome { ScenarioOutcome(result(for: id)) }

    func matches(_ scenario: CompletionScenario, _ filters: ScenarioFilters) -> Bool {
        filters.admits(scenario, outcome: outcome(for: scenario.id))
    }

    func count(_ filters: ScenarioFilters) -> Int { scenarios.count { matches($0, filters) } }

    /// Scenarios waiting for the agent: flagged ones (fix the scenario), and approved ones that fail (fix EchoSense).
    var waitingForAgent: (flagged: Int, toFix: Int) {
        (scenarios.count { $0.review == .flagged },
         scenarios.count { $0.review == .approved && outcome(for: $0.id) == .wrong })
    }

    /// Records the owner's answer without touching anything else in the scenario.
    func setReview(_ review: ScenarioReview, for id: String) {
        guard var scenario = library.scenario(id: id), scenario.review != review else { return }
        scenario.review = review
        update(scenario)
    }
}
