import SwiftUI

/// One event as a compact card (round 17, D): icon, headline and time on one line, bold while
/// new. Opened, it fades in the server, the rest of the message (selectable) and small buttons.
struct NotificationHistoryCard: View {
    let record: NotificationRecord
    let isNew: Bool
    let isOpen: Bool
    let onToggle: () -> Void

    @Environment(EnvironmentState.self) private var environmentState

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: record.category.defaultIcon)
                    .foregroundStyle(record.severity.color)
                Text(record.headline)
                    .font(TypographyTokens.standard.weight(isNew ? .semibold : .regular))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                Spacer(minLength: SpacingTokens.xs)
                Text(record.date, format: .relative(presentation: .named))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen {
                opened
                    .padding(.leading, SpacingTokens.lg)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(
            ColorTokens.Workspace.groupFill,
            in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
    }

    private var opened: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if let server = record.context?.serverName {
                Text(server)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            if let detail = record.detail {
                Text(detail)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: SpacingTokens.xs) {
                if let action = record.context?.action, environmentState.canPerform(action, context: record.context) {
                    Button(action.title) { environmentState.perform(action, context: record.context) }
                }
                if environmentState.canReveal(record.context) {
                    Button(record.context?.tabID != nil ? "Open Tab" : "Show Server") {
                        environmentState.reveal(record.context)
                    }
                }
                Button("Copy") { copyToGeneralPasteboard(record.message) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

extension NotificationRecord.Severity {
    var color: Color {
        switch self {
        case .success: ColorTokens.Status.success
        case .info: ColorTokens.Text.secondary
        case .warning: ColorTokens.Status.warning
        case .error: ColorTokens.Status.error
        }
    }
}
