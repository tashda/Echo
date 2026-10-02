import SwiftUI

/// The tab's one line (design board, 2026-09-30; round 49): room for its kind's icon, then the
/// title. The icon itself is drawn on the strip's still layer (`TabIconLayer`, MO9), so it never
/// moves with the tab; a running tab's spinner is on that layer too. The database and running
/// time are in the tooltip. A tool tab with pages shows them after its title (ST2).
extension QueryTabButton {
    /// Everything in a tab besides its title: padding, close button, icon room, and the close
    /// button's place on the right.
    static var fixedChrome: CGFloat {
        SpacingTokens.xs + SpacingTokens.sm2 + SpacingTokens.xxxs + SpacingTokens.sm2 + SpacingTokens.xxs2
            + SpacingTokens.xxxs + SpacingTokens.sm2 + SpacingTokens.sm
    }

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
                // The icon's room; the icon is on the strip's layer above. A tab with no home
                // shows its ☆ here while the pointer is on it (round IC).
                Color.clear.frame(width: SpacingTokens.sm2, height: SpacingTokens.sm2)
                    .overlay { if showsSaveStar { saveStar } }
                    .accessibilityHidden(!showsSaveStar)

                titleText

                if hasToolPages {
                    // The pages fade with the tab (MO9); the tab's width clips them as it narrows.
                    TabPageChips(pages: tab.toolPages, selected: tab.currentToolPage) { tab.selectToolPage($0) }
                        .opacity(isActive ? 1 : 0)
                        .animation(motion.pageFade, value: isActive)
                        .allowsHitTesting(isActive)
                }
            }
            .help(tabTooltip)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(runningSince == nil ? displayedTitle : "\(displayedTitle), running")
        }
    }

    /// A tab with pages keeps its title whole; any other tab's title is laid out at the width the
    /// tab is moving to, at once, so it truncates there and never re-flows on the way, and sits
    /// centred with its icon.
    @ViewBuilder
    private var titleText: some View {
        let text = Text(displayedTitle)
            .font(isActive && hasToolPages ? TypographyTokens.detail.weight(.medium) : tabTitleFont)
            .lineLimit(1)
            .foregroundStyle(tabTitleColor)
        if hasToolPages || finalWidth <= 0 {
            text.fixedSize()
        } else {
            text
                .frame(width: max(finalWidth - Self.fixedChrome - centringLead, 0), alignment: .leading)
                .transaction { $0.animation = nil }
        }
    }

    /// A tool tab shows its pages after its title while they fit the strip (ST2, FP4).
    var hasToolPages: Bool { !tab.isPinned && pagesInTab && !tab.toolPages.isEmpty }

    /// Title, database, and when a running query started.
    var tabTooltip: String {
        // Which server: the dot is gone (round 49, SD2), so the tooltip says it.
        var parts = [displayedTitle, tab.connection.connectionName]
        if let database = tab.tabSubtitle ?? tab.activeDatabaseName, !database.isEmpty { parts.append(database) }
        if let home = tab.homeTooltip { parts.append(home) }
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
