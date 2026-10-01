import Foundation

extension JobQueueViewModel {
    /// What the jobs list's Status column shows for a job (round 33, JC1 and JR1): one symbol
    /// for running, disabled, failed or ready, in that order of precedence.
    enum JobListStatus: Equatable {
        /// Running now; `since` is when it started, if the Agent reported it.
        case running(since: Date?)
        case failed
        case disabled
        case ready

        /// Sorts running first, then failed, ready and disabled.
        var sortRank: Int {
            switch self {
            case .running: 0
            case .failed: 1
            case .ready: 2
            case .disabled: 3
            }
        }

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    func listStatus(for job: JobRow) -> JobListStatus {
        Self.listStatus(for: job, runningNames: runningJobNames, startDates: runningJobStartDates)
    }

    static func listStatus(for job: JobRow, runningNames: Set<String>, startDates: [String: Date]) -> JobListStatus {
        if runningNames.contains(job.name) { return .running(since: startDates[job.name]) }
        if !job.enabled { return .disabled }
        if job.lastOutcome == "Failed" { return .failed }
        return .ready
    }
}
