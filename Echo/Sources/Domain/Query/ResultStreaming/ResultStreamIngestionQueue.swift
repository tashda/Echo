import Foundation

actor ResultStreamIngestionQueue {
    typealias SpoolReadyHandler = @MainActor @Sendable (ResultSpoolHandle) -> Void

    private let spoolManager: ResultSpoolManager
    private let rowCache: ResultSpoolRowCache
    private let onSpoolReady: SpoolReadyHandler?

    private var spoolHandle: ResultSpoolHandle?
    private var hasNotifiedReady = false
    private var totalRowCount: Int = 0
    private var isFinished = false

    init(
        spoolManager: ResultSpoolManager,
        rowCache: ResultSpoolRowCache,
        onSpoolReady: SpoolReadyHandler? = nil
    ) {
        self.spoolManager = spoolManager
        self.rowCache = rowCache
        self.onSpoolReady = onSpoolReady
    }

    private func notifyHandleReady(_ handle: ResultSpoolHandle) async {
        guard !hasNotifiedReady else { return }
        hasNotifiedReady = true
        if let onSpoolReady {
            await onSpoolReady(handle)
        }
    }

    private func ensureHandle() async throws -> ResultSpoolHandle {
        if let handle = spoolHandle {
            return handle
        }
        let handle = try await spoolManager.makeSpoolHandle()
        spoolHandle = handle
        await notifyHandleReady(handle)
        return handle
    }

    func ingest(update: QueryStreamUpdate) async {
        guard !isFinished else { return }
        guard !update.appendedRows.isEmpty || !update.encodedRows.isEmpty else { return }
        do {
            let handle = try await ensureHandle()
            try await handle.append(
                columns: update.columns,
                rows: update.appendedRows,
                encodedRows: update.encodedRows,
                metrics: update.metrics
            )

            if !update.appendedRows.isEmpty {
                let start = totalRowCount
                rowCache.ingest(rows: update.appendedRows, startingAt: start)
            }

            let appendedCount = !update.encodedRows.isEmpty ? update.encodedRows.count : update.appendedRows.count
            totalRowCount += appendedCount
        } catch {
#if DEBUG
            print("ResultStreamIngestionQueue ingest failed: \(error)")
#endif
        }
    }

    func finalize(commandTag: String?, metrics: QueryStreamMetrics?) async {
        guard !isFinished else { return }
        isFinished = true
        guard let handle = spoolHandle else { return }
        do {
            try await handle.markFinished(commandTag: commandTag, metrics: metrics)
        } catch {
#if DEBUG
            print("ResultStreamIngestionQueue finalize failed: \(error)")
#endif
        }
    }

    func finalize(with result: QueryResultSet) async {
        guard !isFinished else { return }
        do {
            if let handle = spoolHandle {
                if totalRowCount == 0 && !result.rows.isEmpty {
                    try await handle.append(
                        columns: result.columns,
                        rows: result.rows,
                        encodedRows: [],
                        metrics: nil
                    )
                    totalRowCount = result.rows.count
                }
                try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                isFinished = true
                return
            }

            guard !result.columns.isEmpty || !result.rows.isEmpty else { return }

            let handle = try await spoolManager.makeSpoolHandle()
            spoolHandle = handle
            await notifyHandleReady(handle)

            if !result.rows.isEmpty {
                try await handle.append(
                    columns: result.columns,
                    rows: result.rows,
                    encodedRows: [],
                    metrics: nil
                )
                totalRowCount = result.rows.count
            }

            try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
            isFinished = true
        } catch {
#if DEBUG
            print("ResultStreamIngestionQueue finalize(with:) failed: \(error)")
#endif
        }
    }

    func cancel() async {
        guard !isFinished else { return }
        isFinished = true
        guard let handle = spoolHandle else { return }
        do {
            try await handle.markFinished(commandTag: nil, metrics: nil)
        } catch {
#if DEBUG
            print("ResultStreamIngestionQueue cancel failed: \(error)")
#endif
        }
    }

    func currentHandle() -> ResultSpoolHandle? {
        spoolHandle
    }
}
