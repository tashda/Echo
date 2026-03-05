import Foundation

extension ResultSpoolHandle {
    func statsStream() -> AsyncStream<ResultSpoolStats> {
        let identifier = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(identifier)
                }
            }
            Task {
                await self.addContinuation(identifier, continuation)
            }
        }
    }

    func addContinuation(_ id: UUID, _ continuation: AsyncStream<ResultSpoolStats>.Continuation) async {
        statContinuations[id] = continuation
#if DEBUG
        debugLog("statsStream subscribed id=\(id.uuidString.prefix(8)) continuations=\(statContinuations.count)")
#endif
        continuation.yield(currentStats(lastBatch: 0, metrics: nil, isFinished: metadata.isFinished))
    }

    func removeContinuation(_ id: UUID) async {
        statContinuations.removeValue(forKey: id)
#if DEBUG
        debugLog("statsStream removed id=\(id.uuidString.prefix(8)) remaining=\(statContinuations.count)")
#endif
    }

    func persistStats(lastBatch: Int, metrics: QueryStreamMetrics?, isFinished: Bool) {
        let stats = currentStats(lastBatch: lastBatch, metrics: metrics, isFinished: isFinished)
        let statsURL = directory.appendingPathComponent("stats.json")
        Task.detached(priority: .utility) { [weak self, stats] in
            guard let self else { return }
            do {
                let data = try await MainActor.run { () -> Data in
                    let encoder = self.makeJSONEncoder()
                    return try encoder.encode(stats)
                }
                try data.write(to: statsURL, options: .atomic)
            } catch {
                print("ResultSpoolHandle: Failed to persist stats \(error)")
            }
        }
        statContinuations.values.forEach { $0.yield(stats) }
        lastTransientEmission = DispatchTime.now().uptimeNanoseconds
    }

    func emitTransientStatsIfAppropriate() {
        guard !statContinuations.isEmpty else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        if now &- lastTransientEmission >= transientImmediateInterval {
            transientDispatchTask?.cancel()
            transientDispatchTask = nil
            lastTransientEmission = now
            let stats = currentStats(lastBatch: 1, metrics: nil, isFinished: metadata.isFinished)
            statContinuations.values.forEach { $0.yield(stats) }
        } else {
            scheduleTrailingStats()
        }
    }

    func scheduleTrailingStats() {
        guard !statContinuations.isEmpty else { return }
        guard transientDispatchTask == nil else { return }
        transientDispatchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.transientDispatchInterval)
            if Task.isCancelled { return }
            await self.emitScheduledStats()
        }
    }

    func emitScheduledStats() async {
        transientDispatchTask = nil
        guard !statContinuations.isEmpty else { return }
        let stats = currentStats(lastBatch: 0, metrics: nil, isFinished: metadata.isFinished)
        statContinuations.values.forEach { $0.yield(stats) }
        lastTransientEmission = DispatchTime.now().uptimeNanoseconds
    }

    func currentStats(lastBatch: Int, metrics: QueryStreamMetrics?, isFinished: Bool) -> ResultSpoolStats {
        ResultSpoolStats(
            spoolID: metadata.id,
            rowCount: metadata.totalRowCount,
            lastBatchCount: lastBatch,
            cumulativeBytes: metadata.cumulativeBytes,
            lastUpdated: metadata.updatedAt,
            metrics: metrics,
            isFinished: isFinished
        )
    }
}
