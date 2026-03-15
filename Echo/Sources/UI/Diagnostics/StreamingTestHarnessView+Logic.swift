import SwiftUI

extension StreamingTestHarnessView {
    func runStreamingTest() {
        guard let session = selectedSession else {
            errorMessage = "Select a connection before running the test."
            return
        }

        flushPendingDebugLogs(immediate: true)
        pendingDebugLogs.removeAll(keepingCapacity: true)
        cancelRunningTest()

        let sql = sqlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else {
            errorMessage = "Enter a SQL statement to execute."
            return
        }

        logs.removeAll()
        errorMessage = nil
        statusMessage = nil
        report = nil
        isRunning = true
        debugAggregator.reset()
        appendLog("[Start] Executing diagnostic query (\(sql.count) chars).", debug: false)

        let initialBatchTarget = max(100, projectStore.globalSettings.resultsInitialRowLimit)
        let newTracker = QueryPerformanceTracker(initialBatchTarget: initialBatchTarget)
        tracker = newTracker
        tracker.reset()
        tracker.markQueryDispatched()

        let runStart = CFAbsoluteTimeGetCurrent()

        runTask = Task {
            do {
                let result = try await session.session.simpleQuery(sql) { update in
                    Task { @MainActor in
                        handleStreamUpdate(update)
                    }
                }

                let rowCount = result.totalRowCount ?? result.rows.count
                await MainActor.run {
                    tracker.markResultSetReceived(totalRowCount: rowCount)
                    let finalReport = tracker.finalize(cancelled: false, finalRowCount: rowCount, estimatedMemoryBytes: nil)
                    report = finalReport
                    statusMessage = "Completed in \(EchoFormatters.duration(CFAbsoluteTimeGetCurrent() - runStart))."
                    isRunning = false
                    appendLog("[Complete] rows=\(rowCount) batches=\(finalReport.batchCount)", debug: false)
                    appendLog(
                        "[Report] firstBatch=\(finalReport.firstBatchSize ?? 0) largestBatch=\(finalReport.largestBatchSize) totalRows=\(finalReport.totalRows)",
                        debug: false
                    )
                    flushDebugSummaries()
                    flushPendingDebugLogs(immediate: true)
                    runTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    statusMessage = "Test cancelled."
                    isRunning = false
                    appendLog("[Cancelled]", debug: false)
                    flushDebugSummaries()
                    flushPendingDebugLogs(immediate: true)
                    runTask = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                    appendLog("[Error] \(error.localizedDescription)", debug: false)
                    flushDebugSummaries()
                    flushPendingDebugLogs(immediate: true)
                    runTask = nil
                }
            }
        }
    }

    func cancelRunningTest() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        flushDebugSummaries()
        flushPendingDebugLogs(immediate: true)
    }

    func handleStreamUpdate(_ update: QueryStreamUpdate) {
        let appendedCount = update.metrics?.batchRowCount
            ?? (!update.appendedRows.isEmpty ? update.appendedRows.count : update.encodedRows.count)

        tracker.recordStreamUpdate(appendedRowCount: appendedCount, totalRowCount: update.totalRowCount)

        if let metrics = update.metrics {
            tracker.recordBackendMetrics(metrics)
            emitDebugSummaries(for: metrics)
            if metrics.fetchRowCount == 0 {
                flushDebugSummaries()
            }
        }
    }

    func emitDebugSummaries(for metrics: QueryStreamMetrics) {
        if let summaries = debugAggregator.record(metrics: metrics), logFilter == .debug {
            for summary in summaries {
                appendLog(summary, debug: true)
            }
        }
    }

    func flushDebugSummaries() {
        if let summaries = logFilter == .debug ? debugAggregator.flushRemaining() : nil {
            for summary in summaries {
                appendLog(summary, debug: true)
            }
        }
        if logFilter != .debug {
            debugAggregator.reset()
        }
    }

    func appendLog(_ message: String, debug: Bool) {
        let entry = StreamingLogEntry(message: message, isDebug: debug)
        if !debug {
            logs.append(entry)
            trimLogsIfNeeded()
            return
        }

        guard logFilter == .debug else { return }
        pendingDebugLogs.append(entry)
        if pendingDebugLogs.count >= 20 {
            flushPendingDebugLogs()
        } else {
            scheduleDebugLogFlush()
        }
    }

    func copyLogsToClipboard() {
        flushPendingDebugLogs(immediate: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let text = filteredLogs
            .map { "[\u{200E}\(formatter.string(from: $0.timestamp))] \($0.message)" }
            .joined(separator: "\n")
#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
#elseif canImport(UIKit)
        UIPasteboard.general.string = text
#endif
    }

    func scheduleDebugLogFlush() {
        guard debugFlushTask == nil else { return }
        debugFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            flushPendingDebugLogs()
        }
    }

    func flushPendingDebugLogs(immediate: Bool = false) {
        if immediate {
            debugFlushTask?.cancel()
        }
        debugFlushTask = nil
        guard !pendingDebugLogs.isEmpty else { return }
        logs.append(contentsOf: pendingDebugLogs)
        pendingDebugLogs.removeAll(keepingCapacity: true)
        trimLogsIfNeeded()
    }

    func trimLogsIfNeeded() {
        let overflow = logs.count - 600
        if overflow > 0 {
            logs.removeFirst(overflow)
        }
    }
}
