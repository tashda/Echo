import EchoSenseScenarios
import SwiftUI

/// The scenario's expectation as sentences, each ticked or crossed on its own ("offers `customers`",
/// "never offers `users`"), with the reason under a crossed one. These are the same checks the
/// package's tests assert on (`ScenarioResult.checks`).
struct ScenarioChecksCard: View {
    let result: ScenarioResult?
    /// Writes what EchoSense does now as the expectation.
    var useActual: (() -> Void)?

    var body: some View {
        let checks = result?.checks ?? []
        let engine = checks.filter { $0.subject == .echoSense }, editor = checks.filter { $0.subject == .editor }
        LabReadingCard(title: "Checks", symbol: "checklist") {
            if case .error(let message)? = result?.verdict {
                Label(message, systemImage: "exclamationmark.octagon").foregroundStyle(ColorTokens.Status.warning)
            } else if checks.isEmpty {
                noExpectation
            } else {
                if !engine.isEmpty { group("At the caret, EchoSense", engine) }
                if !editor.isEmpty { group("Echo's editor", editor) }
            }
        }
    }

    private func group(_ title: String, _ checks: [ScenarioCheck]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            ForEach(checks) { check in row(check) }
        }
        .padding(.bottom, SpacingTokens.xxs)
    }

    private func row(_ check: ScenarioCheck) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(check.passed ? ColorTokens.Status.success : ColorTokens.Status.error)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.markdown(check.statement)).font(TypographyTokens.prominent)
                if let failure = check.failure {
                    Text(failure).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.error).textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, SpacingTokens.xxxs)
    }

    private var noExpectation: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("No expectation yet, so there is nothing to check.").font(TypographyTokens.standard)
            Text("If the popup above is what should happen, use it as the expectation. Otherwise press Edit and write it.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            if let useActual, result?.actual != nil {
                Button("Use what it does now", systemImage: "equal.circle", action: useActual)
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
            }
        }
    }

    /// Backticks become inline code.
    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
