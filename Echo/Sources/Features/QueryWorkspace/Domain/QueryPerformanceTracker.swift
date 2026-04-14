import Foundation
import Darwin

@MainActor
final class QueryPerformanceTracker {
    struct TimelineEntry: Sendable {
        let time: TimeInterval
        let rows: Int
    }

    struct Report: Sendable {
        struct Timings: Sendable {
            var startToDispatch: TimeInterval?
            var dispatchToFirstUpdate: TimeInterval?
            var startToFirstUpdate: TimeInterval?
            var startToInitialBatch: TimeInterval?
            var firstUpdateToInitialBatch: TimeInterval?
            var startToResultSet: TimeInterval?
            var resultSetToFinish: TimeInterval?
            var startToFinish: TimeInterval?
            var startToFirstTableReload: TimeInterval?
            var firstUpdateToFirstTableReload: TimeInterval?
            var startToVisibleInitialLimit: TimeInterval?
            var firstUpdateToVisibleInitialLimit: TimeInterval?
        }

        struct BackendSample: Sendable {
            var totalElapsed: TimeInterval
            var loopElapsed: TimeInterval
            var decodeDuration: TimeInterval
            var networkWaitDuration: TimeInterval
            var batchRowCount: Int
            var cumulativeRowCount: Int
            var fetchRequestRowCount: Int?
            var fetchRowCount: Int?
        }

        var timings: Timings
        var totalRows: Int
        var batchCount: Int
        var firstBatchSize: Int?
        var largestBatchSize: Int
        var batchSizes: [Int]
        var initialBatchTarget: Int
        var cancelled: Bool
        var estimatedMemoryBytes: Int?
        var cpuUserSeconds: TimeInterval?
        var cpuSystemSeconds: TimeInterval?
        var residentMemoryBytes: Int?
        var residentMemoryDeltaBytes: Int?
        var virtualMemoryBytes: Int?
        var maxResidentMemoryBytes: Int?
        var timeline: [TimelineEntry]
        var backendSamples: [BackendSample]

        var cpuTotalSeconds: TimeInterval? {
            guard let user = cpuUserSeconds, let system = cpuSystemSeconds else { return nil }
            return user + system
        }
    }

    private let initialBatchTarget: Int
    private var didFinalize = false
    private var cachedReport: Report?

    private var startTimestamp: TimeInterval
    private var dispatchTimestamp: TimeInterval?
    private var firstUpdateTimestamp: TimeInterval?
    private var initialBatchTimestamp: TimeInterval?
    private var resultSetTimestamp: TimeInterval?
    private var finishTimestamp: TimeInterval?
    private var firstTableReloadTimestamp: TimeInterval?
    private var visibleInitialLimitTimestamp: TimeInterval?

    private var totalRows: Int = 0
    private var finalRowCount: Int = 0
    private var batchSizes: [Int] = []
    private var largestBatchSize: Int = 0
    private var firstBatchSize: Int?
    private var cancelled = false
    private var dispatchSample: ResourceSample?
    private var finishSample: ResourceSample?
    private var timeline: [TimelineEntry] = []
    private var backendSamples: [Report.BackendSample] = []

    private struct ResourceSample {
        let userTime: TimeInterval
        let systemTime: TimeInterval
        let residentSize: Int
        let virtualSize: Int
        let maxResidentSize: Int
    }

    init(initialBatchTarget: Int) {
        self.initialBatchTarget = max(1, initialBatchTarget)
        self.startTimestamp = QueryPerformanceTracker.now()
    }

    func markQueryDispatched() {
        dispatchTimestamp = dispatchTimestamp ?? QueryPerformanceTracker.now()
        if dispatchSample == nil {
            dispatchSample = captureResourceUsage()
        }
    }

    func recordStreamUpdate(appendedRowCount: Int, totalRowCount: Int) {
        totalRows = max(totalRows, totalRowCount)
        if appendedRowCount > 0 {
            batchSizes.append(appendedRowCount)
            if appendedRowCount > largestBatchSize {
                largestBatchSize = appendedRowCount
            }
            if firstBatchSize == nil {
                firstBatchSize = appendedRowCount
            }
        }

        let now = QueryPerformanceTracker.now()
        if firstUpdateTimestamp == nil {
            firstUpdateTimestamp = now
        }

        if appendedRowCount > 0 {
            timeline.append(TimelineEntry(time: max(0, now - startTimestamp), rows: totalRowCount))
        }

        if appendedRowCount > 0, initialBatchTimestamp == nil, totalRowCount >= initialBatchTarget {
            initialBatchTimestamp = now
        }
    }

    func recordBackendMetrics(_ metrics: QueryStreamMetrics) {
        let sample = Report.BackendSample(
            totalElapsed: metrics.totalElapsed,
            loopElapsed: metrics.loopElapsed,
            decodeDuration: metrics.decodeDuration,
            networkWaitDuration: metrics.networkWaitEstimate,
            batchRowCount: metrics.batchRowCount,
            cumulativeRowCount: metrics.cumulativeRowCount,
            fetchRequestRowCount: metrics.fetchRequestRowCount,
            fetchRowCount: metrics.fetchRowCount
        )
        backendSamples.append(sample)
    }

    func recordInitialBatchReady(totalRowCount: Int) {
        guard initialBatchTimestamp == nil, totalRowCount >= initialBatchTarget else { return }
        initialBatchTimestamp = QueryPerformanceTracker.now()
    }

    func recordTableReload() {
        firstTableReloadTimestamp = firstTableReloadTimestamp ?? QueryPerformanceTracker.now()
    }

    func recordVisibleInitialLimitSatisfied() {
        visibleInitialLimitTimestamp = visibleInitialLimitTimestamp ?? QueryPerformanceTracker.now()
    }

    func markResultSetReceived(totalRowCount: Int) {
        finalRowCount = max(finalRowCount, totalRowCount)
        resultSetTimestamp = resultSetTimestamp ?? QueryPerformanceTracker.now()
    }

    func finalize(cancelled: Bool, finalRowCount: Int, estimatedMemoryBytes: Int?) -> Report {
        if let cachedReport {
            return cachedReport
        }

        let finishTime = QueryPerformanceTracker.now()
        self.cancelled = cancelled
        self.finalRowCount = max(self.finalRowCount, finalRowCount)
        finishTimestamp = finishTimestamp ?? finishTime
        if finishSample == nil {
            finishSample = captureResourceUsage()
        }

        let report = makeReport(
            finishTime: finishTime,
            finishSample: finishSample,
            cancelled: cancelled,
            finalRowCount: self.finalRowCount,
            estimatedMemoryBytes: estimatedMemoryBytes
        )
        cachedReport = report
        didFinalize = true
        return report
    }

    func snapshot(currentRowCount: Int, estimatedMemoryBytes: Int?) -> Report {
        let finishTime = QueryPerformanceTracker.now()
        let resolvedFinalCount = max(finalRowCount, totalRows, currentRowCount)
        return makeReport(
            finishTime: finishTime,
            finishSample: nil,
            cancelled: cancelled,
            finalRowCount: resolvedFinalCount,
            estimatedMemoryBytes: estimatedMemoryBytes
        )
    }

    func reset() {
        didFinalize = false
        cachedReport = nil
        totalRows = 0
        finalRowCount = 0
        batchSizes.removeAll(keepingCapacity: true)
        largestBatchSize = 0
        firstBatchSize = nil
        cancelled = false
        startTimestamp = QueryPerformanceTracker.now()
        dispatchTimestamp = nil
        firstUpdateTimestamp = nil
        initialBatchTimestamp = nil
        resultSetTimestamp = nil
        finishTimestamp = nil
        firstTableReloadTimestamp = nil
        visibleInitialLimitTimestamp = nil
        dispatchSample = nil
        finishSample = nil
        timeline.removeAll(keepingCapacity: true)
        backendSamples.removeAll(keepingCapacity: true)
    }

    private func captureResourceUsage() -> ResourceSample? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }

        let user = TimeInterval(usage.ru_utime.tv_sec) + TimeInterval(usage.ru_utime.tv_usec) / 1_000_000
        let system = TimeInterval(usage.ru_stime.tv_sec) + TimeInterval(usage.ru_stime.tv_usec) / 1_000_000

        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<Int32>.size)
        let kernStatus = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }

        let resident = kernStatus == KERN_SUCCESS ? Int(info.resident_size) : 0
        let virtual = kernStatus == KERN_SUCCESS ? Int(info.virtual_size) : 0

        let rawMaxRSS = Int(usage.ru_maxrss)
        let maxRSSBytes: Int
        if rawMaxRSS == 0 {
            maxRSSBytes = resident
        } else if resident > 0, rawMaxRSS > 0, rawMaxRSS < resident / 2 {
            maxRSSBytes = rawMaxRSS * 1024
        } else {
            maxRSSBytes = rawMaxRSS
        }

        return ResourceSample(
            userTime: user,
            systemTime: system,
            residentSize: resident,
            virtualSize: virtual,
            maxResidentSize: maxRSSBytes
        )
    }

    private static func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private func makeReport(
        finishTime: TimeInterval,
        finishSample: ResourceSample?,
        cancelled: Bool,
        finalRowCount: Int,
        estimatedMemoryBytes: Int?
    ) -> Report {
        let resolvedFinishTimestamp = finishTimestamp ?? finishTime
        let timings = Report.Timings(
            startToDispatch: delta(from: startTimestamp, to: dispatchTimestamp),
            dispatchToFirstUpdate: delta(from: dispatchTimestamp, to: firstUpdateTimestamp),
            startToFirstUpdate: delta(from: startTimestamp, to: firstUpdateTimestamp),
            startToInitialBatch: delta(from: startTimestamp, to: initialBatchTimestamp),
            firstUpdateToInitialBatch: delta(from: firstUpdateTimestamp, to: initialBatchTimestamp),
            startToResultSet: delta(from: startTimestamp, to: resultSetTimestamp),
            resultSetToFinish: delta(from: resultSetTimestamp, to: resolvedFinishTimestamp),
            startToFinish: delta(from: startTimestamp, to: resolvedFinishTimestamp),
            startToFirstTableReload: delta(from: startTimestamp, to: firstTableReloadTimestamp),
            firstUpdateToFirstTableReload: delta(from: firstUpdateTimestamp, to: firstTableReloadTimestamp),
            startToVisibleInitialLimit: delta(from: startTimestamp, to: visibleInitialLimitTimestamp),
            firstUpdateToVisibleInitialLimit: delta(from: firstUpdateTimestamp, to: visibleInitialLimitTimestamp)
        )

        let cpuUserDelta = delta(from: dispatchSample?.userTime, to: finishSample?.userTime)
        let cpuSystemDelta = delta(from: dispatchSample?.systemTime, to: finishSample?.systemTime)
        let residentBytes = finishSample?.residentSize
        let residentDelta = difference(finishSample?.residentSize, from: dispatchSample?.residentSize)
        let virtualBytes = finishSample?.virtualSize
        let maxResident = max(dispatchSample?.maxResidentSize ?? 0, finishSample?.maxResidentSize ?? 0)

        return Report(
            timings: timings,
            totalRows: max(self.finalRowCount, totalRows, finalRowCount),
            batchCount: batchSizes.count,
            firstBatchSize: firstBatchSize,
            largestBatchSize: largestBatchSize,
            batchSizes: batchSizes,
            initialBatchTarget: initialBatchTarget,
            cancelled: cancelled,
            estimatedMemoryBytes: estimatedMemoryBytes,
            cpuUserSeconds: cpuUserDelta,
            cpuSystemSeconds: cpuSystemDelta,
            residentMemoryBytes: residentBytes,
            residentMemoryDeltaBytes: residentDelta,
            virtualMemoryBytes: virtualBytes,
            maxResidentMemoryBytes: maxResident > 0 ? maxResident : nil,
            timeline: timeline,
            backendSamples: backendSamples
        )
    }

    private func difference(_ end: Int?, from start: Int?) -> Int? {
        guard let end, let start else { return nil }
        return end - start
    }

    private func delta(from start: TimeInterval?, to end: TimeInterval?) -> TimeInterval? {
        guard let start, let end else { return nil }
        return max(0, end - start)
    }
}
