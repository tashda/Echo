import Foundation

extension QueryEditorState {

    // MARK: - Streaming & Spooling

    @MainActor
    func prepareSpoolForNewExecution() {
        spoolStatsTask?.cancel()
        spoolStatsTask = nil
        streamingMode = .idle
        shouldPersistResults = false

        if let existingService = ingestionService {
            Task.detached(priority: .utility) {
                await existingService.cancel()
            }
        }
        ingestionService = nil
        deferredSpoolUpdates.removeAll(keepingCapacity: false)
        isSpoolActivationDeferred = true

        rowCache.reset()
        streamedRowCount = 0
        rowProgress = RowProgress()
        materializedHighWaterMark = 0
        lastVisibleDisplayRange = 0..<0
        lastPrefetchedSourceRange = 0..<0
        if let previousID = resultSpoolID {
            let manager = spoolManager
            Task.detached(priority: .utility) {
                await manager.removeSpool(for: previousID)
            }
        }
        spoolHandle = nil
        resultSpoolID = nil
    }

    @MainActor
    func submitToSpool(update: QueryStreamUpdate, mode: StreamingMode) {
        let treatAsPreview = (mode == .preview || mode == .idle)
        if !shouldPersistResults {
            deferredSpoolUpdates.append(.init(update: update, treatAsPreview: treatAsPreview))
            return
        }
        if shouldDeferSpool(for: mode) {
            deferredSpoolUpdates.append(.init(update: update, treatAsPreview: treatAsPreview))
            return
        }

        let service = ensureIngestionService()
        Task.detached(priority: .utility) {
            await service.enqueue(update: update, isPreview: treatAsPreview)
        }
    }

    @MainActor
    private func shouldDeferSpool(for mode: StreamingMode) -> Bool {
        guard isSpoolActivationDeferred else { return false }
        return mode == .preview || mode == .idle
    }

    @MainActor
    @discardableResult
    private func ensureIngestionService() -> ResultStreamIngestionService {
        if let service = ingestionService {
            return service
        }
        let manager = spoolManager
        let service = ResultStreamIngestionService(
            spoolManager: manager,
            rowCache: rowCache,
            onSpoolReady: { [weak self] handle in
                guard let self else { return }
                self.spoolHandle = handle
                self.resultSpoolID = handle.id
                self.attachSpoolStats(from: handle)
            }
        )
        ingestionService = service
        return service
    }

    @MainActor
    func activateSpoolIfNeeded(force: Bool = false) {
        guard shouldPersistResults else { return }
        guard isSpoolActivationDeferred else { return }
        if !force {
            guard streamingMode == .background || streamingMode == .completed else { return }
        }

        isSpoolActivationDeferred = false

        guard !deferredSpoolUpdates.isEmpty else { return }
        let buffered = deferredSpoolUpdates
        deferredSpoolUpdates.removeAll(keepingCapacity: false)
        let service = ensureIngestionService()
        let pendingUpdates: [(QueryStreamUpdate, Bool)] = buffered.map { update in
            (update.update, update.treatAsPreview)
        }

        Task.detached(priority: .utility) {
            for (update, treatAsPreview) in pendingUpdates {
                await service.enqueue(update: update, isPreview: treatAsPreview)
            }
        }
    }

    @MainActor
    func finalizeSpool(with result: QueryResultSet) {
        guard shouldPersistResults else { return }
        let service = ingestionService
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            if let service {
                await service.finalize(with: result)
            } else if !result.columns.isEmpty || !result.rows.isEmpty {
                do {
                    let handle = try await self.spoolManager.makeSpoolHandle()
                    if !result.rows.isEmpty {
                        try await handle.append(
                            columns: result.columns,
                            rows: result.rows,
                            encodedRows: [],
                            rowRange: 0..<result.rows.count,
                            metrics: nil
                        )
                    }
                    try await handle.markFinished(commandTag: result.commandTag, metrics: nil)
                    await MainActor.run {
                        self.spoolHandle = handle
                        self.resultSpoolID = handle.id
                        self.attachSpoolStats(from: handle)
                    }
                } catch {
#if DEBUG
                    print("ResultSpool finalize failed: \(error)")
#endif
                }
            }
            await MainActor.run {
                self.ingestionService = nil
            }
        }
    }

    @MainActor
    func finalizeSpoolOnCompletion(cancelled _: Bool) {
        let currentService = ingestionService

        guard shouldPersistResults else {
            Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                if let service = currentService {
                    await service.cancel()
                }
                await MainActor.run {
                    self.ingestionService = nil
                    self.spoolHandle = nil
                    self.resultSpoolID = nil
                    self.deferredSpoolUpdates.removeAll(keepingCapacity: false)
                    self.shouldPersistResults = false
                }
            }
            return
        }
        if isSpoolActivationDeferred {
            deferredSpoolUpdates.removeAll(keepingCapacity: false)
        }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            if let service = currentService {
                await service.finalize(commandTag: nil, metrics: nil)
            } else {
                let handle = await MainActor.run { self.spoolHandle }
#if DEBUG
                if handle == nil {
                    print("ResultSpoolOnCompletion skipped: no active spool")
                }
#endif
                guard let handle else { return }
                do {
                    try await handle.markFinished(commandTag: nil, metrics: nil)
                } catch {
#if DEBUG
                    print("ResultSpool completion finalize failed: \(error)")
#endif
                }
            }
            await MainActor.run {
                self.ingestionService = nil
            }
        }
    }

    private func attachSpoolStats(from handle: ResultSpoolHandle) {
        spoolStatsTask?.cancel()
        spoolStatsTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let stream = await handle.statsStream()
            for await stats in stream {
                await MainActor.run {
                    self.applySpoolStats(stats)
                }
                if stats.isFinished { break }
            }
            await MainActor.run {
                if self.spoolStatsTask?.isCancelled == false {
                    self.spoolStatsTask = nil
                }
            }
        }
    }

    private func applySpoolStats(_ stats: ResultSpoolStats) {
        var shouldRefreshReport = false
        if let metrics = stats.metrics {
            performanceTracker.recordBackendMetrics(metrics)
            shouldRefreshReport = true
        }

        let previousCount = lastSpoolStatsRowCount
        if stats.rowCount > previousCount {
            lastSpoolStatsRowCount = stats.rowCount
            if rowDiagnosticsEnabled && stats.rowCount > streamedRowCount {
                debugReportRowAnomaly(
                    stage: "spoolStats",
                    message: "spool rowCount \(stats.rowCount) exceeds streamedRowCount \(streamedRowCount)"
                )
            }
            let newReported = max(rowProgress.totalReported, stats.rowCount)
            let newReceived = max(max(streamedRowCount, stats.rowCount), rowProgress.totalReceived)
            if rowProgress.totalReported != newReported || rowProgress.totalReceived != newReceived {
                rowProgress = RowProgress(
                    totalReceived: newReceived,
                    totalReported: newReported,
                    materialized: rowProgress.materialized
                )
                markResultDataChanged()
                if var existing = results, existing.totalRowCount != newReported {
                    existing.totalRowCount = newReported
                    results = existing
                }
            }
            if streamingMode == .background, !isResultsOnly, visibleRowLimit != nil {
                visibleRowLimit = nil
            }
            shouldRefreshReport = true
            if !lastPrefetchedSourceRange.isEmpty {
                ensureRowsMaterialized(range: lastPrefetchedSourceRange)
            }
        }

        if stats.isFinished && !hasAppliedFinalSpoolStats {
            hasAppliedFinalSpoolStats = true
            if !isExecuting {
                markResultDataChanged()
            }
            shouldRefreshReport = true
        }

        if shouldRefreshReport {
            refreshLivePerformanceReport()
        }
    }
}
