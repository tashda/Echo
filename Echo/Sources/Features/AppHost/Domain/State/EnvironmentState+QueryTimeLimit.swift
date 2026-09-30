import Foundation

/// The query time limit (Echo Labs round 21, timeouts, accepted): a default in Settings, which a
/// connection can override (TW2); no limit unless set (TD2). SQL Server applies the same value as
/// its request deadline (round 22, TO1).
extension EnvironmentState {
    /// The limit for `connection` in seconds and whose it is; nil when there is none.
    func queryTimeLimit(for connection: SavedConnection) -> (seconds: TimeInterval, scope: QueryTimeLimitScope)? {
        if let override = connection.queryTimeLimit {
            return override > 0 ? (override, .connection) : nil
        }
        let seconds = projectStore.globalSettings.queryTimeLimitSeconds
        return seconds > 0 ? (TimeInterval(seconds), .settings) : nil
    }

    /// Once, the first time a query runs after the update (M3): the old 60 s field never did anything,
    /// every connection now uses the Settings default, and the limit works.
    func announceQueryTimeLimitsOnce() {
        guard !projectStore.globalSettings.queryTimeLimitNoticeShown else { return }
        var updated = projectStore.globalSettings
        updated.queryTimeLimitNoticeShown = true
        Task { try? await projectStore.updateGlobalSettings(updated) }
        notificationEngine?.post(
            category: .generalInfo,
            icon: "timer",
            message: "Query time limits now work: the old Query Timeout (60 s) was never applied, so every connection now uses Settings › Databases › Query time limit, which is no limit until you set one. A connection can set its own.",
            style: .info,
            duration: 10
        )
    }
}
