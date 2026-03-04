import SwiftUI

extension TabOverviewView {
    var overviewHero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tab Overview")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(heroSubtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .center, spacing: 16) {
                    heroStat(icon: "rectangle.grid.2x2.fill", title: formattedCount(totalTabs), subtitle: "Open Tabs")
                    heroStat(icon: "bolt.fill", title: formattedCount(runningQueriesCount), subtitle: "Running")
                    heroStat(icon: "tablecells", title: formattedCount(totalRowCount), subtitle: "Rows Fetched")
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 32)

            heroUpdateChip
                .padding(.trailing, 32)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: heroShadowColor, radius: 18, y: 10)
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func heroStat(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(heroAccentColor)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(minWidth: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.06), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private var heroUpdateChip: some View {
        if let last = latestActivityDate {
            heroChip(text: "Updated " + relativeDateString(from: last), icon: "clock.arrow.circlepath", tint: .secondary)
        } else {
            heroChip(text: "No activity yet", icon: "clock.arrow.circlepath", tint: Color.secondary.opacity(0.6))
        }
    }

    private func heroChip(text: String, icon: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.08))
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
        "\(formattedCount(totalTabs)) open tabs across \(formattedCount(activeConnectionCount)) connection\(activeConnectionCount == 1 ? "" : "s")"
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

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
