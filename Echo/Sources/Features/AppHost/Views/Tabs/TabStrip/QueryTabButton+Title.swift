import SwiftUI

/// The tab's one line (design board, 2026-09-30): its kind's icon, or a spinner while it runs,
/// then the title. The database and running time are in the tooltip. An active tool tab with
/// pages unfolds them after its title (ST2).
extension QueryTabButton {
    @ViewBuilder
    var tabTitleContent: some View {
        if tab.isPinned {
            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
                .help(tabTooltip)
        } else {
            HStack(spacing: SpacingTokens.xxs2) {
                Group {
                    if runningSince != nil {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: tab.kind.icon)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(tabTitleColor.opacity(isActive ? 0.8 : 0.7))
                    }
                }
                .frame(width: SpacingTokens.sm2)
                .accessibilityHidden(true)

                Text(displayedTitle)
                    .font(tabTitleFont)
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor)
                    .layoutPriority(1)

                if isActive, !tab.toolPages.isEmpty {
                    TabPageChips(pages: tab.toolPages, selected: tab.currentToolPage) { tab.selectToolPage($0) }
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
            }
            .help(tabTooltip)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(runningSince == nil ? displayedTitle : "\(displayedTitle), running")
        }
    }

    /// Title, database, and when a running query started.
    var tabTooltip: String {
        var parts = [displayedTitle]
        if let database = tab.tabSubtitle ?? tab.activeDatabaseName, !database.isEmpty { parts.append(database) }
        if let runningSince {
            parts.append("Running since \(runningSince.formatted(date: .omitted, time: .standard))")
        }
        return parts.joined(separator: " · ")
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
