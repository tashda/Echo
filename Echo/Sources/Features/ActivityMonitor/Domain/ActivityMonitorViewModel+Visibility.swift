import Foundation

/// A monitor whose tab is kept mounted but not shown keeps collecting, but doesn't publish: every
/// snapshot re-renders its tables and charts, about 45 ms a second per monitor, for a tab nobody
/// sees. The held snapshots are applied in one go when the tab shows again, so the charts keep
/// their whole history.
extension ActivityMonitorViewModel {
    /// A snapshot from the stream: shown at once, or held while the tab is hidden.
    func receive(_ snapshot: DatabaseActivitySnapshot) {
        guard isShown else {
            heldSnapshots.append(snapshot)
            if heldSnapshots.count > maxHistoryItems { heldSnapshots.removeFirst() }
            return
        }
        latestSnapshot = snapshot
        updateHistory(with: snapshot)
    }

    /// The tab was shown or hidden (`KeptAliveTabsView`).
    func setShown(_ shown: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        if shown { showHeldSnapshots() }
    }

    func showHeldSnapshots() {
        guard !heldSnapshots.isEmpty else { return }
        let held = heldSnapshots
        heldSnapshots = []
        for snapshot in held { updateHistory(with: snapshot) }
        latestSnapshot = held.last
    }
}
