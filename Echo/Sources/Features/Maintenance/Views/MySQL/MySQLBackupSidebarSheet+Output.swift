import SwiftUI

extension MySQLBackupSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if !viewModel.backupOutput.isEmpty || viewModel.backupPhase != .idle {
            Section("Output") {
                if !viewModel.backupOutput.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.backupOutput.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(TypographyTokens.monospaced)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }

                switch viewModel.backupPhase {
                case .completed(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Status.success)
                        .font(TypographyTokens.formDescription)
                case .failed(let message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.Status.error)
                        .font(TypographyTokens.formDescription)
                case .running:
                    ProgressView("Running mysqldump…")
                case .idle:
                    Text("Ready to run mysqldump.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var footerContent: some View {
        if viewModel.isBackupRunning {
            ProgressView()
                .controlSize(.small)
            Text("Backing up…")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        } else if case .completed = viewModel.backupPhase {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
            Text("Completed")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Status.success)
        } else if case .failed = viewModel.backupPhase {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
            Text("Failed")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Status.error)
        }

        Spacer()

        Button("Close") { onDismiss() }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isBackupRunning)

        Button("Back Up") {
            Task { await viewModel.executeConfiguredBackup(customToolPath: customToolPath) }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!viewModel.canBackup)
    }
}
