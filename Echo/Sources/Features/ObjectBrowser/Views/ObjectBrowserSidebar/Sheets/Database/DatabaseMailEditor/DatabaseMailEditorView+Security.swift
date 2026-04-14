import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    var securitySection: some View {
        Section("Profile Access") {
            ForEach(viewModel.principalProfiles) { pp in
                securityRow(pp)
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
                    await viewModel.revokeAccess(
                        profileID: pp.profileID,
                        principalName: pp.principalName ?? "public",
                        session: session
                    )
                }
            }
            .disabled(!canConfigure)
        }
    }
}
