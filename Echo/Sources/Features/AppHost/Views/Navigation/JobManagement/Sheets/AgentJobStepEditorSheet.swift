import SwiftUI

/// Shared sheet for creating or editing an Agent Job step.
/// Used by both the "New Job" modal and the "Details" pane.
///
/// Supports two save modes:
/// - `onSave`: synchronous (for New Job modal where parent manages state)
/// - `onSaveAsync`: async with error return (for Details pane where server is called)
struct AgentJobStepEditorSheet: View {
    @State var name: String
    @State var subsystem: String
    @State var database: String
    @State var command: String
    let databaseNames: [String]
    let title: String
    let actionLabel: String
    private let syncSave: ((String, String, String?, String) -> Void)?
    private let asyncSave: ((String, String, String?, String) async -> String?)?
    let onCancel: () -> Void

    @State private var showCommandEditor = false
    @State private var errorMessage: String?
    @State private var nameHasError = false
    @State private var isSaving = false

    init(
        name: String = "",
        subsystem: String = "TSQL",
        database: String = "",
        command: String = "",
        databaseNames: [String],
        title: String = "New Step",
        actionLabel: String = "Add Step",
        onSave: @escaping (String, String, String?, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._name = State(initialValue: name)
        self._subsystem = State(initialValue: subsystem)
        self._database = State(initialValue: database)
        self._command = State(initialValue: command)
        self.databaseNames = databaseNames
        self.title = title
        self.actionLabel = actionLabel
        self.syncSave = onSave
        self.asyncSave = nil
        self.onCancel = onCancel
    }

    init(
        name: String = "",
        subsystem: String = "TSQL",
        database: String = "",
        command: String = "",
        databaseNames: [String],
        title: String = "New Step",
        actionLabel: String = "Add Step",
        onSaveAsync: @escaping (String, String, String?, String) async -> String?,
        onCancel: @escaping () -> Void
    ) {
        self._name = State(initialValue: name)
        self._subsystem = State(initialValue: subsystem)
        self._database = State(initialValue: database)
        self._command = State(initialValue: command)
        self.databaseNames = databaseNames
        self.title = title
        self.actionLabel = actionLabel
        self.syncSave = nil
        self.asyncSave = onSaveAsync
        self.onCancel = onCancel
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSaving
    }

    var body: some View {
        SheetLayoutCustomFooter(title: title) {
            Form {
                Section(title) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        TextField("Name", text: $name, prompt: Text("e.g. Run cleanup query"))
                            .overlay(alignment: .trailing) {
                                if nameHasError {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(ColorTokens.Status.error)
                                        .padding(.trailing, SpacingTokens.xxs)
                                }
                            }
                            .onChange(of: name) { _, _ in
                                nameHasError = false
                                errorMessage = nil
                            }
                        if nameHasError, let errorMessage {
                            Text(errorMessage)
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.Status.error)
                        }
                    }

                    Picker("Type", selection: $subsystem) {
                        Text("T-SQL").tag("TSQL")
                        Text("CmdExec").tag("CmdExec")
                        Text("PowerShell").tag("PowerShell")
                    }
                    if subsystem == "TSQL" {
                        Picker("Database", selection: $database) {
                            Text("Default").tag("")
                            ForEach(databaseNames, id: \.self) { db in
                                Text(db).tag(db)
                            }
                        }
                    }

                    LabeledContent("Command") {
                        HStack(alignment: .top) {
                            TextEditor(text: $command)
                                .font(TypographyTokens.body.monospaced())
                                .frame(minHeight: 80, maxHeight: 160)
                                .scrollContentBackground(.hidden)
                                .padding(SpacingTokens.xxs)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(ColorTokens.Background.primary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(ColorTokens.Text.quaternary.opacity(0.4), lineWidth: 0.5)
                                )
                            Button {
                                showCommandEditor = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .help("Open in full editor")
                            .accessibilityLabel("Open in full editor")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
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

            if isValid {
                Button(actionLabel) {
                    performSave()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
            } else {
                Button(actionLabel) {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 480, minHeight: 340)
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

    private func performSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let db: String? = database.isEmpty ? nil : database

        if let syncSave {
            syncSave(trimmedName, subsystem, db, trimmedCommand)
        } else if let asyncSave {
            isSaving = true
            Task {
                let error = await asyncSave(trimmedName, subsystem, db, trimmedCommand)
                isSaving = false
                if let error {
                    let isNameErr = error.localizedLowercase.contains("step_name") || error.localizedLowercase.contains("already exists")
                    nameHasError = isNameErr
                    errorMessage = error
                }
            }
        }
    }
}
