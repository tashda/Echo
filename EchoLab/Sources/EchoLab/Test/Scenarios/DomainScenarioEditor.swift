import EchoSenseScenarios
import SwiftUI

/// One domain scenario: what it is, the input, and the expected lines beside the actual lines.
struct DomainScenarioEditor: View {
    let domain: ScenarioDomain
    @Binding var scenario: DomainScenario
    let result: DomainResult?
    let onDelete: () -> Void

    private var expectedText: Binding<String> {
        Binding(
            get: { (scenario.expected ?? []).joined(separator: "\n——\n") },
            set: { scenario.expected = $0.isEmpty ? nil : $0.components(separatedBy: "\n——\n") })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                header
                field("Scenario", domain.inputLabel) { editor($scenario.input) }
                HStack(alignment: .top, spacing: SpacingTokens.md) {
                    field("Expected", "\(domain.expectedLabel); separate lines with a row holding ——") { editor(expectedText) }
                    field("Actual", "What the real code gives now") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array((result?.actual ?? []).enumerated()), id: \.offset) { index, line in
                                let differs = scenario.expected.map { index >= $0.count || $0[index] != line } ?? false
                                Text(line.isEmpty ? " " : line).font(TypographyTokens.code).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(6)
                                    .background((differs ? ColorTokens.Status.error : ColorTokens.Workspace.groupFill).opacity(differs ? 0.15 : 1), in: .rect(cornerRadius: 6))
                            }
                            if result?.actual.isEmpty == true { Text("Nothing").foregroundStyle(ColorTokens.Text.tertiary) }
                        }
                    }
                }
                verdict
                HStack {
                    Button("Use actual as expected", systemImage: "arrow.left.circle") { scenario.expected = result?.actual; scenario.knownIssue = nil }
                        .help("Only when the actual lines are what should happen")
                    Spacer()
                    Button("Delete", role: .destructive, action: onDelete)
                }
                .controlSize(.small)
            }
            .padding(SpacingTokens.md)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Title", text: $scenario.title, prompt: Text("What this checks")).font(TypographyTokens.title3.weight(.semibold)).textFieldStyle(.plain)
                Text(scenario.id).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
            }
            TextField("Should", text: $scenario.should, prompt: Text("What should happen, in words"), axis: .vertical)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch result?.verdict {
            case .pass: Label("As expected", systemImage: "checkmark.circle.fill").foregroundStyle(ColorTokens.Status.success)
            case .fail: Label("Does not match", systemImage: "xmark.octagon.fill").foregroundStyle(ColorTokens.Status.error)
            case .knownIssue: Label("Known issue", systemImage: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.Status.warning)
            default: Label("No expected result yet", systemImage: "questionmark.circle").foregroundStyle(ColorTokens.Text.secondary)
            }
            ForEach(result?.differences ?? [], id: \.self) { Text($0).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary) }
            TextField("Known issue", text: Binding(get: { scenario.knownIssue ?? "" }, set: { scenario.knownIssue = $0.isEmpty ? nil : $0 }),
                      prompt: Text("Why it fails today, if it does"), axis: .vertical)
        }
    }

    private func field<Content: View>(_ title: String, _ hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(TypographyTokens.standard.weight(.semibold))
            Text(hint).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editor(_ text: Binding<String>) -> some View {
        TextEditor(text: text).font(TypographyTokens.code).scrollContentBackground(.hidden)
            .frame(minHeight: 90).padding(4)
            .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: 6))
            .autocorrectionDisabled()
    }
}
