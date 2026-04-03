import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    var accountsSection: some View {
        Section("Accounts") {
            ForEach(viewModel.accounts) { account in
                accountRow(account)
            }
        }
    }

    private func accountRow(_ account: SQLServerMailAccount) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(account.name)
                .font(TypographyTokens.standard.weight(.medium))
            if let email = account.emailAddress, !email.isEmpty {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "at")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(email)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let server = account.serverName {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "server.rack")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    let port = account.serverPort.map { ":\($0)" } ?? ""
                    Text("\(server)\(port)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    if account.enableSSL {
                        Image(systemName: "lock.fill")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.Status.success)
                            .help("SSL enabled")
                    }
                }
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
        .contextMenu {
            Button("Edit") { viewModel.editingAccount = account }
                .disabled(!canConfigure)
            Divider()
            Button("Delete", role: .destructive) { viewModel.confirmDeleteAccount = account }
                .disabled(!canConfigure)
        }
    }
}
