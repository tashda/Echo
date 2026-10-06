import Foundation
import Testing
@testable import Echo

/// A monitor that records the rate each of its streams was asked for.
private final class RecordingActivityMonitor: DatabaseActivityMonitoring, @unchecked Sendable {
    private(set) var rates: [TimeInterval] = []
    func snapshot() async throws -> DatabaseActivitySnapshot { throw CancellationError() }
    func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error> {
        rates.append(seconds)
        return AsyncThrowingStream { _ in }
    }
    func killSession(id: Int) async throws {}
}

@Suite("Activity monitor polling rate")
struct ActivityMonitorPollingTests {
    @Test func aShownMonitorPollsAtTheChosenRate() {
        #expect(ActivityMonitorPolling.interval(selected: 2, isShown: true, slowsWhenHidden: true) == 2)
    }

    @Test func aHiddenMonitorPollsAMinuteApartUnlessSettingsSaysOtherwise() {
        #expect(ActivityMonitorPolling.interval(selected: 5, isShown: false, slowsWhenHidden: true) == 60)
        #expect(ActivityMonitorPolling.interval(selected: 5, isShown: false, slowsWhenHidden: false) == 5)
    }

    @Test func aRateSlowerThanAMinuteIsLeftAlone() {
        #expect(ActivityMonitorPolling.interval(selected: 120, isShown: false, slowsWhenHidden: true) == 120)
    }

    @MainActor @Test func hidingAndShowingRestartsTheStreamAtTheNewRate() async throws {
        let monitor = RecordingActivityMonitor()
        let viewModel = ActivityMonitorViewModel(monitor: monitor, connectionSessionID: UUID(), connectionID: UUID(), databaseType: .mysql, refreshInterval: 5)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.setShown(false)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.setShown(true)
        try await Task.sleep(for: .milliseconds(100))
        #expect(monitor.rates == [5, 60, 5])
    }

    @MainActor @Test func keepingTheChosenRateNeverRestartsTheStream() async throws {
        let monitor = RecordingActivityMonitor()
        let viewModel = ActivityMonitorViewModel(monitor: monitor, connectionSessionID: UUID(), connectionID: UUID(), databaseType: .mysql, refreshInterval: 5)
        viewModel.slowsWhenHidden = false
        try await Task.sleep(for: .milliseconds(100))
        viewModel.setShown(false)
        viewModel.setShown(true)
        try await Task.sleep(for: .milliseconds(100))
        #expect(monitor.rates == [5])
    }

    @MainActor @Test func aPausedMonitorStaysPaused() async throws {
        let monitor = RecordingActivityMonitor()
        let viewModel = ActivityMonitorViewModel(monitor: monitor, connectionSessionID: UUID(), connectionID: UUID(), databaseType: .mysql, refreshInterval: 5)
        try await Task.sleep(for: .milliseconds(100))
        viewModel.stopStreaming()
        viewModel.setShown(false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(monitor.rates == [5])
    }

    @Test func settingsSavedBeforeTheOptionExistedSlowDownHiddenMonitors() throws {
        let data = try JSONEncoder().encode(GlobalSettings())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "activityMonitorSlowsWhenHidden")
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.activityMonitorSlowsWhenHidden)
    }
}
