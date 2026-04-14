import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    @ViewBuilder
    var pageContent: some View {
        switch selectedPage {
        case .profiles: profilesSection
        case .accounts: accountsSection
        case .security: securitySection
        case .settings: settingsSection
        case .status: statusSection
        case .queue: queueSection
        case nil: EmptyView()
        }
    }

    // MARK: - Feature Disabled

    var featureDisabledView: some View {
        VStack(spacing: SpacingTokens.md) {
            Spacer()
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(TypographyTokens.iconLarge)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Database Mail is not enabled")
                .font(TypographyTokens.prominent.weight(.medium))
            Text("Database Mail XPs must be enabled on the server before you can configure mail.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if canConfigure && !viewModel.isSaving {
                Button("Enable Database Mail") {
                    Task { await viewModel.enableFeature(session: session) }
                }
                .buttonStyle(.bordered)
            } else if canConfigure {
                Button("Enable Database Mail") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
            } else {
                Text("Contact your server administrator to enable Database Mail.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    func mailStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "sent": ColorTokens.Status.success
        case "failed": ColorTokens.Status.error
        case "unsent", "retrying": ColorTokens.Status.warning
        default: ColorTokens.Text.tertiary
        }
    }
}
