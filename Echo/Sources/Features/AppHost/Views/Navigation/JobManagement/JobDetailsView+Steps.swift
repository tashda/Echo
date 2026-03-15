import SwiftUI

extension JobDetailsView {

    // MARK: - Steps Tab

    var isAddStepDisabled: Bool {
        newStepName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || newStepCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var stepsTab: some View {
        VSplitView {
            List {
                ForEach(viewModel.steps) { step in
                    stepListRow(step)
                        .contextMenu {
                            Button("Open Command in Editor") {
                                openCommandEditor(text: step.command ?? "", stepName: step.name)
                            }
                            Divider()
                            Button("Delete Step", role: .destructive) {
                                Task { await viewModel.deleteStep(stepName: step.name) }
                            }
                        }
                }
                .onMove(perform: moveSteps)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, minHeight: 40)

            ScrollView {
                addStepForm
            }
            .frame(minHeight: 40)
        }
    }

    func stepListRow(_ step: JobQueueViewModel.StepRow) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("\(step.id)")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .monospacedDigit()
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(step.name)
                        .font(TypographyTokens.standard)

                    Text(step.subsystem)
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, 1)
                        .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())

                    if let db = step.database, !db.isEmpty {
                        Text(db)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }

                if let cmd = step.command, !cmd.isEmpty {
                    Text(cmd.prefix(80).description)
                        .font(TypographyTokens.detail.monospaced())
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if step.command != nil {
                Button {
                    openCommandEditor(text: step.command ?? "", stepName: step.name)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.secondary)
                .help("Open in editor")
            }
        }
    }

    func moveSteps(from source: IndexSet, to destination: Int) {
        Task {
            await viewModel.reorderSteps(from: source, to: destination)
        }
    }

    func openCommandEditor(text: String, stepName: String? = nil) {
        commandEditorContext = CommandEditorContext(stepName: stepName, initialText: text)
    }

    var addStepForm: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Add Step")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.sm)

            HStack(spacing: SpacingTokens.sm) {
                TextField("Step Name", text: $newStepName)
                Picker("Type", selection: $newStepSubsystem) {
                    Text("T-SQL").tag("TSQL")
                    Text("CmdExec").tag("CmdExec")
                    Text("PowerShell").tag("PowerShell")
                }
                .fixedSize()
                if newStepSubsystem == "TSQL" {
                    Picker("Database", selection: $newStepDatabase) {
                        Text("Default").tag("")
                        ForEach(viewModel.databaseNames, id: \.self) { db in
                            Text(db).tag(db)
                        }
                    }
                    .frame(maxWidth: 160)
                }
            }
            .padding(.horizontal, SpacingTokens.md)

            HStack(spacing: SpacingTokens.xs) {
                TextField("Command", text: $newStepCommand, axis: .vertical)
                    .lineLimit(1...3)
                    .font(TypographyTokens.body.monospaced())
                Button {
                    openCommandEditor(text: newStepCommand, stepName: nil)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Open in full editor")
            }
            .padding(.horizontal, SpacingTokens.md)

            HStack {
                Spacer()
                Button("Add Step") {
                    let name = newStepName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let command = newStepCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !command.isEmpty else { return }
                    Task {
                        await viewModel.addStep(
                            name: name,
                            subsystem: newStepSubsystem,
                            database: newStepDatabase.isEmpty ? nil : newStepDatabase,
                            command: command
                        )
                        newStepName = ""
                        newStepDatabase = ""
                        newStepCommand = ""
                    }
                }
                .disabled(isAddStepDisabled)
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.bottom, SpacingTokens.sm)
        }
    }
}
