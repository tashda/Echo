import SwiftUI

struct ObjectBrowserPendingConnectionRow: View {
    let pending: PendingConnection
    let displayName: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: SidebarRowConstants.iconTextSpacing) {
            Text(displayName)
                .font(SidebarRowConstants.sectionHeaderFont)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)

            statusLabel
                .font(TypographyTokens.detail)
                .lineLimit(1)

            Spacer(minLength: SpacingTokens.xxs)

            trailingAccessory
        }
        .padding(.leading, SpacingTokens.xs + SpacingTokens.xxs)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding + SidebarRowConstants.rowOuterHorizontalPadding)
        .padding(.top, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(helpText)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch pending.phase {
        case .connecting:
            Text("Connecting…")
                .foregroundStyle(ColorTokens.Text.tertiary)
        case .failed:
            Text("Failed")
                .foregroundStyle(ColorTokens.Status.error)
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch pending.phase {
        case .connecting:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Connecting to \(displayName)")
        case .failed:
            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise")
                    .font(TypographyTokens.detail.weight(.semibold))
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
            .help("Retry connection")
            .accessibilityLabel("Retry connection to \(displayName)")
        }
    }

    private var helpText: String {
        switch pending.phase {
        case .connecting:
            "Connecting to \(displayName)"
        case .failed(let message):
            message
        }
    }
}
