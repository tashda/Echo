import SwiftUI

/// A single row in the execution console, showing severity, category, timestamp, delta, and message.
struct ConsoleMessageRow: View {
    let message: QueryExecutionMessage

    private static let categoryWidth: CGFloat = 120
    private static let timestampWidth: CGFloat = 68
    private static let deltaWidth: CGFloat = 72

    var body: some View {
        HStack(spacing: 0) {
            // Severity icon
            Image(systemName: message.severity.systemImage)
                .font(TypographyTokens.detail)
                .foregroundStyle(message.severity.tint)
                .frame(width: 20, alignment: .center)

            // Category
            Text(message.category)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
                .frame(width: Self.categoryWidth, alignment: .leading)
                .padding(.leading, SpacingTokens.xs)

            // Timestamp
            Text(message.formattedTimestamp)
                .font(TypographyTokens.detail.monospaced())
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: Self.timestampWidth, alignment: .leading)
                .padding(.leading, SpacingTokens.xs)

            // Delta
            Text(message.delta > 0 ? "+" + EchoFormatters.duration(message.delta) : "")
                .font(TypographyTokens.detail.monospaced())
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: Self.deltaWidth, alignment: .leading)
                .padding(.leading, SpacingTokens.xxs)

            // Message (fills remaining space)
            Text(message.message)
                .font(TypographyTokens.detail)
                .foregroundStyle(messageTextColor)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, SpacingTokens.xs)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    // MARK: - Styling

    private var messageTextColor: Color {
        switch message.severity {
        case .error: ColorTokens.Status.error
        case .warning: .orange
        case .info, .success, .debug: ColorTokens.Text.primary
        }
    }

    private var rowBackground: Color {
        switch message.severity {
        case .error: ColorTokens.Status.error.opacity(0.06)
        case .warning: ColorTokens.Status.warning.opacity(0.04)
        default: .clear
        }
    }
}
