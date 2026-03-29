import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    var queuePage: some View {
        Group {
            if queueItems.isEmpty {
                mailEmptyState("No items in the mail queue.", icon: "tray")
            } else {
                List(queueItems) { item in
                    queueRow(item)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func queueRow(_ item: SQLServerMailQueueItem) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Text(item.subject ?? "(No Subject)")
                    .font(TypographyTokens.standard.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let sentStatus = item.sentStatus {
                    Text(sentStatus)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(mailStatusColor(sentStatus))
                        .padding(.horizontal, SpacingTokens.xxs)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(mailStatusColor(sentStatus).opacity(0.12))
                        )
                }
            }
            if let recipients = item.recipients, !recipients.isEmpty {
                Text("To: \(recipients)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            if let date = item.sendRequestDate {
                Text("Sent: \(date, style: .relative) ago")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }

    func mailEmptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: SpacingTokens.sm) {
            Spacer()
            Image(systemName: icon)
                .font(TypographyTokens.iconMedium)
                .foregroundStyle(ColorTokens.Text.quaternary)
            Text(message)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Spacer()
        }
    }

    func mailStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "sent": ColorTokens.Status.success
        case "failed": ColorTokens.Status.error
        case "unsent", "retrying": ColorTokens.Status.warning
        default: ColorTokens.Text.tertiary
        }
    }
}
