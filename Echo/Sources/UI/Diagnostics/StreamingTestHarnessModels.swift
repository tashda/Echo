import SwiftUI

enum LogVisibility: String, CaseIterable, Identifiable {
    case simple
    case debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return "Simple"
        case .debug: return "Debug"
        }
    }
}

struct StreamingLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
    let isDebug: Bool
}

struct DebugLogAggregator {
    private(set) var nextFetchIndex: Int = 1
    private var pendingMetrics: [QueryStreamMetrics] = []
    private var lastFlushTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    mutating func reset() {
        nextFetchIndex = 1
        pendingMetrics.removeAll(keepingCapacity: true)
        lastFlushTime = CFAbsoluteTimeGetCurrent()
    }

    mutating func record(metrics: QueryStreamMetrics) -> [String]? {
        guard metrics.batchRowCount > 0 || (metrics.fetchRowCount ?? 0) > 0 else {
            return nil
        }
        if let request = metrics.fetchRequestRowCount,
           let rows = metrics.fetchRowCount,
           request == 0,
           rows == 0 {
            return nil
        }
        pendingMetrics.append(metrics)
        let now = CFAbsoluteTimeGetCurrent()
        if pendingMetrics.count >= 4 || now - lastFlushTime >= 0.5 {
            return flush(currentTime: now)
        }
        return nil
    }

    mutating func flushRemaining() -> [String]? {
        guard !pendingMetrics.isEmpty else { return nil }
        return flush(currentTime: CFAbsoluteTimeGetCurrent())
    }

    private mutating func flush(currentTime: CFAbsoluteTime) -> [String] {
        let startIndex = nextFetchIndex
        nextFetchIndex += pendingMetrics.count
        let messages = pendingMetrics.enumerated().map { offset, metric -> String in
            let fetchNumber = startIndex + offset
            let requested = metric.fetchRequestRowCount ?? metric.batchRowCount
            let rows = metric.fetchRowCount ?? metric.batchRowCount
            let duration = metric.fetchDuration ?? metric.loopElapsed
            let wait = metric.fetchWait ?? max(duration - metric.decodeDuration, 0)
            let throughput = (duration > 0 && rows > 0) ? Double(rows) / duration : 0
            return String(
                format: "[Fetch #%d] requested=%d rows=%d wait=%.3fs decode=%.3fs loop=%.3fs rows/s=%.0f total=%d",
                fetchNumber,
                requested,
                rows,
                wait,
                metric.decodeDuration,
                duration,
                throughput,
                metric.cumulativeRowCount
            )
        }
        pendingMetrics.removeAll(keepingCapacity: true)
        lastFlushTime = currentTime
        return messages
    }
}

struct StreamingReportSummary: View {
    let report: QueryPerformanceTracker.Report

    private var timings: [(label: String, value: String)] {
        var items: [(String, String)] = []
        if let dispatch = report.timings.startToDispatch {
            items.append(("Dispatch", EchoFormatters.duration(dispatch)))
        }
        if let first = report.timings.startToFirstUpdate {
            items.append(("First batch", EchoFormatters.duration(first)))
        }
        if let initial = report.timings.startToInitialBatch {
            items.append(("Initial target", EchoFormatters.duration(initial)))
        }
        if let finish = report.timings.startToFinish {
            items.append(("Finish", EchoFormatters.duration(finish)))
        }
        return items
    }

    private var throughput: String {
        guard let total = report.timings.startToFinish, total > 0 else {
            return "—"
        }
        let rowsPerSecond = Double(report.totalRows) / total
        return String(format: "%.0f rows/s", rowsPerSecond)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
                GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading),
                GridItem(.flexible(minimum: 120), spacing: 18, alignment: .leading)
            ], alignment: .leading, spacing: 12) {
                metric("Total rows", value: "\(report.totalRows)")
                metric("Batches", value: "\(report.batchCount)")
                metric("Largest batch", value: "\(report.largestBatchSize)")
                metric("First batch", value: report.firstBatchSize.map { "\($0)" } ?? "—")
                metric("Throughput", value: throughput)
                metric("Estimated memory", value: report.estimatedMemoryBytes.map(EchoFormatters.bytes) ?? "—")
            }

            if !timings.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Timings")
                        .font(.subheadline.bold())
                    ForEach(timings, id: \.label) { item in
                        HStack {
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text(item.value)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }

            if let sample = report.backendSamples.last {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest Backend Sample")
                        .font(.subheadline.bold())
                    HStack(spacing: 18) {
                        metric("Rows in batch", value: "\(sample.batchRowCount)")
                        metric("Total rows", value: "\(sample.cumulativeRowCount)")
                        metric("Loop", value: EchoFormatters.duration(sample.loopElapsed))
                        metric("Decode", value: EchoFormatters.duration(sample.decodeDuration))
                        metric("Network wait", value: EchoFormatters.duration(sample.networkWaitDuration))
                    }
                }
            }
        }
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
    }

}
