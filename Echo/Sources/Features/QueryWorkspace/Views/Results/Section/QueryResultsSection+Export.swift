import AppKit
import SwiftUI

#if os(macOS)
extension QueryResultsSection {
    var resultsToolbar: some View {
        TabSectionToolbar(sectionPicker: {
            if let entry = query.selectedScriptEntry {
                Text(entry.label)
                    .font(TypographyTokens.formValue)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            } else if query.allResultSetsForDisplay.count > 1 {
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
        let set = query.additionalResults[additionalIndex]
        // A streamed extra set holds only its preview in `additionalResults`; its rows are in its
        // own (possibly spooled) state, exported the same way as the first set.
        guard (set.totalRowCount ?? set.rows.count) > set.rows.count,
              let state = query.additionalResultState(at: additionalIndex) else { return set }
        let rows = (0..<state.displayedRowCount).compactMap { state.displayedRow(at: $0) }
        return QueryResultSet(
            columns: set.columns,
            rows: rows,
            totalRowCount: rows.count,
            commandTag: set.commandTag,
            dataClassification: set.dataClassification
        )
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

    /// Carries out what the rows pill's popover asked for, on the result set on screen in its
    /// current order (round 41.5, PR0).
    func handleResultsAction(_ request: ResultsActionRequest) {
        query.resultsActionRequest = nil
        switch request.kind {
        case .export:
            presentExportSheet()
        case .copyAll:
            guard let resultSet = currentResultSet else { return }
            let text = ResultTableExportFormatter.formatTSV(headers: resultSet.columns.map(\.name), rows: resultSet.rows, includeHeaders: true)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
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
