import SwiftUI

/// Notification Center-style list in the inspector sidebar.
struct NotificationInspectorView: View {
    let notificationEngine: NotificationEngine?

    private var notifications: [QueryExecutionMessage] {
        (notificationEngine?.notificationMessages ?? []).reversed()
    }

    private var todayNotifications: [QueryExecutionMessage] {
        notifications.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var earlierNotifications: [QueryExecutionMessage] {
        notifications.filter { !Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        if notifications.isEmpty {
            emptyState
        } else {
            notificationList
        }
    }

    // MARK: - List

    private var notificationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !todayNotifications.isEmpty {
                    sectionHeader("Today", showClear: true)
                    ForEach(todayNotifications) { notification in
                        NotificationCard(notification: notification)
                    }
                }

                if !earlierNotifications.isEmpty {
                    sectionHeader("Earlier", showClear: false)
                        .padding(.top, todayNotifications.isEmpty ? 0 : SpacingTokens.xs)
                    ForEach(earlierNotifications) { notification in
                        NotificationCard(notification: notification)
                    }
                }
            }
            .padding(.horizontal, InspectorLayout.horizontalPadding)
            .padding(.vertical, SpacingTokens.xs)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, showClear: Bool) -> some View {
        HStack {
            Text(title)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Spacer()
            if showClear {
                Button("Clear All") {
                    notificationEngine?.clearNotifications()
                }
                .font(TypographyTokens.detail)
                .buttonStyle(.borderless)
                .foregroundStyle(ColorTokens.accent)
            }
        }
        .padding(.vertical, SpacingTokens.xs2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "bell.slash")
                .font(TypographyTokens.iconMedium)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Notifications")
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Activity notifications will appear here.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.lg)
    }
}

// MARK: - Notification Card

private struct NotificationCard: View {
    let notification: QueryExecutionMessage

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            Image(systemName: notification.severity.systemImage)
                .font(TypographyTokens.standard)
                .foregroundStyle(notification.severity.tint)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                HStack {
                    Text(notification.category)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                    Spacer()
                    Text(relativeTime(notification.timestamp))
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }

                Text(notification.message)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(SpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ColorTokens.Background.secondary)
        )
        .padding(.vertical, SpacingTokens.xxs2)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
