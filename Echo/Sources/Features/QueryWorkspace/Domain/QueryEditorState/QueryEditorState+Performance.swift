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
        if !alreadyReported {
            appendPerformanceMessage(report: report)
        }
    }

    func refreshLivePerformanceReport() {
        livePerformanceReport = performanceTracker.snapshot(
            currentRowCount: rowProgress.materialized,
            estimatedMemoryBytes: estimatedMemoryUsageBytes()
        )
    }

    private func appendPerformanceMessage(report: QueryPerformanceTracker.Report) {
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

        var metadata: [String: String] = [
            "rows": "\(report.totalRows)",
            "batchCount": "\(report.batchCount)",
            "largestBatchSize": "\(report.largestBatchSize)",
            "initialBatchTarget": "\(report.initialBatchTarget)",
            "cancelled": report.cancelled ? "true" : "false",
            "timelineSamples": "\(report.timeline.count)"
        ]
        if let firstBatch = report.firstBatchSize {
            metadata["firstBatchSize"] = "\(firstBatch)"
        }
        if let memory = report.estimatedMemoryBytes {
            metadata["estimatedMemoryBytes"] = "\(memory)"
            metadata["estimatedMemoryDisplay"] = EchoFormatters.bytes(memory)
        }

        if let cpuUser = report.cpuUserSeconds {
            metadata["cpuUserSeconds"] = String(format: "%.6f", cpuUser)
        }
        if let cpuSystem = report.cpuSystemSeconds {
            metadata["cpuSystemSeconds"] = String(format: "%.6f", cpuSystem)
        }
        if let cpuTotal = report.cpuTotalSeconds {
            metadata["cpuTotalSeconds"] = String(format: "%.6f", cpuTotal)
        }
        if let resident = report.residentMemoryBytes {
            metadata["residentMemoryBytes"] = "\(resident)"
            metadata["residentMemoryDisplay"] = EchoFormatters.bytes(resident)
        }
        if let residentDelta = report.residentMemoryDeltaBytes {
            metadata["residentMemoryDeltaBytes"] = "\(residentDelta)"
            metadata["residentMemoryDeltaDisplay"] = formattedSignedBytes(residentDelta)
        }
        if let maxResident = report.maxResidentMemoryBytes {
            metadata["maxResidentMemoryBytes"] = "\(maxResident)"
            metadata["maxResidentMemoryDisplay"] = EchoFormatters.bytes(maxResident)
        }
        if let virtual = report.virtualMemoryBytes {
            metadata["virtualMemoryBytes"] = "\(virtual)"
            metadata["virtualMemoryDisplay"] = EchoFormatters.bytes(virtual)
        }
        if let value = millisecondsString(report.timings.startToDispatch) {
            metadata["startToDispatchMs"] = value
        }
        if let value = millisecondsString(report.timings.dispatchToFirstUpdate) {
            metadata["dispatchToFirstUpdateMs"] = value
        }
        if let value = millisecondsString(report.timings.startToFirstUpdate) {
            metadata["startToFirstUpdateMs"] = value
        }
        if let value = millisecondsString(report.timings.startToInitialBatch) {
            metadata["startToInitialBatchMs"] = value
        }
        if let value = millisecondsString(report.timings.startToVisibleInitialLimit) {
            metadata["startToVisibleInitialLimitMs"] = value
        }
        if let value = millisecondsString(report.timings.startToResultSet) {
            metadata["startToResultSetMs"] = value
        }
        if let value = millisecondsString(report.timings.startToFinish) {
            metadata["startToFinishMs"] = value
        }
        if let value = millisecondsString(report.timings.resultSetToFinish) {
            metadata["resultSetToFinishMs"] = value
        }

        appendMessage(
            message: "Execution metrics: \(segments.joined(separator: ", "))",
            severity: .debug,
            category: "Performance",
            metadata: metadata
        )
    }

    private func millisecondsString(_ value: TimeInterval?) -> String? {
        guard let value else { return nil }
        return String(format: "%.2f", value * 1_000)
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
