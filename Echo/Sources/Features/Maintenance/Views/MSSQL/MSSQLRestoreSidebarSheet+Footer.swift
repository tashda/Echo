import SwiftUI
import SQLServerKit

// MARK: - Output & Footer

extension MSSQLRestoreSidebarSheet {
    @ViewBuilder
    var outputSection: some View {
        if viewModel.restorePhase != .idle {
            Section("Output") {
                switch viewModel.restorePhase {
                case .completed(let messages):
                    ForEach(messages, id: \.self) { msg in
                        Text(msg)
                            .font(TypographyTokens.monospaced)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .textSelection(.enabled)
                    }
                    if messages.isEmpty {
                        Label("Restore completed successfully.", systemImage: "checkmark.circle")
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

    @ViewBuilder
    var footerContent: some View {
        if viewModel.isRestoreRunning {
            ProgressView()
                .controlSize(.small)
            Text("Restoring\u{2026}")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
        } else if case .completed = viewModel.restorePhase {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.success)
            Text("Completed")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Status.success)
        } else if case .failed = viewModel.restorePhase {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(ColorTokens.Status.error)
            Text("Failed")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Status.error)
        }
        Spacer()
        if viewModel.isRestoreRunning {
            Button("Cancel") { viewModel.cancelRestore() }
                .buttonStyle(.bordered)
        }
        Button("Close") { onDismiss() }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isRestoreRunning)
        if viewModel.canRestore {
            Button("Restore") {
                Task { await viewModel.executeRestore() }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        } else {
            Button("Restore") {}
                .buttonStyle(.bordered)
                .disabled(true)
                .keyboardShortcut(.defaultAction)
        }
    }
}
