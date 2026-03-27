import SwiftUI

struct MySQLRestoreSidebarSheet: View {
    @Bindable var viewModel: MySQLBackupRestoreViewModel
    let customToolPath: String?
    let onDismiss: () -> Void

    var body: some View {
        SheetLayoutCustomFooter(title: "Restore Database") {
            Form {
                Section("Source") {
                    TextField("", text: $viewModel.inputPath, prompt: Text("/path/to/backup.sql"))
                    Button("Choose File…") { viewModel.selectRestoreFile() }
                }

                Section("Options") {
                    Toggle("Continue On Error", isOn: $viewModel.forceRestore)
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
                    .disabled(viewModel.isRestoreRunning)
                Spacer()
                Button("Restore") {
                    Task { await viewModel.executeRestore(customToolPath: customToolPath) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canRestore)
            }
        }
        .frame(minWidth: 560, minHeight: 380)
        .interactiveDismissDisabled(viewModel.isRestoreRunning)
    }

    @ViewBuilder
    private var outputContent: some View {
        switch viewModel.restorePhase {
        case .idle:
            Text("Ready to restore SQL script into \(viewModel.databaseName).")
                .foregroundStyle(ColorTokens.Text.secondary)
        case .running:
            ProgressView("Running mysql…")
        case .completed(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
        }

        if !viewModel.restoreOutput.isEmpty {
            ForEach(Array(viewModel.restoreOutput.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(TypographyTokens.Table.sql)
                    .textSelection(.enabled)
            }
        }
    }
}
