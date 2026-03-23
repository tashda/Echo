import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    var securityPage: some View {
        VStack(spacing: 0) {
            securityList
            Divider()
            securityToolbar
        }
    }

    private var securityList: some View {
        Group {
            if principalProfiles.isEmpty {
                mailEmptyState("No profile access grants configured.", icon: "lock.shield")
            } else {
                List(principalProfiles) { pp in
                    securityRow(pp)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func securityRow(_ pp: SQLServerMailPrincipalProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "person.fill")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(pp.principalName ?? "public")
                        .font(TypographyTokens.standard.weight(.medium))
                }
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(pp.profileName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Spacer()

            if pp.isDefault {
                Text("Default")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.accent)
                    .padding(.horizontal, SpacingTokens.xxs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.accent.opacity(0.12))
                    )
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
        .contextMenu {
            Button("Revoke Access", role: .destructive) {
                Task {
                    await revokeAccess(
                        profileID: pp.profileID,
                        principalName: pp.principalName ?? "public"
                    )
                }
            }
            .disabled(!canConfigure)
        }
    }

    private var securityToolbar: some View {
        HStack {
            Button {
                showGrantAccess = true
            } label: {
                Label("Grant Access", systemImage: "plus")
            }
            .controlSize(.small)
            .disabled(profiles.isEmpty || !canConfigure)
            .help(canConfigure ? "Grant a principal access to a profile" : "Requires sysadmin role")
            Spacer()
        }
        .padding(SpacingTokens.sm)
    }
}
