import SwiftUI

// MARK: - Output Section & Footer

extension MSSQLBackupSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if viewModel.backupPhase != .idle {
            Section("Output") {
                switch viewModel.backupPhase {
                case .completed(let messages):
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    if messages.isEmpty {
                        Label("Backup completed successfully.", systemImage: "checkmark.circle")
                            .foregroundStyle(ColorTokens.Status.success)
                            .font(TypographyTokens.monospaced)
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

    var footerBar: some View {
        HStack {
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
            Button("Back Up") {
                Task { await viewModel.executeBackup() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canBackup)
        }
        .padding(SpacingTokens.md)
    }
}
