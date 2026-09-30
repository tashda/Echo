import EchoSenseScenarios
import SwiftUI

/// The bar under a scenario: the owner's answer to "is this what should happen?" (Right, Y; Wrong,
/// N), a note for the agent when it is wrong, and Edit (⌘E). Y and N also work from the list.
struct ScenarioReviewBar: View {
    let review: ScenarioReview
    @Binding var note: String
    let isEditing: Bool
    let answer: (ScenarioReview) -> Void
    let toggleEditing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                if !isEditing {
                    Text("Is this what should happen?").font(TypographyTokens.standard.weight(.medium))
                    Button { answer(.approved) } label: { key("Right", "Y", symbol: "hand.thumbsup") }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.success, isOn: review == .approved))
                        .help("The checks and the text say what should happen. Moves to the next scenario.")
                    Button { answer(.flagged) } label: { key("Wrong", "N", symbol: "hand.thumbsdown") }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error, isOn: review == .flagged))
                        .help("The expectation needs a change. Say why in the note.")
                    if review != .imported {
                        Button("Clear", systemImage: "arrow.uturn.backward") { answer(.imported) }
                            .labelStyle(.iconOnly).buttonStyle(.borderless).help("Back to not reviewed")
                    }
                }
                Spacer()
                Button(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil", action: toggleEditing)
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: isEditing))
                    .keyboardShortcut("e", modifiers: .command)
                    .help(isEditing ? "Back to reviewing (⌘E)" : "Change the scenario: SQL, settings and expectation (⌘E)")
            }
            if review == .flagged && !isEditing {
                TextField("", text: $note, prompt: Text("What should happen instead, for the agent"), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...3)
            }
        }
        .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func key(_ title: String, _ key: String, symbol: String) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: symbol)
            Text(title)
            Text(key).font(TypographyTokens.label.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }
}
