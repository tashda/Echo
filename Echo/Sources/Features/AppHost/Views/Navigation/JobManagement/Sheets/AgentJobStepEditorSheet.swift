import SwiftUI
import SQLServerKit

/// New Step and Edit Step for an Agent job (round 33.2): the command full height at the left in
/// Echo's SQL editor with Parse (NS4, CE2), the settings in a sidebar at the right with what the
/// step does when it finishes (OC1), on one surface with a prominent default button (SE1, PB1).
/// Editing a step shows how it last ran under the title (ES1).
struct AgentJobStepEditorSheet: View {
    /// What the sheet saves.
    struct Draft: Equatable {
        var name: String
        var subsystem: String
        var database: String?
        var command: String
        var proxyName: String?
        var outputFile: String?
        var outcome: AgentJobStepOutcome
    }

    @State var name: String
    @State var subsystem: String
    @State var database: String
    @State var command: String
    @State var proxyName: String
    @State var outputFile: String
    @State var outcome: AgentJobStepOutcome
    let jobName: String?
    /// The job's other steps (id → name), for "Go to step" on success or failure.
    let otherSteps: [Int: String]
    /// Edit Step: "Last run 26 Sep 23:00 · Succeeded · 14 min".
    let lastRunLine: String?
    let isEditing: Bool
    let databaseNames: [String]
    let proxyNames: [String]
    let onParse: (String) async throws -> SQLServerParseIssue?
    let onSave: (Draft) async -> String?
    let onCancel: () -> Void

    @State var showCommandEditor = false
    @State var errorMessage: String?
    @State var nameHasError = false
    @State var isSaving = false
    @State var parseState: ParseState = .idle

    init(step: JobQueueViewModel.StepRow? = nil, jobName: String?, otherSteps: [Int: String], lastRunLine: String? = nil,
         databaseNames: [String], proxyNames: [String] = [],
         onParse: @escaping (String) async throws -> SQLServerParseIssue?,
         onSave: @escaping (Draft) async -> String?, onCancel: @escaping () -> Void) {
        self._name = State(initialValue: step?.name ?? "")
        self._subsystem = State(initialValue: step?.subsystem ?? "TSQL")
        self._database = State(initialValue: step?.database ?? "")
        self._command = State(initialValue: step?.command ?? "")
        self._proxyName = State(initialValue: "")
        self._outputFile = State(initialValue: "")
        self._outcome = State(initialValue: step?.outcome ?? AgentJobStepOutcome())
        self.jobName = jobName
        self.otherSteps = otherSteps
        self.lastRunLine = lastRunLine
        self.isEditing = step != nil
        self.databaseNames = databaseNames
        self.proxyNames = proxyNames
        self.onParse = onParse
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var title: String {
        let base = isEditing ? "Edit Step" : "New Step"
        return jobName.map { "\(base) · \($0)" } ?? base
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    var body: some View {
        SheetLayoutCustomFooter(title: title) {
            VStack(spacing: SpacingTokens.none) {
                header
                HStack(spacing: SpacingTokens.none) {
                    commandColumn
                    sidebar
                }
            }
        } footer: {
            footer
        }
        .frame(minWidth: LayoutTokens.AgentJobs.stepSheetMinWidth, minHeight: LayoutTokens.AgentJobs.stepSheetMinHeight)
        .sheet(isPresented: $showCommandEditor) {
            CommandEditorView(
                context: CommandEditorContext(stepName: nil, initialText: command),
                onSaveToStep: { _, _ in },
                onUseCommand: { text in
                    command = text
                    showCommandEditor = false
                },
                onCancel: { showCommandEditor = false }
            )
        }
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.xxxs) {
            Text(title)
                .font(TypographyTokens.headline)
                .lineLimit(1)
            if let lastRunLine {
                Text(lastRunLine)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sm)
        .padding(.horizontal, SpacingTokens.md)
    }

    @ViewBuilder
    private var footer: some View {
        if let errorMessage, !nameHasError {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Status.warning)
            Text(errorMessage)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(2)
        }
        Spacer()
        if isSaving {
            ProgressView()
                .controlSize(.small)
        }
        Button("Cancel", role: .cancel, action: onCancel)
            .keyboardShortcut(.cancelAction)
        SheetLayout.primaryButton(isEditing ? "Save" : "Add Step", canSubmit: canSave) { save() }
    }
}
