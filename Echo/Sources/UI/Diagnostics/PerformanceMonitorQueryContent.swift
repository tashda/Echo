import SwiftUI

struct PerformanceMonitorQueryContent: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var query: QueryEditorState
    @EnvironmentObject private var appearanceStore: AppearanceStore

    private let columns: [GridItem] = [
        GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
        GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
        GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let report = report {
                metricsSection(for: report)
                backendSection(for: report)
            } else {
                Text("Waiting for performance samples...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SpacingTokens.md2)
    }

    private var report: QueryPerformanceTracker.Report? {
        query.livePerformanceReport ?? query.lastPerformanceReport
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(tab.title.isEmpty ? "Untitled Query" : tab.title)
                    .font(.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: 16) {
                if let connectionName = tab.connection.connectionName.nonEmpty {
                    Label(connectionName, systemImage: "server.rack")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let database = tab.connection.database.nonEmpty {
                    Label(database, systemImage: "database")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                let rowSummary = "\(max(query.rowProgress.reported, query.rowProgress.materialized)) rows"
                Label(rowSummary, systemImage: "tablecells")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusBadge: some View {
        let status = statusDescription
        return Text(status.label)
            .font(.caption.bold())
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
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.body.monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private func backendSection(for report: QueryPerformanceTracker.Report) -> some View {
        if let sample = report.backendSamples.last {
            Divider()
            Text("Latest Batch")
                .font(.subheadline.bold())
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rows in batch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(sample.batchRowCount)")
                        .font(.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(sample.cumulativeRowCount)")
                        .font(.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decode time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(EchoFormatters.duration(sample.decodeDuration))
                        .font(.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network wait")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(EchoFormatters.duration(sample.networkWaitDuration))
                        .font(.body.monospacedDigit())
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
            return ("Executing", .orange)
        }
        if query.wasCancelled {
            return ("Cancelled", .gray)
        }
        if query.errorMessage != nil {
            return ("Error", .red)
        }
        return ("Idle", .green)
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
