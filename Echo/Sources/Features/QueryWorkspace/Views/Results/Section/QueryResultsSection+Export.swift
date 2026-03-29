import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var resultsToolbar: some View {
        TabSectionToolbar(sectionPicker: {
            if query.allResultSetsForDisplay.count > 1 {
                resultSetTabBar(count: query.allResultSetsForDisplay.count)
            } else {
                Text(resultsSummaryText)
                    .font(TypographyTokens.formValue)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }) {
            resultDetailModePicker

            Button {
                presentExportSheet()
            } label: {
                Label("Export Results", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(currentResultSet == nil || query.isExecuting)
        }
    }

    var currentResultSet: QueryResultSet? {
        if query.selectedResultSetIndex == 0 {
            let rows = exportedPrimaryRows
            guard !query.displayedColumns.isEmpty || !rows.isEmpty else { return nil }
            return QueryResultSet(
                columns: query.displayedColumns,
                rows: rows,
                totalRowCount: rows.count,
                commandTag: query.results?.commandTag,
                dataClassification: query.dataClassification
            )
        }

        let additionalIndex = query.selectedResultSetIndex - 1
        guard query.additionalResults.indices.contains(additionalIndex) else { return nil }
        return query.additionalResults[additionalIndex]
    }

    var exportedPrimaryRows: [[String?]] {
        let sourceIndices = rowOrder.isEmpty ? Array(0..<query.displayedRowCount) : rowOrder
        return sourceIndices.compactMap { query.displayedRow(at: $0) }
    }

    var currentResultSetFileName: String {
        if query.allResultSetsForDisplay.count <= 1 {
            return "query-results"
        }
        return "query-results-\(query.selectedResultSetIndex + 1)"
    }

    var resultsSummaryText: String {
        let count = query.selectedResultSetIndex == 0 ? exportedPrimaryRows.count : (currentResultSet?.rows.count ?? 0)
        let rowLabel = count == 1 ? "row" : "rows"
        return "\(count) \(rowLabel)"
    }

    private func presentExportSheet() {
        guard let currentResultSet else { return }
        resultExportViewModel = DataExportViewModel(
            databaseType: connection.databaseType,
            resultSet: currentResultSet,
            suggestedFileName: currentResultSetFileName
        )
    }
}
#endif
