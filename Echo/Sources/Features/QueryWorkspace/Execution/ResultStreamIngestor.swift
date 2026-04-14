import Foundation
import OSLog

actor ResultStreamIngestor {
    typealias SpoolReadyHandler = @MainActor @Sendable (ResultSpoolHandle) -> Void

    private let spoolManager: ResultSpooler
    private let rowCache: ResultSpoolRowCache
    private let onSpoolReady: SpoolReadyHandler?

    private var spoolHandle: ResultSpoolHandle?
    private var hasNotifiedReady = false
    private var totalRowCount: Int = 0
    private var isFinished = false
    private var isCancelled = false
    private var appendTask: Task<Void, Never>?
    private var didWarnAboutEncodingFallback = false

    init(
        spoolManager: ResultSpooler,
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
        guard !update.appendedRows.isEmpty || !update.encodedRows.isEmpty || !update.rawRows.isEmpty else { return }

        do {
            Logger.spool.debug("enqueue start preview=\(isPreview) appended=\(update.appendedRows.count) encoded=\(update.encodedRows.count) total=\(update.totalRowCount)")

            let appendCountEstimate = max(update.appendedRows.count, max(update.encodedRows.count, update.rawRows.count))
            let resolvedRange: Range<Int>? = {
                if let range = update.rowRange, range.count == appendCountEstimate {
                    return range
                }
                return nil
            }()

            let handle = try await ensureHandle()

            if isPreview, !update.appendedRows.isEmpty {
                let startIndex = resolvedRange?.lowerBound ?? totalRowCount
                let rowsForCache = update.appendedRows
                Task.detached(priority: .utility) { [rowCache] in
                    rowCache.ingest(rows: rowsForCache, startingAt: startIndex)
                }
            }

            let encodedRows: [ResultBinaryRow]
            if !update.encodedRows.isEmpty {
                encodedRows = update.encodedRows
            } else if !update.rawRows.isEmpty {
                encodedRows = update.rawRows.map { payload in
                    ResultBinaryRowCodec.encodeRaw(cells: payload.cells.map(\.bytes))
                }
            } else if !update.appendedRows.isEmpty && !isPreview {
                if !didWarnAboutEncodingFallback {
                    didWarnAboutEncodingFallback = true
                    Logger.spool.debug("Encoding background rows on worker; driver did not supply pre-encoded payloads.")
                }
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

            let previousTask = appendTask
            let columns = update.columns
            let metrics = update.metrics

            appendTask = Task.detached(priority: .utility) {
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
                } catch {
                    Logger.spool.error("append failed: \(error)")
                }
            }
        } catch {
            Logger.spool.error("enqueue failed: \(error)")
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
            Logger.spool.error("finalize failed: \(error)")
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
                Logger.spool.error("finalize(with:) failed: \(error)")
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
            Logger.spool.error("finalize(with result:) failed: \(error)")
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
            Logger.spool.error("cancel failed: \(error)")
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
        Logger.spool.debug("ensureHandle created new spool id=\(handle.id.uuidString.prefix(8))")
        return handle
    }

    private func notifyHandleReady(_ handle: ResultSpoolHandle) async {
        guard !hasNotifiedReady else { return }
        hasNotifiedReady = true
        if let onSpoolReady {
            await onSpoolReady(handle)
        }
    }

    private func waitForPendingAppends() async {
        if let task = appendTask {
            appendTask = nil
            await task.value
        }
    }
}
