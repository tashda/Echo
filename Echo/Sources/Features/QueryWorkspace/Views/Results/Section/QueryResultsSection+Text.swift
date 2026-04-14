import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var textResultsView: some View {
        formattedResultsView(
            content: QueryResultTextFormatter.formatTable(resultSet: currentResultSetForTextDisplay)
        )
    }

    var verticalResultsView: some View {
        formattedResultsView(
            content: QueryResultTextFormatter.formatVertical(resultSet: currentResultSetForTextDisplay)
        )
    }

    private var currentResultSetForTextDisplay: QueryResultSet {
        currentResultSet ?? QueryResultSet(columns: query.displayedColumns, rows: exportedPrimaryRows)
    }

    private func formattedResultsView(content: String) -> some View {
        VStack(spacing: 0) {
            resultsToolbar
            Divider()
            ScrollView([.horizontal, .vertical]) {
                Text(verbatim: content)
                    .font(TypographyTokens.detail.monospaced())
                    .foregroundStyle(ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SpacingTokens.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ColorTokens.Background.primary)
        }
    }
}
#endif
