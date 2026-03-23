import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    var accountsPage: some View {
        VStack(spacing: 0) {
            accountList
            Divider()
            accountToolbar
        }
    }

    private var accountList: some View {
        Group {
            if accounts.isEmpty {
                mailEmptyState("No Database Mail accounts configured.", icon: "envelope")
            } else {
                List(accounts) { account in
                    accountRow(account)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
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
            Button("Edit\u{2026}") { editingAccount = account }
            Divider()
            Button("Delete", role: .destructive) { confirmDeleteAccount = account }
        }
    }

    private var accountToolbar: some View {
        HStack {
            Button {
                showAddAccount = true
            } label: {
                Label("Add Account", systemImage: "plus")
            }
            .controlSize(.small)
            Spacer()
        }
        .padding(SpacingTokens.sm)
    }
}
