import SwiftUI

extension TabOverviewView {
    var overviewHero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    Text("Tab Overview")
                        .font(TypographyTokens.hero.weight(.bold))
                    Text(heroSubtitle)
                        .font(TypographyTokens.prominent.weight(.regular))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                HStack(alignment: .center, spacing: SpacingTokens.md) {
                    heroStat(icon: "rectangle.grid.2x2.fill", title: EchoFormatters.compactNumber(totalTabs), subtitle: "Open Tabs")
                    heroStat(icon: "bolt.fill", title: EchoFormatters.compactNumber(runningQueriesCount), subtitle: "Running")
                    heroStat(icon: "tablecells", title: EchoFormatters.compactNumber(totalRowCount), subtitle: "Rows Fetched")
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, SpacingTokens.lg2)
            .padding(.horizontal, SpacingTokens.xl)

            heroUpdateChip
                .padding(.trailing, SpacingTokens.xl)
                .padding(.bottom, SpacingTokens.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: heroShadowColor, radius: 18, y: 10)
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.top, SpacingTokens.lg)
    }

    private func heroStat(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Image(systemName: icon)
                .font(TypographyTokens.prominent.weight(.semibold))
                .foregroundStyle(heroAccentColor)
            Text(title)
                .font(TypographyTokens.hero.weight(.semibold))
            Text(subtitle)
                .font(TypographyTokens.caption2.weight(.medium))
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.vertical, SpacingTokens.md)
        .padding(.horizontal, SpacingTokens.md2)
        .frame(minWidth: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTokens.Text.primary.opacity(colorScheme == .dark ? 0.15 : 0.06), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private var heroUpdateChip: some View {
        if let last = latestActivityDate {
            heroChip(text: "Updated " + EchoFormatters.relativeDate(last), icon: "clock.arrow.circlepath", tint: ColorTokens.Text.secondary)
        } else {
            heroChip(text: "No activity yet", icon: "clock.arrow.circlepath", tint: ColorTokens.Text.secondary.opacity(0.6))
        }
    }

    private func heroChip(text: String, icon: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(TypographyTokens.caption2.weight(.semibold))
        } icon: {
            Image(systemName: icon)
                .font(TypographyTokens.caption2.weight(.semibold))
        }
        .padding(.horizontal, SpacingTokens.sm2)
        .padding(.vertical, SpacingTokens.xs)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(colorScheme == .dark ? 0.18 : 0.08))
        )
        .foregroundStyle(tint)
    }

    private var heroBackground: LinearGradient {
        LinearGradient(
            colors: [
                heroAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.16),
                heroAccentColor.opacity(colorScheme == .dark ? 0.08 : 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12)
    }

    private var heroSubtitle: String {
        "\(EchoFormatters.compactNumber(totalTabs)) open tabs across \(EchoFormatters.compactNumber(activeConnectionCount)) connection\(activeConnectionCount == 1 ? "" : "s")"
    }

    private var totalTabs: Int { tabs.count }

    private var activeConnectionCount: Int {
        Set(tabs.map { $0.connection.id }).count
    }

    private var runningQueriesCount: Int {
        tabs.filter { $0.query?.isExecuting == true }.count
    }

    private var totalRowCount: Int {
        tabs.reduce(0) { $0 + ($1.query?.rowProgress.displayCount ?? 0) }
    }

    private var latestActivityDate: Date? {
        tabs.compactMap { latestExecutionDate(for: $0) }.max()
    }

    private func latestExecutionDate(for tab: WorkspaceTab) -> Date? {
        if let message = tab.query?.messages.last(where: { $0.severity != .debug }) {
            return message.timestamp
        }
        if let diagram = tab.diagram {
            switch diagram.loadSource {
            case .live(let date): return date
            case .cache(let date): return date
            }
        }
        return nil
    }

}
