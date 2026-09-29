import SwiftUI

struct ConnectionDashboardRecentQueries: View {
    @Bindable var session: ConnectionSession
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    private var recentQueries: [QueryHistoryItem] {
        let connectionID = session.connection.id
        let filtered = appState.queryHistory.filter { $0.connectionID == connectionID }
        return Array(filtered.prefix(5))
    }

    var body: some View {
        if !recentQueries.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                DashboardSectionLabel(title: "Recent queries")

                DashboardCard {
                    ForEach(recentQueries) { item in
                        DashboardRecentQueryRow(item: item) {
                            environmentState.openQueryTab(
                                for: session,
                                presetQuery: item.query,
                                database: item.databaseName
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct DashboardRecentQueryRow: View {
    let item: QueryHistoryItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DashboardCardRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text(truncatedQuery)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    HStack(spacing: SpacingTokens.xs) {
                        Text(relativeTimestamp)
                        if let db = item.databaseName {
                            Text(db)
                        }
                        if let rows = item.resultCount {
                            Text("\(rows) row\(rows == 1 ? "" : "s")")
                        }
                        if let duration = item.formattedDuration {
                            Text(duration)
                        }
                    }
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                }

                Spacer(minLength: SpacingTokens.none)
            }
            .padding(.vertical, SpacingTokens.xxs)
        }
        .buttonStyle(.plain)
    }

    private var truncatedQuery: String {
        let firstLine = item.query
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? item.query
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.count > 80 {
            return String(trimmed.prefix(80)) + "…"
        }
        return trimmed
    }

    private var relativeTimestamp: String {
        let interval = Date().timeIntervalSince(item.timestamp)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return item.formattedTimestamp
    }
}
