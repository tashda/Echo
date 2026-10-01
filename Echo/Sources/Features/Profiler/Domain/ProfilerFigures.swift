import Foundation
import SwiftUI
import SQLServerKit

/// SQL Profiler's figures as Monitor tiles (round 37.4, MO0): events, average duration, CPU and
/// reads in each ten-second stretch of the trace, the latest stretch shown large.
nonisolated enum ProfilerFigures {
    static let bucket: TimeInterval = 10
    static let bucketsShown = 30

    struct Bucket: Equatable {
        let start: Date
        var events = 0
        var durationTotal: Double = 0
        var durations = 0
        var cpu: Double = 0
        var reads: Double = 0

        var averageDuration: Double { durations == 0 ? 0 : durationTotal / Double(durations) }
    }

    /// The trace in ten-second stretches, oldest first, with empty stretches between events kept,
    /// at most the last thirty.
    static func buckets(for events: [SQLServerProfilerEvent]) -> [Bucket] {
        var byStart: [Date: Bucket] = [:]
        for event in events {
            guard let time = event.timestamp else { continue }
            let start = Date(timeIntervalSinceReferenceDate: (time.timeIntervalSinceReferenceDate / bucket).rounded(.down) * bucket)
            var entry = byStart[start] ?? Bucket(start: start)
            entry.events += 1
            if let duration = event.duration { entry.durationTotal += Double(duration); entry.durations += 1 }
            entry.cpu += Double(event.cpu ?? 0)
            entry.reads += Double(event.reads ?? 0)
            byStart[start] = entry
        }
        guard let first = byStart.keys.min(), let last = byStart.keys.max() else { return [] }
        let count = Int(last.timeIntervalSince(first) / bucket) + 1
        let from = max(0, count - bucketsShown)
        return (from..<count).map { index in
            let start = first.addingTimeInterval(Double(index) * bucket)
            return byStart[start] ?? Bucket(start: start)
        }
    }
}

extension ProfilerFigures {
    @MainActor
    static func metrics(for events: [SQLServerProfilerEvent]) -> [SparklineMetric] {
        let stretches = buckets(for: events)
        func points(_ value: (Bucket) -> Double) -> [ActivityMonitorViewModel.GraphPoint] {
            stretches.map { .init(timestamp: $0.start, value: value($0)) }
        }
        return [
            SparklineMetric(label: "Events", unit: " per 10 s", color: ColorTokens.Status.info, maxValue: nil, data: points { Double($0.events) }),
            SparklineMetric(label: "Duration", unit: " ms avg", color: ColorTokens.accent, maxValue: nil, data: points(\.averageDuration)),
            SparklineMetric(label: "CPU", unit: " ms", color: ColorTokens.Status.warning, maxValue: nil, data: points(\.cpu)),
            SparklineMetric(label: "Reads", unit: "", color: ColorTokens.Status.success, maxValue: nil, data: points(\.reads)),
        ]
    }
}
