import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    var queueSection: some View {
        Section("Mail Queue") {
            ForEach(viewModel.queueItems) { item in
                DisclosureGroup {
                    queueItemDetail(item)
                } label: {
                    queueRowLabel(item)
                }
            }
        }
    }

    private func queueRowLabel(_ item: SQLServerMailQueueItem) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Text(item.subject ?? "(No Subject)")
                    .font(TypographyTokens.standard.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let sentStatus = item.sentStatus {
                    statusBadge(sentStatus)
                }
            }
            if let recipients = item.recipients, !recipients.isEmpty {
                Text("To: \(recipients)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            if let date = item.sendRequestDate {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(date, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text("\(date, style: .relative) ago")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }

    private func queueItemDetail(_ item: SQLServerMailQueueItem) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if let cc = item.copyRecipients, !cc.isEmpty {
                PropertyRow(title: "Cc") {
                    Text(cc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let bcc = item.blindCopyRecipients, !bcc.isEmpty {
                PropertyRow(title: "Bcc") {
                    Text(bcc)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let importance = item.importance, !importance.isEmpty {
                PropertyRow(title: "Importance") {
                    Text(importance.capitalized)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let user = item.sendRequestUser, !user.isEmpty {
                PropertyRow(title: "Requested By") {
                    Text(user)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let sentDate = item.sentDate {
                PropertyRow(title: "Sent Date") {
                    VStack(alignment: .trailing, spacing: SpacingTokens.xxxs) {
                        HStack(spacing: SpacingTokens.xxs) {
                            Text(sentDate, style: .date)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                            Text(sentDate, style: .time)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                        Text("\(sentDate, style: .relative) ago")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            if let attachments = item.fileAttachments, !attachments.isEmpty {
                PropertyRow(title: "Attachments") {
                    Text(attachments)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(2)
                }
            }

            if let body = item.body, !body.isEmpty {
                Divider()
                Text("Message")
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text(body)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .lineLimit(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.xs)
                    .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: 6))
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(TypographyTokens.compact)
            .foregroundStyle(mailStatusColor(status))
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, 2)
            .background(
                mailStatusColor(status).opacity(0.12),
                in: .capsule
            )
    }
}
