import SwiftUI

struct ConnectionDashboardQuickActions: View {
    @ObservedObject var session: ConnectionSession
    let onNewQuery: () -> Void
    let onOpenJobQueue: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Quick Actions")
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .textCase(.uppercase)
                .padding(.leading, SpacingTokens.xxs)

            VStack(spacing: SpacingTokens.xxs) {
                DashboardQuickActionRow(
                    icon: "plus.square",
                    title: "New Query",
                    subtitle: "Open a blank SQL editor",
                    action: onNewQuery
                )

                if session.connection.databaseType == .microsoftSQL,
                   let onOpenJobQueue {
                    DashboardQuickActionRow(
                        icon: "clock.badge.checkmark",
                        title: "SQL Agent Jobs",
                        subtitle: "View scheduled jobs and execution history",
                        action: onOpenJobQueue
                    )
                }

                if session.connection.databaseType == .postgresql {
                    if let onOpenJobQueue {
                        DashboardQuickActionRow(
                            icon: "clock.badge.checkmark",
                            title: "Job Queue",
                            subtitle: "Monitor background jobs",
                            action: onOpenJobQueue
                        )
                    }
                }
            }
        }
    }
}

private struct DashboardQuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.accent)
                    .frame(width: 28, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(TypographyTokens.standard.weight(.medium))
                        .foregroundStyle(ColorTokens.Text.primary)

                    Text(subtitle)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.label.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.quaternary)
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xs)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered
                        ? ColorTokens.Text.primary.opacity(0.05)
                        : ColorTokens.Text.primary.opacity(0.02))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
