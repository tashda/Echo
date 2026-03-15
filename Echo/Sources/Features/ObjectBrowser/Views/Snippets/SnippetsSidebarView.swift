import SwiftUI
import EchoSense

struct SnippetsSidebarView: View {
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(TabStore.self) private var tabStore

    private var activeSession: ConnectionSession? {
        environmentState.sessionGroup.activeSession
    }

    private var dialect: SQLDialect? {
        guard let dbType = activeSession?.connection.databaseType else { return nil }
        switch dbType {
        case .postgresql: return .postgresql
        case .mysql: return .mysql
        case .sqlite: return .sqlite
        case .microsoftSQL: return .microsoftSQL
        }
    }

    private var snippetsByGroup: [(group: SQLSnippet.Group, snippets: [SQLSnippet])] {
        guard let dialect else { return [] }
        let all = SQLSnippetCatalog.snippets(for: dialect)
        let grouped = Dictionary(grouping: all, by: \.group)
        return SQLSnippet.Group.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group, items.sorted { $0.priority > $1.priority })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.sm)

            Divider()
                .opacity(dialect == nil ? 0 : 1)
                .padding(.vertical, dialect == nil ? 0 : SpacingTokens.xs)

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if dialect == nil {
            EmptyStatePlaceholder(
                icon: "curlybraces",
                title: "No Active Connection",
                subtitle: "Connect to a database to browse SQL snippets."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(SpacingTokens.xl)
        } else if snippetsByGroup.isEmpty {
            EmptyStatePlaceholder(
                icon: "curlybraces",
                title: "No Snippets",
                subtitle: "No snippets available for this dialect."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(SpacingTokens.xl)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.md) {
                    ForEach(snippetsByGroup, id: \.group) { section in
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            Text(section.group.displayName)
                                .font(TypographyTokens.caption)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .padding(.horizontal, SpacingTokens.sm)

                            LazyVStack(spacing: SpacingTokens.xxs) {
                                ForEach(section.snippets, id: \.id) { snippet in
                                    SnippetRow(snippet: snippet, onInsert: { insert(snippet) })
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.top, SpacingTokens.xxs)
                }
                .padding(.bottom, SpacingTokens.lg)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Snippets")
                .font(TypographyTokens.headline)

            Text(headerSubtitle)
                .font(TypographyTokens.footnote)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(2)
        }
    }

    private var headerSubtitle: String {
        guard let dialect else { return "Connect to a database to browse snippets" }
        switch dialect {
        case .postgresql: return "PostgreSQL snippets"
        case .mysql: return "MySQL snippets"
        case .sqlite: return "SQLite snippets"
        case .microsoftSQL: return "SQL Server snippets"
        }
    }

    private func insert(_ snippet: SQLSnippet) {
        if let query = tabStore.activeTab?.query {
            if query.sql.isEmpty {
                query.sql = snippet.insertText
            } else {
                query.sql += "\n" + snippet.insertText
            }
        } else {
            environmentState.openQueryTab(presetQuery: snippet.insertText)
        }
    }
}

// MARK: - Snippet Row

private struct SnippetRow: View {
    let snippet: SQLSnippet
    let onInsert: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onInsert) {
            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: 16, alignment: .center)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    Text(snippet.title)
                        .font(TypographyTokens.body)
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    if let detail = snippet.detail {
                        Text(detail)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xs2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? ColorTokens.Text.primary.opacity(0.06) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Insert snippet")
    }
}

// MARK: - Group Display Names

extension SQLSnippet.Group {
    var displayName: String {
        switch self {
        case .select: return "Select & Expressions"
        case .filter: return "Filtering"
        case .join: return "Joins"
        case .modification: return "Data Modification"
        case .json: return "JSON"
        case .general: return "General"
        }
    }
}
