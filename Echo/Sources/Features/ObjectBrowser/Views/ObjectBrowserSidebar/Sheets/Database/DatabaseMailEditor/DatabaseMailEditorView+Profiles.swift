import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    var profilesSection: some View {
        Section("Profiles") {
            ForEach(viewModel.profiles) { profile in
                profileRow(profile)
            }
        }
    }

    private func profileRow(_ profile: SQLServerMailProfile) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(profile.name)
                .font(TypographyTokens.standard.weight(.medium))
            if let desc = profile.description, !desc.isEmpty {
                Text(desc)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            let linked = viewModel.profileAccounts.filter { $0.profileID == profile.profileID }
            if !linked.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    ForEach(linked) { pa in
                        HStack(spacing: SpacingTokens.xxs) {
                            Text("\(pa.sequenceNumber).")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                                .frame(width: 20, alignment: .trailing)
                            Image(systemName: "envelope")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                            Text(pa.accountName)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                            Spacer()
                            Button {
                                Task { await viewModel.unlinkAccount(profileID: pa.profileID, accountID: pa.accountID, session: session) }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(ColorTokens.Status.error)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canConfigure)
                            .help(canConfigure ? "Remove account from profile" : "Requires sysadmin role")
                        }
                    }
                }
                .padding(.top, SpacingTokens.xxxs)
            }

            if !viewModel.accounts.isEmpty {
                let unlinkedAccounts = viewModel.accounts.filter { account in
                    !linked.contains { $0.accountID == account.accountID }
                }
                if !unlinkedAccounts.isEmpty {
                    Menu {
                        ForEach(unlinkedAccounts) { account in
                            Button(account.name) {
                                let nextSeq = (linked.map(\.sequenceNumber).max() ?? 0) + 1
                                Task {
                                    await viewModel.linkAccount(
                                        profileID: profile.profileID,
                                        accountID: account.accountID,
                                        sequence: nextSeq,
                                        session: session
                                    )
                                }
                            }
                        }
                    } label: {
                        Label("Link Account", systemImage: "plus.circle")
                            .font(TypographyTokens.detail)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .foregroundStyle(ColorTokens.accent)
                    .padding(.top, SpacingTokens.xxxs)
                }
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
        .contextMenu {
            Button("Edit") { viewModel.editingProfile = profile }
                .disabled(!canConfigure)
            Divider()
            Button("Delete", role: .destructive) { viewModel.confirmDeleteProfile = profile }
                .disabled(!canConfigure)
        }
    }
}
