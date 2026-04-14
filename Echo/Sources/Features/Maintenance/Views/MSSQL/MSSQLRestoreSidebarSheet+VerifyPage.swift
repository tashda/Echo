import SwiftUI
import SQLServerKit

// MARK: - Verify Page

extension MSSQLRestoreSidebarSheet {
    var verifyPage: some View {
        Section {
            HStack {
                Spacer()
                Button("Verify Backup") {
                    Task { await viewModel.verify() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.restoreDiskPath.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isVerifying)
            }

            switch viewModel.verifyPhase {
            case .completed(let messages):
                if messages.isEmpty {
                    Label("Backup verified successfully.", systemImage: "checkmark.circle")
                        .foregroundStyle(ColorTokens.Status.success)
                        .font(TypographyTokens.monospaced)
                        .textSelection(.enabled)
                } else {
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                }
            case .failed(let message):
                Text(message)
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Status.error)
                    .textSelection(.enabled)
            case .running:
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Verifying\u{2026}")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            case .idle:
                EmptyView()
            }
        } header: {
            Text("Verify Backup")
        } footer: {
            Text("Checks the backup file integrity without restoring. Runs RESTORE VERIFYONLY.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
