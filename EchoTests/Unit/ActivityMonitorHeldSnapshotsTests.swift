import Foundation
import Testing
@testable import Echo

/// A monitor that never sends anything by itself; the tests hand snapshots in.
private struct SilentActivityMonitor: DatabaseActivityMonitoring {
    func snapshot() async throws -> DatabaseActivitySnapshot { throw CancellationError() }
    func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error> {
        AsyncThrowingStream { _ in }
    }
    func killSession(id: Int) async throws {}
}

@MainActor
@Suite("Activity monitor while its tab is hidden")
struct ActivityMonitorHeldSnapshotsTests {
    private func makeViewModel() -> ActivityMonitorViewModel {
        ActivityMonitorViewModel(monitor: SilentActivityMonitor(), connectionSessionID: UUID(), connectionID: UUID(), databaseType: .mysql)
    }

    private func snapshot(at seconds: TimeInterval) -> DatabaseActivitySnapshot {
        .mysql(MySQLActivitySnapshot(capturedAt: Date(timeIntervalSince1970: seconds), processes: [], globalVariables: [], overview: nil))
    }

    @Test func showsSnapshotsAtOnceWhileShown() {
        let viewModel = makeViewModel()
        viewModel.receive(snapshot(at: 1))
        #expect(viewModel.latestSnapshot?.capturedAt == Date(timeIntervalSince1970: 1))
        #expect(viewModel.connectionCountHistory.count == 1)
    }

    @Test func holdsSnapshotsWhileHiddenAndAppliesThemWhenShown() {
        let viewModel = makeViewModel()
        viewModel.setShown(false)
        viewModel.receive(snapshot(at: 1))
        viewModel.receive(snapshot(at: 2))
        #expect(viewModel.latestSnapshot == nil)
        #expect(viewModel.connectionCountHistory.isEmpty)

        viewModel.setShown(true)
        #expect(viewModel.latestSnapshot?.capturedAt == Date(timeIntervalSince1970: 2))
        #expect(viewModel.connectionCountHistory.count == 2)
    }

    @Test func keepsAtMostAHistoryOfHeldSnapshots() {
        let viewModel = makeViewModel()
        viewModel.setShown(false)
        for second in 0..<(viewModel.maxHistoryItems + 10) { viewModel.receive(snapshot(at: TimeInterval(second))) }
        #expect(viewModel.heldSnapshots.count == viewModel.maxHistoryItems)
    }
}
