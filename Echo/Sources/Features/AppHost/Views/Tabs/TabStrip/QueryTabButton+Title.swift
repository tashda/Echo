import SwiftUI

/// The tab's title, its database subtitle, and the running state (plan B2).
extension QueryTabButton {
    @ViewBuilder
    var tabTitleContent: some View {
        if tab.isPinned {
            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
        } else if let runningSince {
            // A running query (plan B2): a spinner at the leading edge, and the timer in place
            // of the subtitle. The timer text updates itself, so the tab doesn't re-render.
            HStack(spacing: SpacingTokens.xxxs) {
                ProgressView()
                    .controlSize(.mini)
                Text(displayedTitle)
                    .font(tabTitleFont)
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor)
                Text(runningSince, style: .timer)
                    .font(TypographyTokens.detail.weight(.medium).monospacedDigit())
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor.opacity(0.55))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(displayedTitle), running")
        } else if let dbName = tab.tabSubtitle ?? tab.activeDatabaseName, !dbName.isEmpty {
            HStack(spacing: SpacingTokens.xxxs) {
                Text(displayedTitle)
                    .font(tabTitleFont)
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor)

                Text(dbName)
                    .font(TypographyTokens.detail.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor.opacity(0.55))
            }
        } else {
            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
        }
    }

    /// When the tab's query started, while it's running.
    var runningSince: Date? {
        guard let query = tab.query, query.isExecuting else { return nil }
        return query.executionStartTime ?? Date()
    }

    var displayedTitle: String {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if tab.isPinned {
            if let first = trimmed.first {
                return String(first).uppercased()
            }
            return "•"
        }
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
