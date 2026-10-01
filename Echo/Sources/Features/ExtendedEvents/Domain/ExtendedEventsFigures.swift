import Foundation
import SwiftUI
import SQLServerKit

/// Extended Events' figures as Monitor tiles (round 37.4, MO0): the sessions, how many run, and
/// the selected session's captured events in ten-second stretches.
nonisolated enum ExtendedEventsFigures {
    /// Captured events per ten-second stretch, oldest first, empty stretches kept, at most thirty.
    static func eventCounts(_ events: [SQLServerXEEventData]) -> [(start: Date, count: Int)] {
        let bucket = ProfilerFigures.bucket
        var counts: [Date: Int] = [:]
        for time in events.compactMap(\.timestamp) {
            let start = Date(timeIntervalSinceReferenceDate: (time.timeIntervalSinceReferenceDate / bucket).rounded(.down) * bucket)
            counts[start, default: 0] += 1
        }
        guard let first = counts.keys.min(), let last = counts.keys.max() else { return [] }
        let total = Int(last.timeIntervalSince(first) / bucket) + 1
        return (max(0, total - ProfilerFigures.bucketsShown)..<total).map { index in
            let start = first.addingTimeInterval(Double(index) * bucket)
            return (start, counts[start] ?? 0)
        }
    }
}

extension ExtendedEventsFigures {
    @MainActor
    static func metrics(sessions: [SQLServerXESession], events: [SQLServerXEEventData], now: Date = Date()) -> [SparklineMetric] {
        func single(_ value: Int) -> [ActivityMonitorViewModel.GraphPoint] { [.init(timestamp: now, value: Double(value))] }
        let stretches = eventCounts(events).map { ActivityMonitorViewModel.GraphPoint(timestamp: $0.start, value: Double($0.count)) }
        return [
            SparklineMetric(label: "Sessions", unit: "", color: ColorTokens.accent, maxValue: nil, data: single(sessions.count)),
            SparklineMetric(label: "Running", unit: "", color: ColorTokens.Status.success, maxValue: nil,
                            data: single(sessions.filter(\.isRunning).count)),
            SparklineMetric(label: "Events", unit: " per 10 s", color: ColorTokens.Status.info, maxValue: nil, data: stretches),
            SparklineMetric(label: "Event types", unit: "", color: ColorTokens.Status.warning, maxValue: nil,
                            data: single(Set(events.map(\.eventName)).count)),
        ]
    }
}
