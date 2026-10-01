import SwiftUI

/// The command, full height at the left (NS4), in Echo's SQL editor with Parse for T-SQL (CE2).
struct AgentJobStepCommandEditor: View {
    @Binding var command: String
    let isTSQL: Bool
    @Binding var parseState: AgentJobStepEditorSheet.ParseState
    let onParse: () -> Void
    let onOpenInEditor: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
            editor
                .frame(minHeight: LayoutTokens.AgentJobs.stepCommandMinHeight, maxHeight: .infinity)
                .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs, style: .continuous))
                .clipShape(.rect(cornerRadius: SpacingTokens.xs, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                        .strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5)
                }
            HStack(spacing: SpacingTokens.xs) {
                if isTSQL { parseStatus }
                Spacer(minLength: SpacingTokens.xs)
                if isTSQL {
                    Button("Parse", action: onParse)
                        .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parseState == .parsing)
                        .help("Check the T-SQL without running it")
                }
                Button("Open in Editor", systemImage: "arrow.up.left.and.arrow.down.right", action: onOpenInEditor)
            }
            .controlSize(.small)
        }
        .padding(SpacingTokens.md)
        .onChange(of: command) { _, _ in
            if parseState != .idle { parseState = .idle }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if isTSQL {
            SQLEditorView(
                text: $command,
                theme: editorTheme,
                display: appState.sqlEditorDisplay,
                onTextChange: { command = $0 },
                onSelectionChange: { _ in },
                onSelectionPreviewChange: { _ in },
                errorMark: parseState.errorMark(in: command)
            )
        } else {
            TextEditor(text: $command)
                .font(TypographyTokens.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(SpacingTokens.xs)
        }
    }

    @ViewBuilder
    private var parseStatus: some View {
        switch parseState {
        case .idle:
            EmptyView()
        case .parsing:
            ProgressView().controlSize(.mini)
            Text("Parsing").foregroundStyle(ColorTokens.Text.secondary)
        case .parsed:
            Label("No errors", systemImage: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
        case .issue(let line, let message):
            Label("Line \(line): \(message)", systemImage: "xmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
                .lineLimit(2)
                .help(message)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Status.warning)
                .lineLimit(1)
                .help(message)
        }
    }

    private var editorTheme: SQLEditorTheme {
        let tone: SQLEditorPalette.Tone = appearanceStore.effectiveColorScheme == .dark ? .dark : .light
        let resolved = appState.sqlEditorTheme
        if resolved.palette.tone == tone { return resolved }
        return SQLEditorThemeResolver.resolve(globalSettings: projectStore.globalSettings, project: projectStore.selectedProject, tone: tone)
    }
}

extension AgentJobStepEditorSheet {
    /// What Parse found (CE2).
    enum ParseState: Equatable {
        case idle
        case parsing
        case parsed
        case issue(line: Int, message: String)
        /// Parse itself failed (no connection, or not SQL Server).
        case failed(String)

        /// The failing line, marked in the editor as a failed query's is.
        func errorMark(in text: String) -> QueryErrorMark? {
            guard case .issue(let line, let message) = self,
                  let range = QueryErrorMarker.lineRange(line, in: text as NSString) else { return nil }
            return QueryErrorMark(range: range, line: line, message: message, detail: nil, fix: nil)
        }
    }

    var commandColumn: some View {
        AgentJobStepCommandEditor(
            command: $command,
            isTSQL: subsystem == "TSQL",
            parseState: $parseState,
            onParse: parse,
            onOpenInEditor: { showCommandEditor = true }
        )
    }
}
