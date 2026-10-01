import SwiftUI

/// The rows pill's popover (round 41.5, PR0): rows and columns, which result set, rows loaded
/// against the total while streaming, the memory the results take; Export and Copy All.
struct RowsPillPopover: View {
    @Bindable var query: QueryEditorState

    private var rowCount: Int { query.rowProgress.displayCount }
    private var resultSetCount: Int { query.allResultSetsForDisplay.count }

    private var title: String {
        let rows = rowCount == 1 ? "1 row" : "\(rowCount.formatted()) rows"
        let columnCount = query.displayedColumns.count
        guard columnCount > 0 else { return rows }
        return "\(rows) · \(columnCount == 1 ? "1 column" : "\(columnCount.formatted()) columns")"
    }

    private var memoryBytes: Int? {
        (query.livePerformanceReport ?? query.lastPerformanceReport)?.estimatedMemoryBytes
    }

    var body: some View {
        FooterPopoverContent(title: title) {
            if resultSetCount > 1 {
                FooterPopoverLine(label: "Result", value: "\(query.selectedResultSetIndex + 1) of \(resultSetCount)")
            }
            FooterPopoverLine(label: "Loaded", value: loadedText)
            if let memoryBytes {
                FooterPopoverLine(label: "In memory", value: EchoFormatters.bytes(memoryBytes))
            }
            Divider()
            HStack(spacing: SpacingTokens.xs) {
                Button("Export\u{2026}") { query.resultsActionRequest = ResultsActionRequest(kind: .export) }
                Button("Copy All") { query.resultsActionRequest = ResultsActionRequest(kind: .copyAll) }
                Spacer(minLength: SpacingTokens.none)
            }
            .controlSize(.small)
            .disabled(query.isExecuting || rowCount == 0)
        }
    }

    /// "1,204 of 1,204", or rows read so far against those the server reported while streaming.
    private var loadedText: String {
        let progress = query.rowProgress
        let total = max(progress.totalReported, progress.displayCount)
        return "\(progress.materialized.formatted()) of \(total.formatted())"
    }
}
