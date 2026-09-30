import EchoSenseScenarios
import SwiftUI

/// The right column: one scenario to judge. Its settings as tags (try others without saving), what
/// should happen, the SQL with the popup under the caret, the checks, and the review bar. Edit (⌘E)
/// swaps in the full editor on a draft: nothing is written until Save.
struct ScenarioReviewPane: View {
    let id: String
    let store: ScenarioStore
    @Binding var isEditing: Bool
    let answer: (ScenarioReview) -> Void
    /// Done with this scenario (Return in the note): the page moves on.
    let next: () -> Void
    let select: (String) -> Void

    /// Settings being tried; nil while the pane shows the saved scenario.
    @State private var trial: CompletionScenario?
    @State private var trialResult: ScenarioResult?
    /// The scenario being edited; written to the files only by Save.
    @State private var draft: CompletionScenario?

    var body: some View {
        if let saved = store.library.scenario(id: id) {
            VStack(spacing: 0) {
                if isEditing, draft != nil {
                    ScenarioEditorView(scenario: Binding(get: { draft ?? saved }, set: { draft = $0 }))
                } else {
                    ScrollView { content(saved).padding(SpacingTokens.md).frame(maxWidth: 920, alignment: .leading).frame(maxWidth: .infinity) }
                }
                ScenarioReviewBar(
                    review: saved.review, outcome: store.outcome(for: id), note: note(saved),
                    isEditing: isEditing, hasUnsavedChanges: draft.map { $0 != saved } ?? false,
                    answer: answer, submitNote: next,
                    edit: { trial = nil; draft = saved; isEditing = true },
                    save: { if let draft { store.update(draft) }; draft = nil; isEditing = false },
                    cancel: { draft = nil; isEditing = false })
            }
            .onChange(of: trial) { _, new in trialResult = new.map { CompletionScenarioRunner().run($0) } }
            .onAppear { if isEditing { draft = saved } }
            .onChange(of: isEditing) { _, editing in draft = editing ? (draft ?? store.library.scenario(id: id)) : nil }
        } else {
            LabMailEmpty(title: "Select a scenario", symbol: "checklist")
        }
    }

    private func content(_ saved: CompletionScenario) -> some View {
        let shown = trial ?? saved
        let result = trial == nil ? store.result(for: id) : trialResult
        return VStack(alignment: .leading, spacing: SpacingTokens.md) {
            header(shown, result: result)
            ScenarioContextTags(saved: saved, shown: Binding(get: { trial ?? saved }, set: { trial = $0 == saved ? nil : $0 }))
            if trial != nil { trialBanner(saved) }
            if !shown.should.isEmpty {
                LabReadingCard(title: "What should happen", symbol: "text.alignleft") {
                    Text(ScenarioChecksCard.markdown(shown.should)).font(TypographyTokens.standard).textSelection(.enabled)
                }
            }
            ScenarioPopupPreview(scenario: shown, actual: result?.actual)
            ScenarioChecksCard(result: result, useActual: trial == nil ? { useActual(saved) } : nil)
            footnotes(shown)
        }
    }

    private func header(_ scenario: CompletionScenario, result: ScenarioResult?) -> some View {
        let outcome = ScenarioOutcome(result)
        let checks = result?.checks ?? []
        let verdict: String = switch outcome {
        case .right: scenario.knownIssue == nil ? "Does what it should" : "Does what it should, but it's still listed as a known issue"
        case .wrong: checks.isEmpty ? "Wrong" : "\(checks.count { !$0.passed }) of \(checks.count) checks fail"
        case .noExpectation, .couldNotRun: outcome.title
        }
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack(spacing: SpacingTokens.xxs2) {
                LabTag(text: scenario.id)
                Text(scenario.group).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                if let source = scenario.source { LabTag(text: source, symbol: "doc.text") }
            }
            Text(scenario.title).font(TypographyTokens.title2.weight(.bold)).textSelection(.enabled)
            HStack(spacing: SpacingTokens.xs) {
                Label(verdict, systemImage: outcome.symbol).foregroundStyle(outcome.tint).font(TypographyTokens.prominent.weight(.medium))
                if scenario.knownIssue != nil { LabTag(text: "Known issue", symbol: "exclamationmark.triangle") }
            }
        }
    }

    private func trialBanner(_ saved: CompletionScenario) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "flask").foregroundStyle(ColorTokens.accent)
            Text("Trying other settings. Nothing is saved.").font(TypographyTokens.standard)
            Spacer()
            Button("Reset") { trial = nil }.buttonStyle(LabPillButtonStyle())
            Button("Save as new scenario") { saveAsNew(saved) }.buttonStyle(LabPillButtonStyle())
            Button("Keep for this scenario") { if let trial { store.update(trial) }; trial = nil }
                .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true))
        }
        .padding(SpacingTokens.xs)
        .background(ColorTokens.Surface.selected, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.Surface.selectedBorder, lineWidth: 0.5))
    }

    @ViewBuilder
    private func footnotes(_ scenario: CompletionScenario) -> some View {
        if let issue = scenario.knownIssue {
            Label("Known issue: \(issue)", systemImage: "exclamationmark.triangle")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning).textSelection(.enabled)
        }
        if let notes = scenario.notes, scenario.review != .flagged {
            Label(notes, systemImage: "note.text").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).textSelection(.enabled)
        }
    }

    // MARK: Actions

    private func note(_ saved: CompletionScenario) -> Binding<String> {
        Binding(get: { store.library.scenario(id: id)?.notes ?? "" }, set: { new in
            guard var scenario = store.library.scenario(id: id) else { return }
            scenario.notes = new.isEmpty ? nil : new
            store.update(scenario)
        })
    }

    private func useActual(_ saved: CompletionScenario) {
        guard let actual = store.result(for: id)?.actual else { return }
        var scenario = saved
        scenario.echoSense = saved.expectation(matching: actual)
        store.update(scenario)
    }

    private func saveAsNew(_ saved: CompletionScenario) {
        guard var copy = trial else { return }
        copy.id = store.nextID(prefix: "MINE")
        copy.title = "\(saved.title) (\(copy.dialect != saved.dialect ? copy.dialect.title : "variant"))"
        copy.review = .imported
        copy.knownIssue = nil
        store.update(copy)
        trial = nil
        select(copy.id)
    }
}
