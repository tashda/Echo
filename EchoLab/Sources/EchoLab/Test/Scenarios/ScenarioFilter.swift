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

/// The left column's selection: everything, one result, one review state or one area.
enum ScenarioFilter: Hashable, RawRepresentable {
    case all
    case outcome(ScenarioOutcome)
    case review(ScenarioReview)
    case area(String)

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ".", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count == 2 ? parts[1] : nil) {
        case ("all", _): self = .all
        case ("outcome", let value?): guard let outcome = ScenarioOutcome(rawValue: value) else { return nil }; self = .outcome(outcome)
        case ("review", let value?): guard let review = ScenarioReview(rawValue: value) else { return nil }; self = .review(review)
        case ("area", let value?): self = .area(value)
        default: return nil
        }
    }

    var rawValue: String {
        switch self {
        case .all: "all"
        case .outcome(let outcome): "outcome.\(outcome.rawValue)"
        case .review(let review): "review.\(review.rawValue)"
        case .area(let group): "area.\(group)"
        }
    }
}

extension ScenarioStore {
    func outcome(for id: String) -> ScenarioOutcome { ScenarioOutcome(result(for: id)) }

    func matches(_ scenario: CompletionScenario, filter: ScenarioFilter) -> Bool {
        switch filter {
        case .all: true
        case .outcome(let outcome): outcome == self.outcome(for: scenario.id)
        case .review(let review): scenario.review == review
        case .area(let group): scenario.group == group
        }
    }

    func count(_ filter: ScenarioFilter) -> Int { scenarios.count { matches($0, filter: filter) } }

    func count(_ outcome: ScenarioOutcome, in group: String) -> Int {
        library.scenarios(in: group).count { self.outcome(for: $0.id) == outcome }
    }

    /// Records the owner's answer without touching anything else in the scenario.
    func setReview(_ review: ScenarioReview, for id: String) {
        guard var scenario = library.scenario(id: id), scenario.review != review else { return }
        scenario.review = review
        update(scenario)
    }
}
