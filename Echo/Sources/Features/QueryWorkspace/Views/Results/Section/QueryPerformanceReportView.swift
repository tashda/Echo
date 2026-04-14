import SwiftUI

struct QueryPerformanceReportView: View {
    @Bindable var query: QueryEditorState

    var body: some View {
        if let report {
            HStack(spacing: SpacingTokens.lg) {
                metricCell("First row", EchoFormatters.duration(firstRowTime(for: report)))
                metricCell("Total", EchoFormatters.duration(report.timings.startToFinish))
                metricCell("Rows", EchoFormatters.compactNumber(report.totalRows))
                if let rss = report.residentMemoryBytes {
                    metricCell("Memory", EchoFormatters.bytes(rss))
                }
            }
            .padding(SpacingTokens.md)
        } else {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(ColorTokens.Text.tertiary)
                Text("Run a query to see statistics")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .padding(SpacingTokens.md)
        }
    }

    private var report: QueryPerformanceTracker.Report? {
        query.livePerformanceReport ?? query.lastPerformanceReport
    }

    private func firstRowTime(for report: QueryPerformanceTracker.Report) -> TimeInterval? {
        report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate
    }

    private func metricCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text(value)
                .font(TypographyTokens.body.monospacedDigit())
        }
    }

    struct Metric {
        let label: String
        let value: String
    }
}
