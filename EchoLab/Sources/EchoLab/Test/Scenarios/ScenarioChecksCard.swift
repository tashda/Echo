import EchoSenseScenarios
import SwiftUI

/// The scenario's expectation as sentences, each ticked or crossed on its own ("offers `customers`",
/// "never offers `users`"), with the reason under a crossed one: the scenario's own checks, then each
/// shared rule's, then the editor's. These are the checks the package's tests assert on. Each has a
/// comment button, so feedback can point at exactly one check.
struct ScenarioChecksCard: View {
    let result: ScenarioResult?
    /// Check ids that have comments in the thread.
    var commented: Set<String> = []
    /// Writes what EchoSense does now as the expectation.
    var useActual: (() -> Void)?
    /// Starts a comment about one check.
    var commentAbout: ((ScenarioCheck) -> Void)?

    var body: some View {
        let checks = result?.checks ?? []
        let own = checks.filter { $0.subject == .echoSense && $0.rule == nil }
        let editor = checks.filter { $0.subject == .editor }
        LabReadingCard(title: "Checks", symbol: "checklist") {
            if case .error(let message)? = result?.verdict {
                Label(message, systemImage: "exclamationmark.octagon").foregroundStyle(ColorTokens.Status.warning)
            } else if checks.isEmpty {
                noExpectation
            } else {
                if !own.isEmpty { group("At the caret, EchoSense", symbol: "target", own) }
                ForEach(ruleIDs(checks), id: \.self) { id in
                    let rule = result?.rules.first { $0.id == id }
                    group("Rule \(id): \(rule?.title ?? "missing")", symbol: "link", checks.filter { $0.rule == id })
                }
                if !editor.isEmpty { group("Echo's editor", symbol: "macwindow", editor) }
            }
        }
    }

    private func ruleIDs(_ checks: [ScenarioCheck]) -> [String] {
        var ids: [String] = []
        for id in checks.compactMap(\.rule) where !ids.contains(id) { ids.append(id) }
        return ids
    }

    private func group(_ title: String, symbol: String, _ checks: [ScenarioCheck]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Label(title, systemImage: symbol).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
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
            Spacer(minLength: SpacingTokens.xs)
            if let commentAbout {
                Button("Comment on this check", systemImage: commented.contains(check.id) ? "text.bubble.fill" : "text.bubble") { commentAbout(check) }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                    .foregroundStyle(commented.contains(check.id) ? ColorTokens.accent : ColorTokens.Text.tertiary)
                    .help("Write feedback about this check for the agent")
            }
        }
        .padding(.vertical, SpacingTokens.xxxs)
    }

    private var noExpectation: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("No expectation yet, so there is nothing to check.").font(TypographyTokens.standard)
            Text("If the popup above is what should happen, use it as the expectation. Otherwise press Edit and drag the right suggestions in.")
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
