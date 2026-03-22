import Foundation
#if os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let queryResultsRowCountDidChange = Notification.Name("dk.tippr.echo.queryResultsRowCountDidChange")
}

@MainActor
final class QueryResultsGridState {
    var cachedColumnIDs: [String] = []
    var cachedRowOrder: [Int] = []
    var cachedSort: SortCriteria?
    var lastRowCount: Int = 0
    var lastResultToken: UInt64 = 0
    var hiddenColumnIndices: Set<Int> = []
    var columnOrder: [Int]?
    /// Persisted column widths keyed by column identifier, used to skip expensive
    /// `idealWidth()` measurement when rebuilding the table after a tab switch.
    var cachedColumnWidths: [String: CGFloat] = [:]
    private var isRowCountRefreshScheduled = false

    func scheduleRowCountRefresh() {
        guard !isRowCountRefreshScheduled else { return }
        isRowCountRefreshScheduled = true
#if os(macOS)
        let modes: [RunLoop.Mode] = [.default, .eventTracking]
#else
        let modes: [RunLoop.Mode] = [.default]
#endif
        RunLoop.main.perform(inModes: modes) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRowCountRefreshScheduled = false
                NotificationCenter.default.post(name: .queryResultsRowCountDidChange, object: self)
            }
        }
    }
}
