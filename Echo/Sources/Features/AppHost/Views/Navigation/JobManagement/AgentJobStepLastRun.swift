import Foundation

/// The line under Edit Step's title (round 33.2, ES1): "Last run 26 Sep 23:00 · Succeeded · 14 min",
/// from the job's history rows for that step.
enum AgentJobStepLastRun {
    static func line(stepID: Int, history: [JobQueueViewModel.HistoryRow], locale: Locale = .current, timeZone: TimeZone = .current) -> String? {
        let runs = history.filter { $0.stepId == stepID }
        guard let latest = runs.max(by: { $0.runDateTimeSortKey < $1.runDateTimeSortKey }) else { return nil }
        guard let date = date(runDate: latest.runDate, runTime: latest.runTime, timeZone: timeZone) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMMHHmm")
        return "Last run \(formatter.string(from: date)) · \(latest.statusLabel) · \(duration(latest.runDuration))"
    }

    /// SQL Agent's HHMMSS duration as "42 s", "14 min" or "1 h 12 min".
    static func duration(_ runDuration: Int) -> String {
        let hours = runDuration / 10_000
        let minutes = (runDuration / 100) % 100
        let seconds = runDuration % 100
        if hours > 0 { return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds) s"
    }

    static func date(runDate: Int, runTime: Int, timeZone: TimeZone) -> Date? {
        guard runDate > 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: runDate / 10_000, month: (runDate / 100) % 100, day: runDate % 100,
                                        hour: runTime / 10_000, minute: (runTime / 100) % 100, second: runTime % 100)
        return calendar.date(from: components)
    }
}
