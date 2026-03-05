import Foundation

extension QueryEditorState {
    func prepareSpoolForNewExecution() {
        spoolStatsTask?.cancel()
        spoolStatsTask = nil
        deferredSpoolUpdates.removeAll(keepingCapacity: false)
        isSpoolActivationDeferred = true
        resultSpoolID = nil
        spoolHandle = nil
        ingestionService = nil
        shouldPersistResults = false
    }

    func activateSpoolIfNeeded() {
        guard isSpoolActivationDeferred, (shouldPersistResults || streamingMode == .background) else { return }
        isSpoolActivationDeferred = false
        
        let manager = spoolManager
        let cache = rowCache
        
        ingestionService = ResultStreamIngestionService(
            spoolManager: manager,
            rowCache: cache
        ) { [weak self] handle in
            self?.handleSpoolReady(handle)
        }
        
        // Submit deferred updates
        if let ingestion = ingestionService {
            let updates = deferredSpoolUpdates
            deferredSpoolUpdates.removeAll()
            Task {
                for buffered in updates {
                    await ingestion.enqueue(update: buffered.update, isPreview: buffered.treatAsPreview)
                }
            }
        }
    }

    private func handleSpoolReady(_ handle: ResultSpoolHandle) {
        spoolHandle = handle
        resultSpoolID = handle.id
        startSpoolStatsMonitoring(handle: handle)
    }

    func submitToSpool(update: QueryStreamUpdate, mode: StreamingMode) {
        guard shouldPersistResults || streamingMode == .background else { return }
        
        if let ingestion = ingestionService {
            Task {
                await ingestion.enqueue(update: update, isPreview: mode == .preview)
            }
        } else {
            deferredSpoolUpdates.append(BufferedSpoolUpdate(update: update, treatAsPreview: mode == .preview))
        }
    }

    func finalizeSpoolOnCompletion(cancelled: Bool) {
        if cancelled {
            Task {
                await ingestionService?.cancel()
                await MainActor.run {
                    self.shouldPersistResults = false
                    self.ingestionService = nil
                    self.spoolHandle = nil
                    self.spoolStatsTask?.cancel()
                    self.spoolStatsTask = nil
                }
            }
        } else if shouldPersistResults || streamingMode == .background {
            activateSpoolIfNeeded()
            Task {
                await ingestionService?.finalize(commandTag: results?.commandTag, metrics: nil)
            }
        }
    }

    func finalizeSpool(with result: QueryResultSet) {
        activateSpoolIfNeeded()
        Task {
            await ingestionService?.finalize(with: result)
        }
    }

    private func startSpoolStatsMonitoring(handle: ResultSpoolHandle) {
        spoolStatsTask?.cancel()
        spoolStatsTask = Task { [weak self] in
            let stream = await handle.statsStream()
            for await stats in stream {
                if Task.isCancelled { break }
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.lastSpoolStatsRowCount = stats.rowCount
                    self.refreshMaterializedProgress()
                }
                if stats.isFinished { break }
            }
        }
    }
}
