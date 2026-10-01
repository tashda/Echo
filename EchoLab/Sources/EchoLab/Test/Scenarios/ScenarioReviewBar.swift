import EchoSenseScenarios
import SwiftUI

/// The bar under a scenario. Reviewing: the owner's answer to "is this what should happen?" (Right,
/// Y; Wrong, N) and what happens next because of it; Wrong puts the cursor in the feedback thread.
/// Editing: Cancel and Save, since the editor works on a draft.
struct ScenarioReviewBar: View {
    let review: ScenarioReview
    let outcome: ScenarioOutcome
    /// Whether the thread has (or is getting) a message, so Wrong can ask for one.
    let hasFeedback: Bool
    let isEditing: Bool
    let hasUnsavedChanges: Bool
    let answer: (ScenarioReview) -> Void
    let edit: () -> Void
    let save: () -> Void
    let cancel: () -> Void

    @State private var showsHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if isEditing { editingRow } else { reviewRow; nextStep }
        }
        .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var reviewRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text("Is this what should happen?").font(TypographyTokens.standard.weight(.medium))
            Button("How to answer", systemImage: "questionmark.circle") { showsHelp.toggle() }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
                .popover(isPresented: $showsHelp, arrowEdge: .top) { ScenarioReviewHelp() }
            Button { answer(.approved) } label: { key("Right", "Y", symbol: "hand.thumbsup") }
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.success, isOn: review == .approved))
                .help("The checks and the text say what should happen, even if EchoSense doesn't do it yet. Moves to the next scenario.")
            Button { answer(.flagged) } label: { key("Wrong", "N", symbol: "hand.thumbsdown") }
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.Status.error, isOn: review == .flagged))
                .help("The checks or the text are not what should happen. Say why in the feedback below.")
            if review != .imported {
                Button("Not reviewed", systemImage: "arrow.uturn.backward") { answer(.imported) }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).help("Undo your answer")
            }
            Spacer()
            Button("Edit", systemImage: "pencil", action: edit)
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
                .keyboardShortcut("e", modifiers: .command)
                .help("Change the scenario yourself: SQL, settings and checks. Nothing is saved until you press Save (⌘E)")
        }
    }

    /// What your answer leads to, given what EchoSense does.
    private var nextStep: some View {
        let (text, symbol): (String, String) = switch (review, outcome) {
        case (.imported, _): ("Y if the checks say what should happen, even when they fail. N if they don't; the agent changes them.", "info.circle")
        case (.approved, .right): ("Done: this is right and EchoSense does it.", "checkmark.seal")
        case (.approved, .wrong): ("Next: the agent fixes EchoSense so it does this.", "wrench.and.screwdriver")
        case (.approved, _): ("Next: the agent writes the checks from what should happen.", "pencil.and.list.clipboard")
        case (.flagged, _): (hasFeedback ? "Next: the agent changes the scenario from your feedback." : "Write feedback below so the agent knows what to change.", "arrow.turn.up.right")
        }
        return Label(text, systemImage: symbol).font(TypographyTokens.detail)
            .foregroundStyle(review == .flagged && !hasFeedback ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
    }

    private var editingRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            Label(hasUnsavedChanges ? "Editing. Not saved yet." : "Editing. No changes yet.", systemImage: "pencil")
                .font(TypographyTokens.standard).foregroundStyle(hasUnsavedChanges ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
            Spacer()
            Button("Cancel", action: cancel).buttonStyle(LabPillButtonStyle()).keyboardShortcut(.cancelAction)
            Button("Save", systemImage: "checkmark", action: save)
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
                .keyboardShortcut("s", modifiers: .command)
        }
    }

    private func key(_ title: String, _ key: String, symbol: String) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: symbol)
            Text(title)
            Text(key).font(TypographyTokens.label.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }
}

/// The two questions on the page and what each answer leads to.
private struct ScenarioReviewHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Two questions, two answerers").font(TypographyTokens.headline)
            Text("Red or green is the engine's answer to “does EchoSense do it?”. Right or Wrong is yours, to “is this what should happen?”. Judge the checks and the text, not the colour.")
                .font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: SpacingTokens.sm, verticalSpacing: SpacingTokens.xxs) {
                line("xmark.circle.fill", ColorTokens.Status.error, "Red, you say Right", "the agent fixes EchoSense")
                line("xmark.circle.fill", ColorTokens.Status.error, "Red, you say Wrong", "the agent changes the scenario from your note")
                line("checkmark.circle.fill", ColorTokens.Status.success, "Green, you say Right", "done")
                line("checkmark.circle.fill", ColorTokens.Status.success, "Green, you say Wrong", "the agent changes the scenario, then EchoSense")
            }
            Text("Y and N work from the list; ↑ and ↓ move. The tags (dialect, schema, ...) try other settings without saving.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.md).frame(width: 420)
    }

    private func line(_ symbol: String, _ tint: Color, _ when: String, _ then: String) -> some View {
        GridRow {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(when).font(TypographyTokens.standard.weight(.medium))
            Text(then).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
