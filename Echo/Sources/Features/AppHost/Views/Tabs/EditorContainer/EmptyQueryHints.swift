import SwiftUI
import EchoSense

/// QE6 (design board, 2026-09-30): an empty query tab shows faint starting points in the
/// editor itself, gone as soon as there is text. Snippets insert exactly as the Snippets
/// sidebar does.
struct EmptyQueryHints: View {
    let databaseType: EchoSenseDatabaseType?
    let onInsert: (String) -> Void

    private var snippets: [SQLSnippet] {
        guard let databaseType, let dialect = SQLDialect(rawValue: databaseType.rawValue) else { return [] }
        return Array(SQLSnippetCatalog.snippets(for: dialect).sorted { $0.priority < $1.priority }.prefix(LayoutTokens.EmptyQueryHints.snippetCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Start typing, or begin with a snippet")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .allowsHitTesting(false)
            if !snippets.isEmpty {
                HStack(spacing: SpacingTokens.xxs2) {
                    ForEach(snippets, id: \.id) { snippet in
                        Button(snippet.title) { onInsert(snippet.insertText) }
                            .buttonStyle(.plain)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xs)
                            .padding(.vertical, SpacingTokens.xxxs)
                            .background(ColorTokens.Surface.hover, in: .capsule)
                            .help(snippet.detail ?? snippet.title)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension LayoutTokens {
    enum EmptyQueryHints {
        static let snippetCount = 4
        /// Past the line-number gutter, so the hint lines up with the code.
        static let leadingInset: CGFloat = 52
        static let topInset: CGFloat = SpacingTokens.xl
    }
}
