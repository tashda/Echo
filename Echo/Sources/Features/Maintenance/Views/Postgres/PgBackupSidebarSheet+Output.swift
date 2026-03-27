import SwiftUI

// MARK: - Output & Footer

extension PgBackupSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if !viewModel.backupStderrOutput.isEmpty || viewModel.backupPhase != .idle {
            Section("Output") {
                if !viewModel.backupStderrOutput.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.backupStderrOutput.enumerated()), id: \.offset) { _, line in
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
                case .completed(let messages):
                    if messages.isEmpty {
                        Label("Backup completed successfully.", systemImage: "checkmark.circle")
                            .foregroundStyle(ColorTokens.Status.success)
                            .font(TypographyTokens.monospaced)
                            .textSelection(.enabled)
                    }
                case .failed(let message):
                    Text(message)
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Status.error)
                        .textSelection(.enabled)
                default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    var footerContent: some View {
        if viewModel.isBackupRunning {
            ProgressView()
                .controlSize(.small)
            Text("Backing up\u{2026}")
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
        if viewModel.isBackupRunning {
            Button("Cancel") { viewModel.cancelBackup() }
                .buttonStyle(.bordered)
        }
        Button("Close") { onDismiss() }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isBackupRunning)
        if viewModel.canBackup {
            Button("Back Up") {
                Task { await viewModel.executeBackup(customToolPath: customToolPath) }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        } else {
            Button("Back Up") {}
                .buttonStyle(.bordered)
                .disabled(true)
                .keyboardShortcut(.defaultAction)
        }
    }
}
