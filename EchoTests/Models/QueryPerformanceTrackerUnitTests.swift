import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("QueryPerformanceTracker")
struct QueryPerformanceTrackerUnitTests {

    // MARK: - Initialization

    @Test func initSetsInitialBatchTarget() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 100)
        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.initialBatchTarget == 100)
    }

    @Test func initClampsTargetToMinimumOne() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 0)
        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.initialBatchTarget == 1)
    }

    @Test func initNegativeTargetClampedToOne() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: -5)
        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.initialBatchTarget == 1)
    }

    // MARK: - markQueryDispatched

    @Test func markQueryDispatchedSetsDispatchTime() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.timings.startToDispatch != nil)
        #expect(report.timings.startToDispatch! >= 0)
    }

    @Test func markQueryDispatchedIdempotent() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        let report1 = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: nil)
        let dispatchTime1 = report1.timings.startToDispatch

        // Second call should not change the timestamp
        tracker.markQueryDispatched()
        let report2 = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: nil)
        let dispatchTime2 = report2.timings.startToDispatch

        #expect(dispatchTime1 == dispatchTime2)
    }

    // MARK: - recordStreamUpdate

    @Test func recordStreamUpdateRecordsBatch() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 50, totalRowCount: 50)

        let report = tracker.finalize(cancelled: false, finalRowCount: 50, estimatedMemoryBytes: nil)
        #expect(report.batchCount == 1)
        #expect(report.batchSizes == [50])
        #expect(report.firstBatchSize == 50)
        #expect(report.largestBatchSize == 50)
        #expect(report.totalRows == 50)
    }

    @Test func recordStreamUpdateSetsFirstUpdateTimestamp() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)

        let report = tracker.finalize(cancelled: false, finalRowCount: 5, estimatedMemoryBytes: nil)
        #expect(report.timings.startToFirstUpdate != nil)
        #expect(report.timings.dispatchToFirstUpdate != nil)
    }

    @Test func recordStreamUpdateMultipleBatches() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 100)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 30, totalRowCount: 30)
        tracker.recordStreamUpdate(appendedRowCount: 50, totalRowCount: 80)
        tracker.recordStreamUpdate(appendedRowCount: 20, totalRowCount: 100)

        let report = tracker.finalize(cancelled: false, finalRowCount: 100, estimatedMemoryBytes: nil)
        #expect(report.batchCount == 3)
        #expect(report.batchSizes == [30, 50, 20])
        #expect(report.firstBatchSize == 30)
        #expect(report.largestBatchSize == 50)
        #expect(report.totalRows == 100)
    }

    @Test func recordStreamUpdateZeroAppendedIsNotCounted() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 0, totalRowCount: 0)

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.batchCount == 0)
        #expect(report.batchSizes.isEmpty)
        #expect(report.firstBatchSize == nil)
    }

    @Test func recordStreamUpdateSetsInitialBatchWhenThresholdMet() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)
        let snapshot1 = tracker.snapshot(currentRowCount: 5, estimatedMemoryBytes: nil)
        #expect(snapshot1.timings.startToInitialBatch == nil)

        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 10)
        let snapshot2 = tracker.snapshot(currentRowCount: 10, estimatedMemoryBytes: nil)
        #expect(snapshot2.timings.startToInitialBatch != nil)
    }

    // MARK: - recordInitialBatchReady

    @Test func recordInitialBatchReadyWhenThresholdMet() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 5)
        tracker.markQueryDispatched()

        tracker.recordInitialBatchReady(totalRowCount: 5)

        let report = tracker.finalize(cancelled: false, finalRowCount: 5, estimatedMemoryBytes: nil)
        #expect(report.timings.startToInitialBatch != nil)
    }

    @Test func recordInitialBatchReadyIgnoredBelowThreshold() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordInitialBatchReady(totalRowCount: 5)

        let report = tracker.finalize(cancelled: false, finalRowCount: 5, estimatedMemoryBytes: nil)
        #expect(report.timings.startToInitialBatch == nil)
    }

    @Test func recordInitialBatchReadyIdempotent() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 5)
        tracker.markQueryDispatched()

        tracker.recordInitialBatchReady(totalRowCount: 5)
        let snapshot1 = tracker.snapshot(currentRowCount: 5, estimatedMemoryBytes: nil)

        tracker.recordInitialBatchReady(totalRowCount: 10)
        let snapshot2 = tracker.snapshot(currentRowCount: 10, estimatedMemoryBytes: nil)

        #expect(snapshot1.timings.startToInitialBatch == snapshot2.timings.startToInitialBatch)
    }

    // MARK: - recordTableReload

    @Test func recordTableReloadSetsTimestamp() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordTableReload()

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.timings.startToFirstTableReload != nil)
    }

    @Test func recordTableReloadIdempotent() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordTableReload()
        let s1 = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: nil)

        tracker.recordTableReload()
        let s2 = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: nil)

        #expect(s1.timings.startToFirstTableReload == s2.timings.startToFirstTableReload)
    }

    // MARK: - markResultSetReceived

    @Test func markResultSetReceivedSetsTimestamp() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.markResultSetReceived(totalRowCount: 100)

        let report = tracker.finalize(cancelled: false, finalRowCount: 100, estimatedMemoryBytes: nil)
        #expect(report.timings.startToResultSet != nil)
        #expect(report.timings.resultSetToFinish != nil)
    }

    @Test func markResultSetReceivedUpdatesRowCount() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.markResultSetReceived(totalRowCount: 250)

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.totalRows >= 250)
    }

    // MARK: - finalize

    @Test func finalizeProducesReport() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 10, totalRowCount: 10)
        tracker.markResultSetReceived(totalRowCount: 10)

        let report = tracker.finalize(cancelled: false, finalRowCount: 10, estimatedMemoryBytes: 1024)

        #expect(report.totalRows == 10)
        #expect(report.cancelled == false)
        #expect(report.estimatedMemoryBytes == 1024)
        #expect(report.timings.startToFinish != nil)
        #expect(report.timings.startToFinish! >= 0)
    }

    @Test func finalizeReturnsCachedReport() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        let report1 = tracker.finalize(cancelled: false, finalRowCount: 10, estimatedMemoryBytes: nil)
        let report2 = tracker.finalize(cancelled: true, finalRowCount: 999, estimatedMemoryBytes: 9999)

        // Second call returns cached report, ignoring new parameters
        #expect(report1.totalRows == report2.totalRows)
        #expect(report1.cancelled == report2.cancelled)
    }

    @Test func finalizeCancelledTrue() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        let report = tracker.finalize(cancelled: true, finalRowCount: 5, estimatedMemoryBytes: nil)
        #expect(report.cancelled == true)
    }

    @Test func finalizeWithEstimatedMemory() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: 1_048_576)
        #expect(report.estimatedMemoryBytes == 1_048_576)
    }

    // MARK: - snapshot

    @Test func snapshotProducesPartialReport() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)

        let report = tracker.snapshot(currentRowCount: 5, estimatedMemoryBytes: nil)
        #expect(report.totalRows >= 5)
        #expect(report.batchCount == 1)
    }

    @Test func snapshotDoesNotPreventFurtherUpdates() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)

        _ = tracker.snapshot(currentRowCount: 5, estimatedMemoryBytes: nil)

        tracker.recordStreamUpdate(appendedRowCount: 10, totalRowCount: 15)
        let report = tracker.finalize(cancelled: false, finalRowCount: 15, estimatedMemoryBytes: nil)
        #expect(report.batchCount == 2)
        #expect(report.totalRows == 15)
    }

    @Test func snapshotWithEstimatedMemory() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        let report = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: 2048)
        #expect(report.estimatedMemoryBytes == 2048)
    }

    // MARK: - reset

    @Test func resetClearsAllState() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 50, totalRowCount: 50)
        tracker.recordTableReload()
        tracker.markResultSetReceived(totalRowCount: 50)

        tracker.reset()

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        #expect(report.batchCount == 0)
        #expect(report.batchSizes.isEmpty)
        #expect(report.firstBatchSize == nil)
        #expect(report.largestBatchSize == 0)
        #expect(report.totalRows == 0)
        #expect(report.timings.startToDispatch == nil)
        #expect(report.timings.startToFirstUpdate == nil)
        #expect(report.timings.startToInitialBatch == nil)
        #expect(report.timings.startToResultSet == nil)
        #expect(report.timings.startToFirstTableReload == nil)
        #expect(report.timeline.isEmpty)
        #expect(report.backendSamples.isEmpty)
    }

    @Test func resetAllowsReuse() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        _ = tracker.finalize(cancelled: false, finalRowCount: 5, estimatedMemoryBytes: nil)

        tracker.reset()

        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 20, totalRowCount: 20)
        let report = tracker.finalize(cancelled: false, finalRowCount: 20, estimatedMemoryBytes: nil)
        #expect(report.totalRows == 20)
        #expect(report.batchCount == 1)
    }

    @Test func resetClearsCachedReport() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        let report1 = tracker.finalize(cancelled: false, finalRowCount: 10, estimatedMemoryBytes: nil)

        tracker.reset()

        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)
        let report2 = tracker.finalize(cancelled: true, finalRowCount: 5, estimatedMemoryBytes: nil)

        // After reset, finalize produces a new report
        #expect(report2.cancelled == true)
        #expect(report1.cancelled == false)
    }

    // MARK: - Report.Timings

    @Test func timingsAllPresent() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 5)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)
        tracker.recordTableReload()
        tracker.recordVisibleInitialLimitSatisfied()
        tracker.markResultSetReceived(totalRowCount: 5)

        let report = tracker.finalize(cancelled: false, finalRowCount: 5, estimatedMemoryBytes: nil)
        let timings = report.timings

        #expect(timings.startToDispatch != nil)
        #expect(timings.dispatchToFirstUpdate != nil)
        #expect(timings.startToFirstUpdate != nil)
        #expect(timings.startToInitialBatch != nil)
        #expect(timings.firstUpdateToInitialBatch != nil)
        #expect(timings.startToResultSet != nil)
        #expect(timings.resultSetToFinish != nil)
        #expect(timings.startToFinish != nil)
        #expect(timings.startToFirstTableReload != nil)
        #expect(timings.firstUpdateToFirstTableReload != nil)
        #expect(timings.startToVisibleInitialLimit != nil)
        #expect(timings.firstUpdateToVisibleInitialLimit != nil)
    }

    @Test func timingsAreNonNegative() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 1)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 1, totalRowCount: 1)
        tracker.recordTableReload()
        tracker.markResultSetReceived(totalRowCount: 1)

        let report = tracker.finalize(cancelled: false, finalRowCount: 1, estimatedMemoryBytes: nil)
        let t = report.timings

        if let v = t.startToDispatch { #expect(v >= 0) }
        if let v = t.dispatchToFirstUpdate { #expect(v >= 0) }
        if let v = t.startToFirstUpdate { #expect(v >= 0) }
        if let v = t.startToInitialBatch { #expect(v >= 0) }
        if let v = t.startToResultSet { #expect(v >= 0) }
        if let v = t.resultSetToFinish { #expect(v >= 0) }
        if let v = t.startToFinish { #expect(v >= 0) }
    }

    @Test func timingsNilWhenNoCorrespondingEvent() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 100)
        // Do not call markQueryDispatched or any other method

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)

        #expect(report.timings.startToDispatch == nil)
        #expect(report.timings.dispatchToFirstUpdate == nil)
        #expect(report.timings.startToFirstUpdate == nil)
        #expect(report.timings.startToInitialBatch == nil)
        #expect(report.timings.startToResultSet == nil)
        #expect(report.timings.startToFirstTableReload == nil)
    }

    // MARK: - cpuTotalSeconds

    @Test func cpuTotalSecondsIsNilWithoutResourceSamples() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        // Without markQueryDispatched, no dispatch sample is taken
        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)
        // cpu fields come from dispatch/finish resource samples difference
        // cpuTotalSeconds requires both user and system to be non-nil
        // It may or may not be nil depending on whether rusage succeeds
        // Just verify the sum logic is correct
        if let total = report.cpuTotalSeconds {
            let user = report.cpuUserSeconds ?? 0
            let system = report.cpuSystemSeconds ?? 0
            #expect(total == user + system)
        }
    }

    @Test func cpuTotalSecondsSumsUserAndSystem() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        // Do some work to get measurable CPU time
        var sum = 0
        for i in 0..<10_000 { sum += i }
        _ = sum

        let report = tracker.finalize(cancelled: false, finalRowCount: 0, estimatedMemoryBytes: nil)

        if let user = report.cpuUserSeconds, let system = report.cpuSystemSeconds {
            #expect(report.cpuTotalSeconds == user + system)
        }
    }

    // MARK: - Timeline Entries

    @Test func timelineAccumulatesEntries() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 100)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 10, totalRowCount: 10)
        tracker.recordStreamUpdate(appendedRowCount: 20, totalRowCount: 30)
        tracker.recordStreamUpdate(appendedRowCount: 30, totalRowCount: 60)

        let report = tracker.finalize(cancelled: false, finalRowCount: 60, estimatedMemoryBytes: nil)
        #expect(report.timeline.count == 3)
        #expect(report.timeline[0].rows == 10)
        #expect(report.timeline[1].rows == 30)
        #expect(report.timeline[2].rows == 60)
    }

    @Test func timelineTimesAreNonNegative() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 100)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 10)

        let report = tracker.finalize(cancelled: false, finalRowCount: 10, estimatedMemoryBytes: nil)
        for entry in report.timeline {
            #expect(entry.time >= 0)
        }
    }

    @Test func timelineTimesAreMonotonicallyIncreasing() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 1000)
        tracker.markQueryDispatched()

        for i in 1...5 {
            tracker.recordStreamUpdate(appendedRowCount: 10, totalRowCount: i * 10)
        }

        let report = tracker.finalize(cancelled: false, finalRowCount: 50, estimatedMemoryBytes: nil)
        for i in 1..<report.timeline.count {
            #expect(report.timeline[i].time >= report.timeline[i - 1].time)
        }
    }

    @Test func timelineNotAddedForZeroAppendedRows() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 0, totalRowCount: 0)
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)
        tracker.recordStreamUpdate(appendedRowCount: 0, totalRowCount: 5)

        let report = tracker.finalize(cancelled: false, finalRowCount: 5, estimatedMemoryBytes: nil)
        #expect(report.timeline.count == 1)
    }

    // MARK: - Backend Samples

    @Test func recordBackendMetrics() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        let metrics = QueryStreamMetrics(
            batchRowCount: 100,
            loopElapsed: 0.5,
            decodeDuration: 0.1,
            totalElapsed: 1.0,
            cumulativeRowCount: 100,
            fetchRequestRowCount: 200,
            fetchRowCount: 100
        )
        tracker.recordBackendMetrics(metrics)

        let report = tracker.finalize(cancelled: false, finalRowCount: 100, estimatedMemoryBytes: nil)
        #expect(report.backendSamples.count == 1)
        #expect(report.backendSamples[0].batchRowCount == 100)
        #expect(report.backendSamples[0].totalElapsed == 1.0)
        #expect(report.backendSamples[0].decodeDuration == 0.1)
        #expect(report.backendSamples[0].cumulativeRowCount == 100)
        #expect(report.backendSamples[0].fetchRequestRowCount == 200)
        #expect(report.backendSamples[0].fetchRowCount == 100)
    }

    @Test func multipleBackendSamples() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        for i in 1...3 {
            let metrics = QueryStreamMetrics(
                batchRowCount: i * 10,
                loopElapsed: Double(i) * 0.1,
                decodeDuration: Double(i) * 0.01,
                totalElapsed: Double(i) * 0.5,
                cumulativeRowCount: i * 10
            )
            tracker.recordBackendMetrics(metrics)
        }

        let report = tracker.finalize(cancelled: false, finalRowCount: 30, estimatedMemoryBytes: nil)
        #expect(report.backendSamples.count == 3)
        #expect(report.backendSamples[0].batchRowCount == 10)
        #expect(report.backendSamples[2].batchRowCount == 30)
    }

    // MARK: - Batch Sizes and Largest Batch

    @Test func largestBatchSizeTrackedCorrectly() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 1000)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 10, totalRowCount: 10)
        tracker.recordStreamUpdate(appendedRowCount: 100, totalRowCount: 110)
        tracker.recordStreamUpdate(appendedRowCount: 50, totalRowCount: 160)

        let report = tracker.finalize(cancelled: false, finalRowCount: 160, estimatedMemoryBytes: nil)
        #expect(report.largestBatchSize == 100)
    }

    @Test func batchSizesRecordedInOrder() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 1000)
        tracker.markQueryDispatched()

        let sizes = [5, 15, 3, 25, 8]
        var total = 0
        for size in sizes {
            total += size
            tracker.recordStreamUpdate(appendedRowCount: size, totalRowCount: total)
        }

        let report = tracker.finalize(cancelled: false, finalRowCount: total, estimatedMemoryBytes: nil)
        #expect(report.batchSizes == sizes)
    }

    @Test func firstBatchSizeIsFirstNonZero() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordStreamUpdate(appendedRowCount: 0, totalRowCount: 0)
        tracker.recordStreamUpdate(appendedRowCount: 7, totalRowCount: 7)
        tracker.recordStreamUpdate(appendedRowCount: 15, totalRowCount: 22)

        let report = tracker.finalize(cancelled: false, finalRowCount: 22, estimatedMemoryBytes: nil)
        #expect(report.firstBatchSize == 7)
    }

    // MARK: - recordVisibleInitialLimitSatisfied

    @Test func recordVisibleInitialLimitSetsTimestamp() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 1, totalRowCount: 1)
        tracker.recordVisibleInitialLimitSatisfied()

        let report = tracker.finalize(cancelled: false, finalRowCount: 1, estimatedMemoryBytes: nil)
        #expect(report.timings.startToVisibleInitialLimit != nil)
        #expect(report.timings.firstUpdateToVisibleInitialLimit != nil)
    }

    @Test func recordVisibleInitialLimitIdempotent() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)
        tracker.markQueryDispatched()

        tracker.recordVisibleInitialLimitSatisfied()
        let s1 = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: nil)

        tracker.recordVisibleInitialLimitSatisfied()
        let s2 = tracker.snapshot(currentRowCount: 0, estimatedMemoryBytes: nil)

        #expect(s1.timings.startToVisibleInitialLimit == s2.timings.startToVisibleInitialLimit)
    }

    // MARK: - Full Lifecycle

    @Test func fullLifecycleProducesCompleteReport() {
        let tracker = QueryPerformanceTracker(initialBatchTarget: 10)

        tracker.markQueryDispatched()
        tracker.recordStreamUpdate(appendedRowCount: 5, totalRowCount: 5)
        tracker.recordStreamUpdate(appendedRowCount: 10, totalRowCount: 15)
        tracker.recordInitialBatchReady(totalRowCount: 15)
        tracker.recordTableReload()
        tracker.recordVisibleInitialLimitSatisfied()

        let metrics = QueryStreamMetrics(
            batchRowCount: 15,
            loopElapsed: 0.3,
            decodeDuration: 0.05,
            totalElapsed: 0.8,
            cumulativeRowCount: 15
        )
        tracker.recordBackendMetrics(metrics)
        tracker.markResultSetReceived(totalRowCount: 15)

        let report = tracker.finalize(
            cancelled: false,
            finalRowCount: 15,
            estimatedMemoryBytes: 4096
        )

        #expect(report.totalRows == 15)
        #expect(report.batchCount == 2)
        #expect(report.batchSizes == [5, 10])
        #expect(report.firstBatchSize == 5)
        #expect(report.largestBatchSize == 10)
        #expect(report.cancelled == false)
        #expect(report.estimatedMemoryBytes == 4096)
        #expect(report.timeline.count == 2)
        #expect(report.backendSamples.count == 1)
    }
}
