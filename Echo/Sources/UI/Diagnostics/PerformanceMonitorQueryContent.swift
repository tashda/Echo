import SwiftUI

struct PerformanceMonitorQueryContent: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var query: QueryEditorState
    @Environment(AppearanceStore.self) private var appearanceStore

    private let columns: [GridItem] = [
        GridItem(.flexible(minimum: 120), spacing: SpacingTokens.md, alignment: .leading),
        GridItem(.flexible(minimum: 120), spacing: SpacingTokens.md, alignment: .leading),
        GridItem(.flexible(minimum: 120), spacing: SpacingTokens.md, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            header

            if let report = report {
                metricsSection(for: report)
                backendSection(for: report)
            } else {
                Text("Waiting for performance samples...")
                    .font(TypographyTokens.footnote)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .padding(SpacingTokens.md2)
    }

    private var report: QueryPerformanceTracker.Report? {
        query.livePerformanceReport ?? query.lastPerformanceReport
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .center, spacing: SpacingTokens.sm) {
                Text(tab.title.isEmpty ? "Untitled Query" : tab.title)
                    .font(TypographyTokens.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: SpacingTokens.md) {
                if let connectionName = tab.connection.connectionName.nonEmpty {
                    Label(connectionName, systemImage: "server.rack")
                        .labelStyle(.titleAndIcon)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                if let database = tab.connection.database.nonEmpty {
                    Label(database, systemImage: "database")
                        .labelStyle(.titleAndIcon)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                let rowSummary = "\(max(query.rowProgress.reported, query.rowProgress.materialized)) rows"
                Label(rowSummary, systemImage: "tablecells")
                    .labelStyle(.titleAndIcon)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    private var statusBadge: some View {
        let status = statusDescription
        return Text(status.label)
            .font(TypographyTokens.caption.weight(.bold))
            .padding(.vertical, SpacingTokens.xxs)
            .padding(.horizontal, SpacingTokens.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(status.color.opacity(0.18))
            )
            .foregroundColor(status.color)
    }

    private func metricsSection(for report: QueryPerformanceTracker.Report) -> some View {
        let items = primaryMetrics(for: report)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, metric in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(metric.label)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text(metric.value)
                        .font(TypographyTokens.body.monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private func backendSection(for report: QueryPerformanceTracker.Report) -> some View {
        if let sample = report.backendSamples.last {
            Divider()
            Text("Latest Batch")
                .font(TypographyTokens.subheadline.weight(.bold))
            HStack(spacing: SpacingTokens.xl) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Rows in batch")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text("\(sample.batchRowCount)")
                        .font(TypographyTokens.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Total rows")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text("\(sample.cumulativeRowCount)")
                        .font(TypographyTokens.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Decode time")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text(EchoFormatters.duration(sample.decodeDuration))
                        .font(TypographyTokens.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Network wait")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Text(EchoFormatters.duration(sample.networkWaitDuration))
                        .font(TypographyTokens.body.monospacedDigit())
                }
            }
        }
    }

    private func primaryMetrics(for report: QueryPerformanceTracker.Report) -> [Metric] {
        var items: [Metric] = []
        items.append(Metric(label: "Dispatch", value: EchoFormatters.duration(report.timings.startToDispatch)))

        let firstRow = report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate
        items.append(Metric(label: "First row", value: EchoFormatters.duration(firstRow)))

        items.append(
            Metric(
                label: "Initial \(report.initialBatchTarget)",
                value: EchoFormatters.duration(report.timings.startToInitialBatch)
            )
        )
        items.append(Metric(label: "Grid ready", value: EchoFormatters.duration(report.timings.startToVisibleInitialLimit)))
        items.append(Metric(label: "Total", value: EchoFormatters.duration(report.timings.startToFinish)))
        items.append(Metric(label: "CPU", value: EchoFormatters.duration(report.cpuTotalSeconds)))
        if let rss = report.residentMemoryBytes {
            items.append(Metric(label: "Resident memory", value: EchoFormatters.bytes(rss)))
        }
        if let delta = report.residentMemoryDeltaBytes, delta != 0 {
            let prefix = delta > 0 ? "+" : "--"
            items.append(Metric(label: "RSS delta", value: "\(prefix)\(EchoFormatters.bytes(abs(delta)))"))
        }
        items.append(Metric(label: "Batches", value: "\(report.batchCount)"))
        if let first = report.firstBatchSize {
            items.append(Metric(label: "First batch", value: "\(first)"))
        }
        if report.largestBatchSize > 0 {
            items.append(Metric(label: "Largest batch", value: "\(report.largestBatchSize)"))
        }
        items.append(Metric(label: "Total rows", value: "\(report.totalRows)"))
        if let timeline = report.timeline.last {
            items.append(Metric(label: "Last update", value: "\(timeline.rows) rows @ \(EchoFormatters.duration(timeline.time))"))
        }
        return items
    }

    private var statusDescription: (label: String, color: Color) {
        if query.isExecuting {
            return ("Executing", ColorTokens.Status.warning)
        }
        if query.wasCancelled {
            return ("Cancelled", ColorTokens.Text.secondary)
        }
        if query.errorMessage != nil {
            return ("Error", ColorTokens.Status.error)
        }
        return ("Idle", ColorTokens.Status.success)
    }

    struct Metric {
        let label: String
        let value: String
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
