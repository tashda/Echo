import SwiftUI
import EchoSense

/// QE6 (design board, 2026-09-30): an empty query tab shows faint starting points in the
/// editor itself, gone as soon as there is text: the tables opened most recently on this
/// connection and database, then snippets. A table inserts a query for its first rows;
/// snippets insert exactly as the Snippets sidebar does.
struct EmptyQueryHints: View {
    /// A recent table and the query it starts.
    struct TableStart: Identifiable, Equatable {
        let table: RecentTable
        let sql: String

        var id: String { table.id }
    }

    let databaseType: EchoSenseDatabaseType?
    var tableStarts: [TableStart] = []
    let onInsert: (String) -> Void

    private var snippets: [SQLSnippet] {
        guard let databaseType, let dialect = SQLDialect(rawValue: databaseType.rawValue) else { return [] }
        return Array(SQLSnippetCatalog.snippets(for: dialect).sorted { $0.priority < $1.priority }.prefix(LayoutTokens.EmptyQueryHints.snippetCount))
    }

    static func prompt(hasTables: Bool) -> String {
        hasTables ? "Start typing, or begin with a recent table or a snippet" : "Start typing, or begin with a snippet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(Self.prompt(hasTables: !tableStarts.isEmpty))
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .allowsHitTesting(false)
            if !tableStarts.isEmpty {
                HStack(spacing: SpacingTokens.xxs2) {
                    ForEach(tableStarts) { start in
                        chip(help: "\(start.table.schema).\(start.table.name): insert a query for its first rows") {
                            onInsert(start.sql)
                        } label: {
                            Label(start.table.name, systemImage: "tablecells")
                        }
                    }
                }
            }
            if !snippets.isEmpty {
                HStack(spacing: SpacingTokens.xxs2) {
                    ForEach(snippets, id: \.id) { snippet in
                        chip(help: snippet.detail ?? snippet.title) {
                            onInsert(snippet.insertText)
                        } label: {
                            Text(snippet.title)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func chip<Label: View>(help: String, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action, label: label)
            .buttonStyle(.plain)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.Surface.hover, in: .capsule)
            .help(help)
    }
}

extension LayoutTokens {
    enum EmptyQueryHints {
        static let snippetCount = 4
        static let recentTableCount = 4
        /// Past the line-number gutter, so the hint lines up with the code.
        static let leadingInset: CGFloat = 52
        static let topInset: CGFloat = SpacingTokens.xl
    }
}
