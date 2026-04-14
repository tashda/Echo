import SwiftUI

struct QueryHistoryPanelView: View {
    let connectionID: UUID?

    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    @State private var searchText = ""
    @State private var selectedItemID: UUID?

    private var filteredHistory: [QueryHistoryItem] {
        let items: [QueryHistoryItem]
        if let connectionID {
            items = appState.queryHistory.filter { $0.connectionID == connectionID }
        } else {
            items = appState.queryHistory
        }

        guard !searchText.isEmpty else { return items }
        let query = searchText.lowercased()
        return items.filter { item in
            item.query.lowercased().contains(query)
            || (item.databaseName?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if filteredHistory.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.Text.tertiary)
                .font(TypographyTokens.caption2)
            TextField("Search history\u{2026}", text: $searchText)
                .textFieldStyle(.plain)
                .font(TypographyTokens.caption)
                .frame(maxWidth: 200)

            Spacer()

            Text("\(filteredHistory.count) queries")
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)

            Button {
                appState.clearQueryHistory()
            } label: {
                Label("Clear History", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(appState.queryHistory.isEmpty)
            .help("Clear all query history")
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28))
                .foregroundStyle(ColorTokens.Text.quaternary)
            Text(searchText.isEmpty ? "No query history" : "No matching queries")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        List(filteredHistory, selection: $selectedItemID) { item in
            QueryHistoryRow(item: item) {
                rerunQuery(item)
            }
            .contextMenu {
                Button("Re-run Query") { rerunQuery(item) }
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.query, forType: .string)
                }
                Divider()
                Button("Open in New Tab") {
                    environmentState.openQueryTab(presetQuery: item.query, database: item.databaseName)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func rerunQuery(_ item: QueryHistoryItem) {
        environmentState.openQueryTab(presetQuery: item.query, autoExecute: true, database: item.databaseName)
    }
}

// MARK: - Row View

private struct QueryHistoryRow: View {
    let item: QueryHistoryItem
    let onRerun: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(truncatedQuery)
                    .font(TypographyTokens.code)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(2)

                HStack(spacing: SpacingTokens.xs) {
                    Text(item.formattedTimestamp)
                    if let db = item.databaseName {
                        Text(db)
                            .padding(.horizontal, 4)
                            .background(ColorTokens.Background.secondary.opacity(0.5), in: Capsule())
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

            Spacer()

            if isHovered {
                Button {
                    onRerun()
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Re-run this query")
            }
        }
        .padding(.vertical, SpacingTokens.xxs2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var truncatedQuery: String {
        let firstLine = item.query
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? item.query
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "\u{2026}"
        }
        return trimmed
    }
}
