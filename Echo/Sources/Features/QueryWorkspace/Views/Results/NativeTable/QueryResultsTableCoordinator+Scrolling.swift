#if os(macOS)
import AppKit
import SwiftUI

extension QueryResultsTableView.Coordinator {
    
    func adjustTableSize(rowCount _: Int? = nil) {
        guard let tableView, let scrollView else { return }
        cachedViewportSize = scrollView.contentView.bounds.size
        let contentWidth = tableView.tableColumns.reduce(CGFloat(0)) { $0 + $1.width }
        let targetWidth = max(contentWidth, scrollView.contentSize.width)
        if abs(tableView.frame.width - targetWidth) > 0.5 {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            tableView.setFrameSize(NSSize(width: targetWidth, height: tableView.frame.height))
            CATransaction.commit()
        }
    }

    func registerScrollObservation(for scrollView: NSScrollView) {
        let contentView = scrollView.contentView
        if observedContentView === contentView { return }
        if let old = observedContentView { NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: old) }
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleContentViewBoundsChange(_:)), name: NSView.boundsDidChangeNotification, object: contentView)
        observedContentView = contentView; requestPaginationEvaluation()
    }

    @objc func handleContentViewBoundsChange(_ notification: Notification) { requestPaginationEvaluation() }

    func requestPaginationEvaluation() {
        guard !parent.isResizing, !pendingPaginationEvaluation else { return }
        pendingPaginationEvaluation = true
        DispatchQueue.main.async { [weak self] in guard let self else { return }; self.pendingPaginationEvaluation = false; self.evaluatePaginationForVisibleRows() }
    }

    func evaluatePaginationForVisibleRows() {
        guard let tableView else { return }
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return }
        let lower = max(visibleRange.location, 0); let upper = min(tableView.numberOfRows, lower + visibleRange.length)
        guard upper > lower else { return }
        parent.query.revealMoreRowsIfNeeded(forDisplayedRow: upper - 1)
        var sourceIndices: [Int] = []; sourceIndices.reserveCapacity(upper - lower)
        if parent.rowOrder.isEmpty { for r in lower..<upper { sourceIndices.append(r) } }
        else { for r in lower..<upper { if r < parent.rowOrder.count { sourceIndices.append(parent.rowOrder[r]) } } }
        parent.query.updateVisibleGridWindow(displayedRange: lower..<upper, sourceIndices: sourceIndices)
    }

    func requestTableSizeAdjustment(rowCount: Int? = nil) {
        guard !parent.isResizing, !pendingTableSizeAdjustment else { return }
        pendingTableSizeAdjustment = true; let captured = rowCount
        DispatchQueue.main.async { [weak self] in guard let self else { return }; self.pendingTableSizeAdjustment = false; self.adjustTableSize(rowCount: captured) }
    }

    func installRowCountObserver(for state: QueryResultsGridState?) {
        if let obs = rowCountObserver { NotificationCenter.default.removeObserver(obs); rowCountObserver = nil }
        guard let state else { return }
        rowCountObserver = NotificationCenter.default.addObserver(forName: .queryResultsRowCountDidChange, object: state, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in guard let self = self, let tableView = self.tableView else { self?.pendingRowCountCorrection = true; return }; self.scheduleRowCountUpdate(for: tableView) }
        }
    }

    func scheduleRowCountUpdate(for tableView: NSTableView) {
        pendingRowCountCorrection = true
        if let existing = rowCountUpdateWorkItem, !existing.isCancelled { return }
        let workItem = DispatchWorkItem { [weak self, weak tableView] in
            guard let self = self, let tableView = tableView else { return }
            self.rowCountUpdateWorkItem = nil; self.pendingRowCountCorrection = false; tableView.noteNumberOfRowsChanged()
        }
        rowCountUpdateWorkItem = workItem; DispatchQueue.main.async(execute: workItem)
    }

    func scheduleRowCountCorrection() {
        guard !pendingRowCountCorrection else { return }
        pendingRowCountCorrection = true
        if let state = persistedState { state.scheduleRowCountRefresh(); return }
        if let tableView = tableView { scheduleRowCountUpdate(for: tableView) }
    }
}
#endif
