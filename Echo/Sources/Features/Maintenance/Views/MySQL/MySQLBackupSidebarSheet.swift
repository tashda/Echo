import SwiftUI

struct MySQLBackupSidebarSheet: View {
    @Bindable var viewModel: MySQLBackupRestoreViewModel
    let customToolPath: String?
    let onDismiss: () -> Void

    var body: some View {
        SheetLayoutCustomFooter(title: "Back Up Database") {
            Form {
                Section("Destination") {
                    TextField("", text: $viewModel.outputPath, prompt: Text("/path/to/backup.sql"))
                    Button("Choose File…") { viewModel.selectBackupFile() }
                }

                Section("Options") {
                    Toggle("Include Data", isOn: $viewModel.includeData)
                    Toggle("Include Routines", isOn: $viewModel.includeRoutines)
                    Toggle("Include Triggers", isOn: $viewModel.includeTriggers)
                    Toggle("Include Events", isOn: $viewModel.includeEvents)
                    Toggle("Single Transaction", isOn: $viewModel.singleTransaction)
                }

                Section("Output") {
                    outputContent
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        } footer: {
            HStack {
                Button("Cancel") { onDismiss() }
                    .disabled(viewModel.isBackupRunning)
                Spacer()
                Button("Back Up") {
                    Task { await viewModel.executeBackup(customToolPath: customToolPath) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canBackup)
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .interactiveDismissDisabled(viewModel.isBackupRunning)
    }

    @ViewBuilder
    private var outputContent: some View {
        switch viewModel.backupPhase {
        case .idle:
            Text("Ready to run mysqldump.")
                .foregroundStyle(ColorTokens.Text.secondary)
        case .running:
            ProgressView("Running mysqldump…")
        case .completed(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
        }

        if !viewModel.backupOutput.isEmpty {
            ForEach(Array(viewModel.backupOutput.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(TypographyTokens.Table.sql)
                    .textSelection(.enabled)
            }
        }
    }
}
