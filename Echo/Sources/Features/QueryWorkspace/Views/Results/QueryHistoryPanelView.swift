import SwiftUI

/// Round 39: first SQL line, database · result · time, grouped by day; opening never runs SQL.
struct QueryHistoryPanelView: View {
    let connectionID: UUID?
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(ProjectStore.self) private var projectStore
    @State private var search = ""

    private var history: [QueryHistoryItem] {
        let projectID = projectStore.selectedProject?.id
        let ids = Set(connectionStore.connections.filter { $0.projectID == projectID }.map(\.id)
                      + environmentState.sessionGroup.sessions.filter { $0.connection.projectID == projectID }.map { $0.connection.id })
        return appState.queryHistory.filter { item in
            guard let id = item.connectionID, ids.contains(id), connectionID == nil || connectionID == id else { return false }
            return search.isEmpty || [item.query, item.databaseName ?? "", item.connectionName ?? "", item.outcome ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }
    private var days: [Date] {
        Set(history.map { Calendar.current.startOfDay(for: $0.timestamp) }).sorted(by: >)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack {
                Text("Query History").font(TypographyTokens.headline)
                Spacer()
                Text("\(history.count)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }.padding(SpacingTokens.sm)
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.tertiary)
                TextField("Search", text: $search, prompt: Text("SQL, server or database"))
                    .textFieldStyle(.plain)
            }.font(TypographyTokens.standard).padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
            if history.isEmpty {
                ContentUnavailableView(search.isEmpty ? "No Query History" : "No Matching Queries", systemImage: "clock",
                                       description: Text(search.isEmpty ? "Queries you run appear here. History settings are in Settings › Cache." : "Try another SQL phrase, server or database."))
            } else {
                List {
                    ForEach(days, id: \.self) { day in
                        Section(dayTitle(day)) {
                            ForEach(history.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: day) }) { item in
                                let connected = environmentState.sessionGroup.activeSessions.contains { $0.connection.id == item.connectionID }
                                Button {
                                    environmentState.openSavedQuery(sql: item.query, connectionID: item.connectionID, database: item.databaseName)
                                } label: {
                                    QueryHistoryRow(item: item)
                                }.buttonStyle(.plain).disabled(!connected)
                                    .help(connected ? item.query : "Connect to \(item.connectionName ?? "this server") to open this query.\n\(item.query)")
                                    .contextMenu {
                                        Button("Open in New Tab", systemImage: "arrow.up.right.square") {
                                            environmentState.openSavedQuery(sql: item.query, connectionID: item.connectionID, database: item.databaseName)
                                        }.disabled(!connected)
                                    }
                            }
                        }
                    }
                }.listStyle(.sidebar).scrollContentBackground(.hidden)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task { appState.pruneQueryHistory() }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct QueryHistoryRow: View {
    let item: QueryHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(item.query.split(whereSeparator: \.isNewline).first.map(String.init) ?? item.query)
                .font(TypographyTokens.Table.sql).lineLimit(1)
            Text([item.databaseName, item.outcome ?? item.resultCount.map { "\($0.formatted()) \($0 == 1 ? "row" : "rows")" } ?? "Completed", item.formattedDuration, item.formattedTimestamp]
                .compactMap { $0 }.joined(separator: " · "))
                .font(TypographyTokens.detail).foregroundStyle(item.outcome == "Failed" ? ColorTokens.Status.error : ColorTokens.Text.secondary)
                .lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, SpacingTokens.xxs)
            .contentShape(Rectangle())
    }
}
