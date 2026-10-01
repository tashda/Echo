import EchoSenseScenarios
import SwiftUI

/// One scenario in the middle column: its result, its title and, when it is wrong, what is wrong in
/// a few words ("missing invoices"), so the list can be read without opening anything. Your answer
/// shows on the right; the known-issue flag doesn't (it only tells the tests what fails today).
struct ScenarioListRow: View {
    let scenario: CompletionScenario
    let result: ScenarioResult?

    var body: some View {
        let outcome = ScenarioOutcome(result)
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: outcome.symbol).foregroundStyle(outcome.tint).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: SpacingTokens.xxs) {
                    Text(scenario.title).lineLimit(1)
                    Spacer(minLength: 0)
                    if let thread = ScenarioThreadState(scenario) {
                        Image(systemName: thread.symbol).foregroundStyle(ColorTokens.accent).help(thread.title)
                    }
                    if !scenario.rules.isEmpty {
                        Image(systemName: "link").foregroundStyle(ColorTokens.Text.tertiary).help("Follows \(scenario.rules.joined(separator: ", "))")
                    }
                    if scenario.review != .imported {
                        Image(systemName: scenario.review.symbol).foregroundStyle(ColorTokens.Text.secondary).help(scenario.review.title)
                    }
                }
                Text(line(outcome)).font(TypographyTokens.detailMono)
                    .foregroundStyle(outcome == .wrong ? ColorTokens.Status.error.opacity(0.85) : ColorTokens.Text.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, SpacingTokens.xxxs)
    }

    private func line(_ outcome: ScenarioOutcome) -> String {
        switch outcome {
        case .wrong, .couldNotRun: result?.briefProblem ?? outcome.title
        case .noExpectation: "no expectation yet"
        case .right: scenario.sql.replacingOccurrences(of: "\n", with: " ")
        }
    }
}
