import SwiftUI

struct PerformanceMonitorWindow: Scene {
    static let sceneID = "performance-monitor"

    var body: some Scene {
        Window("Performance Monitor", id: Self.sceneID) {
            PerformanceMonitorView()
                .environmentObject(AppCoordinator.shared.appModel)
                .environmentObject(AppCoordinator.shared.appState)
                .environmentObject(AppCoordinator.shared.themeManager)
        }
        .defaultSize(width: 960, height: 620)
    }
}

private struct PerformanceMonitorView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var coordinator = AppCoordinator.shared

    private var queryTabs: [WorkspaceTab] {
        guard coordinator.isInitialized else { return [] }
        return appModel.tabManager.tabs.filter { $0.query != nil }
    }

    var body: some View {
        Group {
            if !coordinator.isInitialized {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Preparing live metrics…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Background.primary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if queryTabs.isEmpty {
                            EmptyStateView(
                                title: "No Query Tabs",
                                message: "Run a query to start capturing live performance metrics.",
                                systemImage: "table"
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(queryTabs) { tab in
                                PerformanceMonitorRow(tab: tab)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 32)
                }
                .background(ColorTokens.Background.primary)
            }
        }
        .preferredColorScheme(themeManager.effectiveColorScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Query Performance")
                .font(.largeTitle.bold())
            Text("Monitor execution timelines, batch flow, and resource usage across open query tabs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

private struct PerformanceMonitorRow: View {
    @ObservedObject var tab: WorkspaceTab
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            if let query = tab.query {
                PerformanceMonitorQueryContent(tab: tab, query: query)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tab.title)
                        .font(.headline)
                    Text("Performance metrics are only available for query tabs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.Background.secondary)
                .shadow(
                    color: Color.black.opacity(themeManager.effectiveColorScheme == .dark ? 0.35 : 0.12),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

private struct PerformanceMonitorQueryContent: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var query: QueryEditorState
    @EnvironmentObject private var themeManager: ThemeManager

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
                Text("Waiting for performance samples…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
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
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
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
                    Text(formatDuration(sample.decodeDuration))
                        .font(.body.monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network wait")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(sample.networkWaitDuration))
                        .font(.body.monospacedDigit())
                }
            }
        }
    }

    private func primaryMetrics(for report: QueryPerformanceTracker.Report) -> [Metric] {
        var items: [Metric] = []
        items.append(Metric(label: "Dispatch", value: formatDuration(report.timings.startToDispatch)))

        let firstRow = report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate
        items.append(Metric(label: "First row", value: formatDuration(firstRow)))

        items.append(
            Metric(
                label: "Initial \(report.initialBatchTarget)",
                value: formatDuration(report.timings.startToInitialBatch)
            )
        )
        items.append(Metric(label: "Grid ready", value: formatDuration(report.timings.startToVisibleInitialLimit)))
        items.append(Metric(label: "Total", value: formatDuration(report.timings.startToFinish)))
        items.append(Metric(label: "CPU", value: formatDuration(report.cpuTotalSeconds)))
        if let rss = report.residentMemoryBytes {
            items.append(Metric(label: "Resident memory", value: formatBytes(rss)))
        }
        if let delta = report.residentMemoryDeltaBytes, delta != 0 {
            let prefix = delta > 0 ? "+" : "–"
            items.append(Metric(label: "RSS delta", value: "\(prefix)\(formatBytes(abs(delta)))"))
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
            items.append(Metric(label: "Last update", value: "\(timeline.rows) rows @ \(formatDuration(timeline.time))"))
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

    private func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "—" }
        if interval >= 1.0 {
            return String(format: "%.2f s", interval)
        }
        return String(format: "%.0f ms", interval * 1_000)
    }

    private func formatBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 B" }
        let units: [String] = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var index = 0
        while value >= 1024.0, index < units.count - 1 {
            value /= 1024.0
            index += 1
        }
        if index == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.2f %@", value, units[index])
    }

    private struct Metric {
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
