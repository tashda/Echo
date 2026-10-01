import SwiftUI

/// The tab's one line (design board, 2026-09-30): its kind's icon, or a spinner while it runs,
/// then the title. The database and running time are in the tooltip. An active tool tab with
/// pages shows them after its title, past a short hairline (ST2, round 36.1).
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
                    .font(showsToolPages ? TypographyTokens.detail.weight(.medium) : tabTitleFont)
                    .lineLimit(1)
                    .foregroundStyle(tabTitleColor)
                    .layoutPriority(1)

                if let serverDotColor {
                    Circle()
                        .fill(serverDotColor)
                        .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                        .accessibilityHidden(true)
                }

                if showsToolPages {
                    // UF1: the pages fade out before the tab narrows, and in once it has widened.
                    TabPageChips(pages: tab.toolPages, selected: tab.currentToolPage) { tab.selectToolPage($0) }
                        .transition(.asymmetric(
                            insertion: .opacity.animation(motion.press.delay(motion.settleDuration * 0.4)),
                            removal: .opacity.animation(motion.press)))
                }
            }
            .help(tabTooltip)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(runningSince == nil ? displayedTitle : "\(displayedTitle), running")
        }
    }

    /// The active tool tab shows its pages after its title (ST2, round 36.1).
    var showsToolPages: Bool { isActive && !tab.isPinned && !tab.toolPages.isEmpty }

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
