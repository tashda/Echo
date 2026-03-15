import SwiftUI
import SQLServerKit

extension DatabaseMailSheet {

    var profilesPage: some View {
        Group {
            if profiles.isEmpty {
                mailEmptyState("No Database Mail profiles configured.")
            } else {
                List(profiles) { profile in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(profile.name)
                            .font(TypographyTokens.standard.weight(.medium))
                        if let desc = profile.description, !desc.isEmpty {
                            Text(desc)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                    .padding(.vertical, SpacingTokens.xxs)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    var accountsPage: some View {
        Group {
            if accounts.isEmpty {
                mailEmptyState("No Database Mail accounts configured.")
            } else {
                List(accounts) { account in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                        Text(account.name)
                            .font(TypographyTokens.standard.weight(.medium))
                        if let email = account.emailAddress, !email.isEmpty {
                            Text(email)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                        if let server = account.serverName {
                            let port = account.serverPort.map { ":\($0)" } ?? ""
                            Text("Server: \(server)\(port)")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                    .padding(.vertical, SpacingTokens.xxs)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    var queuePage: some View {
        Group {
            if queueItems.isEmpty {
                mailEmptyState("No items in the mail queue.")
            } else {
                List(queueItems) { item in
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
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    func mailEmptyState(_ message: String) -> some View {
        VStack {
            Spacer()
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
