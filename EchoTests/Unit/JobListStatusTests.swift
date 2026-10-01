import Foundation
import Testing
@testable import Echo

/// The jobs list's Status column (round 33, JC1 and JR1).
@MainActor
struct JobListStatusTests {
    private func job(_ name: String, enabled: Bool = true, outcome: String? = "Succeeded") -> JobQueueViewModel.JobRow {
        .init(id: name, name: name, enabled: enabled, category: nil, owner: nil, lastOutcome: outcome, lastRunDate: nil, nextRun: nil)
    }

    private func status(_ row: JobQueueViewModel.JobRow, running: Set<String> = [], starts: [String: Date] = [:]) -> JobQueueViewModel.JobListStatus {
        JobQueueViewModel.listStatus(for: row, runningNames: running, startDates: starts)
    }

    @Test func anEnabledJobThatSucceededIsReady() {
        #expect(status(job("Backup")) == .ready)
        #expect(status(job("Backup", outcome: nil)) == .ready)
    }

    @Test func aFailedLastRunShowsFailed() {
        #expect(status(job("Backup", outcome: "Failed")) == .failed)
    }

    @Test func aDisabledJobShowsDisabledEvenAfterAFailure() {
        #expect(status(job("Backup", enabled: false, outcome: "Failed")) == .disabled)
    }

    @Test func aRunningJobCarriesItsStartTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(status(job("Backup", outcome: "Failed"), running: ["Backup"], starts: ["Backup": start]) == .running(since: start))
        #expect(status(job("Backup"), running: ["Backup"]) == .running(since: nil))
    }

    @Test func runningSortsFirstAndDisabledLast() {
        let ranks = [JobQueueViewModel.JobListStatus.running(since: nil), .failed, .ready, .disabled].map(\.sortRank)
        #expect(ranks == ranks.sorted())
        #expect(JobQueueViewModel.JobListStatus.running(since: nil).isRunning)
        #expect(!JobQueueViewModel.JobListStatus.failed.isRunning)
    }
}
