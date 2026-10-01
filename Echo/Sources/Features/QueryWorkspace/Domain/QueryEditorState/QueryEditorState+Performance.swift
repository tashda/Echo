import Foundation

extension QueryEditorState {
    func finalizePerformanceMetrics(cancelled: Bool) {
        let alreadyReported = lastPerformanceReport != nil
        let report = performanceTracker.finalize(
            cancelled: cancelled,
            finalRowCount: rowProgress.reported,
            estimatedMemoryBytes: estimatedMemoryUsageBytes()
        )
        lastPerformanceReport = report
        livePerformanceReport = report
        // Round 41.4, DM1: the metrics are in the time pill's popover, not in Messages.
        if !alreadyReported {
            logPerformance(report: report)
        }
    }

    func refreshLivePerformanceReport() {
        livePerformanceReport = performanceTracker.snapshot(
            currentRowCount: rowProgress.materialized,
            estimatedMemoryBytes: estimatedMemoryUsageBytes()
        )
    }

    private func logPerformance(report: QueryPerformanceTracker.Report) {
        var segments: [String] = []

        if let dispatch = report.timings.startToDispatch {
            segments.append("dispatch \(EchoFormatters.duration(dispatch))")
        }

        let firstRowInterval = report.timings.dispatchToFirstUpdate ?? report.timings.startToFirstUpdate
        if let firstRowInterval {
            var label = "first-row \(EchoFormatters.duration(firstRowInterval))"
            if let firstBatch = report.firstBatchSize, firstBatch > 0 {
                label += " (\(firstBatch))"
            }
            segments.append(label)
        }

        if let initialBatch = report.timings.startToInitialBatch {
            segments.append("data-ready \(EchoFormatters.duration(initialBatch))")
        }

        if let gridReady = report.timings.startToVisibleInitialLimit {
            segments.append("grid-ready \(EchoFormatters.duration(gridReady))")
        }

        if let total = report.timings.startToFinish {
            segments.append("finished \(EchoFormatters.duration(total))")
        }

        if let cpuTotal = report.cpuTotalSeconds {
            segments.append("cpu \(EchoFormatters.duration(cpuTotal))")
        }

        if let rss = report.residentMemoryBytes {
            segments.append("rss \(EchoFormatters.bytes(rss))")
        }

        if let rssDelta = report.residentMemoryDeltaBytes, rssDelta != 0 {
            segments.append("rssΔ \(formattedSignedBytes(rssDelta))")
        }

        segments.append("rows \(report.totalRows)")
        segments.append("batches \(report.batchCount)")
        if report.largestBatchSize > 0 {
            segments.append("largest \(report.largestBatchSize)")
        }
        if let memory = report.estimatedMemoryBytes {
            segments.append("est-mem \(EchoFormatters.bytes(memory))")
        }
        if report.cancelled {
            segments.append("cancelled true")
        }

        var consoleSegments = segments
        if let backend = report.backendSamples.last {
            consoleSegments.append("latest-batch rows=\(backend.batchRowCount)")
            consoleSegments.append("latest-total \(backend.cumulativeRowCount)")
            consoleSegments.append("decode \(EchoFormatters.duration(backend.decodeDuration))")
            consoleSegments.append("wait \(EchoFormatters.duration(backend.networkWaitDuration))")
        }
        print("[QueryPerformance] \(consoleSegments.joined(separator: ", "))")
    }

    private func formattedSignedBytes(_ bytes: Int) -> String {
        if bytes == 0 { return "0 B" }
        let sign = bytes < 0 ? "-" : "+"
        return "\(sign)\(EchoFormatters.bytes(abs(bytes)))"
    }

    func estimatedMemoryUsageBytes() -> Int {
        var total = 64 * 1024
        total += sql.utf8.count * 2
        total += messages.count * 160

        let columnCount = displayedColumns.count
        total += columnCount * 192

        if let results {
            total += estimatedBytes(for: results.rows)
        } else if !streamingRows.isEmpty {
            total += estimatedBytes(for: streamingRows)
        }

        if let visibleLimit = visibleRowLimit, isExecuting {
            total += visibleLimit * columnCount * 4
        }

        return total
    }

    private func estimatedBytes(for rows: [[String?]]) -> Int {
        guard !rows.isEmpty else { return 0 }
        let maxSamples = 2048
        var sampledCells = 0
        var sampledBytes = 0
        var totalCells = 0

        for row in rows {
            totalCells += row.count
            for value in row {
                if sampledCells < maxSamples {
                    let length = value?.utf8.count ?? 0
                    sampledBytes += length + 16
                    sampledCells += 1
                }
            }
        }

        if sampledCells == 0 { return totalCells * 16 }
        let average = sampledBytes / sampledCells
        return average * totalCells
    }
}
