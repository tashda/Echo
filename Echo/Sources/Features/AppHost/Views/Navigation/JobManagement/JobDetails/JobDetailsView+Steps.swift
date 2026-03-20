import SwiftUI

extension JobDetailsView {

    // MARK: - Steps Tab

    var stepsTab: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.steps) { step in
                    stepListRow(step)
                        .contextMenu {
                            Button {
                                editingStep = step
                            } label: {
                                Label("Edit Step", systemImage: "pencil")
                            }

                            if step.command != nil {
                                Button {
                                    openCommandEditor(text: step.command ?? "", stepName: step.name)
                                } label: {
                                    Label("Open Command in Editor", systemImage: "arrow.up.right.square")
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                pendingDeleteStepName = step.name
                                showDeleteStepAlert = true
                            } label: {
                                Label("Delete Step", systemImage: "trash")
                            }
                        }
                }
                .onMove(perform: moveSteps)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if viewModel.steps.isEmpty {
                    Text("No steps defined.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    showAddStepSheet = true
                } label: {
                    Label("New Step", systemImage: "plus")
                }
                .controlSize(.small)
                .padding(SpacingTokens.xs)
            }
        }
        .sheet(isPresented: $showAddStepSheet) {
            AgentJobStepEditorSheet(
                databaseNames: viewModel.databaseNames,
                title: "New Step",
                actionLabel: "Add Step",
                onSaveAsync: { name, subsystem, database, command in
                    let beforeError = viewModel.errorMessage
                    await viewModel.addStep(name: name, subsystem: subsystem, database: database, command: command)
                    if viewModel.errorMessage == nil || viewModel.errorMessage == beforeError {
                        showAddStepSheet = false
                        return nil
                    }
                    let err = viewModel.errorMessage
                    viewModel.errorMessage = nil
                    return err
                },
                onCancel: { showAddStepSheet = false }
            )
        }
        .alert("Delete Step?", isPresented: $showDeleteStepAlert) {
            Button("Cancel", role: .cancel) { pendingDeleteStepName = nil }
            Button("Delete", role: .destructive) {
                guard let name = pendingDeleteStepName else { return }
                pendingDeleteStepName = nil
                Task { await viewModel.deleteStep(stepName: name) }
            }
        } message: {
            if let name = pendingDeleteStepName {
                Text("Are you sure you want to delete step \"\(name)\"? This action cannot be undone.")
            }
        }
        .sheet(item: $editingStep) { step in
            AgentJobStepEditorSheet(
                name: step.name,
                subsystem: step.subsystem,
                database: step.database ?? "",
                command: step.command ?? "",
                databaseNames: viewModel.databaseNames,
                title: "Edit Step",
                actionLabel: "Save",
                onSaveAsync: { _, _, database, command in
                    let beforeError = viewModel.errorMessage
                    await viewModel.updateStep(stepName: step.name, newCommand: command, database: database)
                    if viewModel.errorMessage == nil || viewModel.errorMessage == beforeError {
                        editingStep = nil
                        return nil
                    }
                    let err = viewModel.errorMessage
                    viewModel.errorMessage = nil
                    return err
                },
                onCancel: { editingStep = nil }
            )
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
}
