import Foundation

actor ResultStreamIngestionService {
    typealias SpoolReadyHandler = @MainActor @Sendable (ResultSpoolHandle) -> Void

    private let spoolManager: ResultSpoolManager
    private let rowCache: ResultSpoolRowCache
    private let onSpoolReady: SpoolReadyHandler?

#if DEBUG
    private let debugID = String(UUID().uuidString.prefix(8))
    private func debugLog(_ message: @autoclosure () -> String) {
        print("[ResultStreamIngestionService][\(debugID)] \(message())")
    }
#else
    private func debugLog(_ message: @autoclosure () -> String) {}
#endif

    private var spoolHandle: ResultSpoolHandle?
    private var hasNotifiedReady = false
    private var totalRowCount: Int = 0
    private var isFinished = false
    private var isCancelled = false
    private var appendTask: Task<Void, Never>?
    private var didWarnAboutEncodingFallback = false

#if DEBUG
    private var pendingBatchCount: Int = 0
    private var queuedRowCount: Int = 0
    private var lastDiagnosticsTimestamp: CFAbsoluteTime = 0
#endif

    init(
        spoolManager: ResultSpoolManager,
        rowCache: ResultSpoolRowCache,
        onSpoolReady: SpoolReadyHandler? = nil
    ) {
        self.spoolManager = spoolManager
        self.rowCache = rowCache
        self.onSpoolReady = onSpoolReady
    }

    deinit {
        appendTask?.cancel()
    }

    func enqueue(update: QueryStreamUpdate, isPreview: Bool) async {
        guard !isFinished, !isCancelled else { return }
        guard !update.appendedRows.isEmpty || !update.encodedRows.isEmpty else { return }

        do {
#if DEBUG
            let enqueueStart = CFAbsoluteTimeGetCurrent()
            debugLog("enqueue start preview=\(isPreview) appended=\(update.appendedRows.count) encoded=\(update.encodedRows.count) total=\(update.totalRowCount)")
#endif
            let appendCountEstimate = max(update.appendedRows.count, update.encodedRows.count)
            let resolvedRange: Range<Int>? = {
                if let range = update.rowRange, range.count == appendCountEstimate {
                    return range
                }
                return nil
            }()

            let handle = try await ensureHandle()

#if DEBUG
            let rowDiagnosticsEnabled = ProcessInfo.processInfo.environment["ECHO_ROW_DEBUG"] == "1"
            if rowDiagnosticsEnabled, let range = update.rowRange, range.count != appendCountEstimate {
                print("[RowDiagnostics][ingestion] rowRange count \(range.count) != appendCountEstimate \(appendCountEstimate)")
            }
            if rowDiagnosticsEnabled, let range = resolvedRange, range.upperBound > update.totalRowCount {
                print("[RowDiagnostics][ingestion] resolvedRange upperBound \(range.upperBound) exceeds total \(update.totalRowCount)")
            }
#endif

            if isPreview, !update.appendedRows.isEmpty {
                let startIndex = resolvedRange?.lowerBound ?? totalRowCount
                let rowsForCache = update.appendedRows
                DispatchQueue.global(qos: .utility).async { [rowCache] in
                    rowCache.ingest(rows: rowsForCache, startingAt: startIndex)
                }
            }

            let encodedRows: [ResultBinaryRow]
            if !update.encodedRows.isEmpty {
                encodedRows = update.encodedRows
            } else if isPreview {
                encodedRows = []
            } else if !update.appendedRows.isEmpty {
#if DEBUG
                if !didWarnAboutEncodingFallback {
                    didWarnAboutEncodingFallback = true
                    print("[ResultStreamIngestionService] Encoding background rows on worker; driver did not supply pre-encoded payloads.")
                }
#endif
                encodedRows = update.appendedRows.map(ResultBinaryRowCodec.encode(row:))
            } else {
                encodedRows = []
            }

            let rowsForAppend: [[String?]] = isPreview ? update.appendedRows : []
            let appendCount = max(rowsForAppend.count, encodedRows.count)
            guard appendCount > 0 else { return }

            let rangeForAppend: Range<Int>
            if let resolvedRange = resolvedRange {
                rangeForAppend = resolvedRange
                totalRowCount = max(totalRowCount, resolvedRange.upperBound)
            } else {
                let start = totalRowCount
                let end = start + appendCount
                rangeForAppend = start..<end
                totalRowCount = end
            }
#if DEBUG
            if ProcessInfo.processInfo.environment["ECHO_ROW_DEBUG"] == "1", rangeForAppend.upperBound > update.totalRowCount {
                print("[RowDiagnostics][ingestion] rangeForAppend \(rangeForAppend) exceeds update total \(update.totalRowCount)")
            }
#endif

            let previousTask = appendTask
            let columns = update.columns
            let metrics = update.metrics
#if DEBUG
            let enqueueEvent = isPreview ? "enqueue-preview" : "enqueue-background"
            pendingBatchCount &+= 1
            queuedRowCount &+= appendCount
            logDiagnostics(event: enqueueEvent, rows: appendCount, metrics: metrics)
#endif
            appendTask = Task.detached(priority: .utility) {
#if DEBUG
                await self.debugLog("append task start preview=\(isPreview) rows=\(appendCount)")
#endif
                if let previousTask {
                    await previousTask.value
                }

                do {
                    try await handle.append(
                        columns: columns,
                        rows: rowsForAppend,
                        encodedRows: encodedRows,
                        rowRange: rangeForAppend,
                        metrics: metrics
                    )
#if DEBUG
                    if appendCount == 1 && !isPreview {
                        print("[ResultStreamIngestionService] Background append single row; consider increasing batch size.")
                    }
#endif
                } catch {
#if DEBUG
                    print("ResultStreamIngestionService append failed: \(error)")
#endif
                }
#if DEBUG
                let duration = CFAbsoluteTimeGetCurrent() - enqueueStart
                await self.debugLog("append task finished preview=\(isPreview) rows=\(appendCount) duration=\(String(format: "%.3f", duration))")
                let flushEvent = isPreview ? "flush-preview" : "flush-background"
                await self.recordAppendCompletion(rows: appendCount, metrics: metrics, event: flushEvent)
#endif
            }
        } catch {
#if DEBUG
            print("ResultStreamIngestionService enqueue failed: \(error)")
#endif
        }
    }

    func finalize(commandTag: String?, metrics: QueryStreamMetrics?) async {
        guard !isFinished else { return }
        isFinished = true
        await waitForPendingAppends()
        guard let handle = spoolHandle else { return }
        do {
            try await handle.markFinished(commandTag: commandTag, metrics: metrics)
        } catch {
#if DEBUG
            print("ResultStreamIngestionService finalize failed: \(error)")
#endif
        }
    }

    func finalize(with result: QueryResultSet) async {
        guard !isFinished else { return }

        let finalCount = result.totalRowCount ?? result.rows.count

        if let handle = spoolHandle {
            await waitForPendingAppends()
            do {
                if totalRowCount == 0, !result.rows.isEmpty {
                    try await handle.append(
                        columns: result.columns,
                        rows: result.rows,
                        encodedRows: [],
                        rowRange: 0..<result.rows.count,
                        metrics: nil
                    )
                    totalRowCount = result.rows.count
                }
                totalRowCount = max(totalRowCount, finalCount)
                try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                isFinished = true
            } catch {
#if DEBUG
                print("ResultStreamIngestionService finalize(with:) failed: \(error)")
#endif
            }
            return
        }

        guard !result.columns.isEmpty || !result.rows.isEmpty else {
            isFinished = true
            return
        }

        do {
            let handle = try await spoolManager.makeSpoolHandle()
            spoolHandle = handle
            await notifyHandleReady(handle)

            if !result.rows.isEmpty {
                try await handle.append(
                    columns: result.columns,
                    rows: result.rows,
                    encodedRows: [],
                    rowRange: 0..<result.rows.count,
                    metrics: nil
                )
                totalRowCount = result.rows.count
            }

            totalRowCount = max(totalRowCount, finalCount)
            try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
            isFinished = true
        } catch {
#if DEBUG
            print("ResultStreamIngestionService finalize(with result:) failed: \(error)")
#endif
        }
    }

    func cancel() async {
        guard !isFinished else { return }
        isCancelled = true
        isFinished = true
        await waitForPendingAppends()
        guard let handle = spoolHandle else { return }
        do {
            try await handle.markFinished(commandTag: nil, metrics: nil)
        } catch {
#if DEBUG
            print("ResultStreamIngestionService cancel failed: \(error)")
#endif
        }
    }

    func currentHandle() -> ResultSpoolHandle? {
        spoolHandle
    }

    private func ensureHandle() async throws -> ResultSpoolHandle {
        if let handle = spoolHandle {
            return handle
        }
        let handle = try await spoolManager.makeSpoolHandle()
        spoolHandle = handle
        await notifyHandleReady(handle)
#if DEBUG
        debugLog("ensureHandle created new spool id=\(handle.id.uuidString.prefix(8))")
#endif
        return handle
    }

    private func notifyHandleReady(_ handle: ResultSpoolHandle) async {
        guard !hasNotifiedReady else { return }
        hasNotifiedReady = true
#if DEBUG
        debugLog("notifyHandleReady spool id=\(handle.id.uuidString.prefix(8))")
#endif
        if let onSpoolReady {
            await onSpoolReady(handle)
        }
    }

    private func waitForPendingAppends() async {
        if let task = appendTask {
            appendTask = nil
            await task.value
        }
#if DEBUG
        resetDiagnostics()
#endif
    }

#if DEBUG
    private func recordAppendCompletion(rows: Int, metrics: QueryStreamMetrics?, event: String) async {
        pendingBatchCount = max(0, pendingBatchCount - 1)
        queuedRowCount = max(0, queuedRowCount - rows)
        logDiagnostics(event: event, rows: rows, metrics: metrics)
    }

    private func resetDiagnostics() {
        pendingBatchCount = 0
        queuedRowCount = 0
        lastDiagnosticsTimestamp = 0
    }

    private func logDiagnostics(event: String, rows: Int, metrics: QueryStreamMetrics?) {
        let totalRows = totalRowCount
        let loop = metrics?.loopElapsed ?? 0
        let decode = metrics?.decodeDuration ?? 0
        let now = CFAbsoluteTimeGetCurrent()
        if rows < 8, loop < 0.3, queuedRowCount < 512, now - lastDiagnosticsTimestamp < 0.25 {
            return
        }
        lastDiagnosticsTimestamp = now
        let message = String(
            format: "[ResultStreamIngestion] %@ rows=%d queued=%d pending=%d total=%d loop=%.3fs decode=%.3fs",
            event,
            rows,
            queuedRowCount,
            pendingBatchCount,
            totalRows,
            loop,
            decode
        )
        print(message)
        if totalRows >= 5_000, totalRows % 5_000 == 0 {
            print("[ResultStreamIngestion] checkpoint total=\(totalRows)")
        }
    }
#endif
}
