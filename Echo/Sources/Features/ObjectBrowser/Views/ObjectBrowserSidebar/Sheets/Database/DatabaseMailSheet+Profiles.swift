import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    var profilesPage: some View {
        VStack(spacing: 0) {
            profileList
            Divider()
            profileToolbar
        }
    }

    private var profileList: some View {
        Group {
            if profiles.isEmpty {
                mailEmptyState("No Database Mail profiles configured.", icon: "person.crop.rectangle.stack")
            } else {
                List {
                    ForEach(profiles) { profile in
                        profileRow(profile)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
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

            let linked = profileAccounts.filter { $0.profileID == profile.profileID }
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
                                Task { await unlinkAccount(profileID: pa.profileID, accountID: pa.accountID) }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(ColorTokens.Status.error)
                            }
                            .buttonStyle(.plain)
                            .help("Remove account from profile")
                        }
                    }
                }
                .padding(.top, SpacingTokens.xxxs)
            }

            if !accounts.isEmpty {
                let unlinkedAccounts = accounts.filter { account in
                    !linked.contains { $0.accountID == account.accountID }
                }
                if !unlinkedAccounts.isEmpty {
                    Menu {
                        ForEach(unlinkedAccounts) { account in
                            Button(account.name) {
                                let nextSeq = (linked.map(\.sequenceNumber).max() ?? 0) + 1
                                Task {
                                    await linkAccount(
                                        profileID: profile.profileID,
                                        accountID: account.accountID,
                                        sequence: nextSeq
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
            Button("Edit\u{2026}") { editingProfile = profile }
            Divider()
            Button("Delete", role: .destructive) { confirmDeleteProfile = profile }
        }
    }

    private var profileToolbar: some View {
        HStack {
            Button {
                showAddProfile = true
            } label: {
                Label("Add Profile", systemImage: "plus")
            }
            .controlSize(.small)
            Spacer()
        }
        .padding(SpacingTokens.sm)
    }
}
