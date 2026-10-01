import AppKit
import SwiftUI

/// Round 27: the grid's data, its options, and its link to the shared scroll state.
@MainActor
final class LabRSGridCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    weak var scrollView: LabRSScrollView?
    var blur: BackdropEdgeBlur?
    var columns: [LabColumn] = []
    var lastScrollToken = ""
    var glideTask: Task<Void, Never>?
    private weak var scroll: LabRSScroll?
    private var setup: LabRSGridSetup?
    private let rows = Array(repeating: LabResultsData.rows, count: 12).flatMap { $0 }

    func apply(_ setup: LabRSGridSetup) {
        guard setup != self.setup, let scrollView else { return }
        self.setup = setup
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: setup.footerZone, right: 0)
        scrollView.scrollerInsets = NSEdgeInsetsZero
        scrollView.hasHorizontalScroller = setup.horizontal != nil
        scrollView.hasVerticalScroller = setup.verticalBottom != nil
        scrollView.scrollerStyle = setup.visibility == .always ? .legacy : .overlay
        scrollView.autohidesScrollers = setup.visibility != .always
        scrollView.horizontalFrame = setup.horizontal
        scrollView.verticalBottom = setup.verticalBottom ?? 0
        let lane = setup.lane
        switch setup.visibility {
        case .nearBottom:
            scrollView.revealZone = { [weak scrollView] point in
                guard let scrollView else { return false }
                return point.y > scrollView.bounds.height - setup.footerZone - lane - SpacingTokens.lg
                    || point.x > scrollView.bounds.width - lane - SpacingTokens.lg
            }
        case .overGrid:
            scrollView.revealZone = { _ in true }
        case .whileScrolling, .always:
            scrollView.revealZone = nil
        }
        scrollView.tile()
        if setup.visibility != .always { scrollView.flashScrollers() }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn,
              let index = columns.firstIndex(where: { $0.id == tableColumn.identifier.rawValue }) else { return nil }
        let column = columns[index]
        let values = rows[row]
        let label = NSTextField(labelWithString: values[index % values.count])
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.alignment = column.isNumeric ? .right : .left
        label.lineBreakMode = .byTruncatingTail
        let cell = NSTableCellView()
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: SpacingTokens.xs),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -SpacingTokens.xs),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    /// Reports the position to the shared state, and lets the drawn bars, track and chip scroll.
    func observe(_ scroll: LabRSScroll) {
        self.scroll = scroll
        guard let scrollView else { return }
        let clip = scrollView.contentView
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged), name: NSView.boundsDidChangeNotification, object: clip)
        scroll.scrollTo = { [weak self] position in self?.scroll(horizontal: position) }
        scroll.scrollVerticallyTo = { [weak self] position in self?.scroll(vertical: position) }
        scrollView.onPointer = { [weak scroll] point in scroll?.pointer = point }
        Task { @MainActor [weak self] in self?.report(scrolled: false) }
    }

    @objc private func boundsChanged(_ notification: Notification) { report(scrolled: true) }

    private func report(scrolled: Bool) {
        guard let scroll, let scrollView, let table = scrollView.documentView as? NSTableView else { return }
        let visible = scrollView.contentView.bounds
        let width = max(table.frame.width, 1)
        scroll.visibleFraction = min(visible.width / width, 1)
        scroll.position = min(max(visible.minX / max(width - visible.width, 1), 0), 1)
        let height = max(table.frame.height, 1)
        let shown = max(visible.height - scrollView.contentInsets.bottom, 1)
        scroll.verticalVisibleFraction = min(shown / height, 1)
        scroll.verticalPosition = min(max(visible.minY / max(height - shown, 1), 0), 1)
        let columns = table.columnIndexes(in: visible)
        scroll.firstColumn = (columns.first ?? 0) + 1
        scroll.lastColumn = (columns.last ?? 0) + 1
        scroll.columnCount = table.numberOfColumns
        scroll.headerHeight = table.headerView?.frame.height ?? 0
        if scrolled { scroll.noteScrolled() }
    }

    private func scroll(horizontal position: CGFloat) {
        guard let scrollView, let document = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let travel = max(document.frame.width - clip.bounds.width, 0)
        clip.scroll(to: NSPoint(x: travel * min(max(position, 0), 1), y: clip.bounds.minY))
        scrollView.reflectScrolledClipView(clip)
    }

    private func scroll(vertical position: CGFloat) {
        guard let scrollView, let document = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let travel = max(document.frame.height - clip.bounds.height + scrollView.contentInsets.bottom, 0)
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: travel * min(max(position, 0), 1)))
        scrollView.reflectScrolledClipView(clip)
    }

    /// Scrolls right and down over a second, then back, so the bars show.
    func glide() {
        glideTask?.cancel()
        glideTask = Task(name: "lab-rs-glide") { @MainActor [weak self] in
            guard let scrollView = self?.scrollView, let document = scrollView.documentView else { return }
            let clip = scrollView.contentView
            let maxX = max(document.frame.width - clip.bounds.width, 0)
            let start = clip.bounds.origin
            let target = NSPoint(x: start.x > maxX / 2 ? 0 : maxX * 0.6, y: start.y + 240)
            for step in 1...60 {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                let t = CGFloat(step) / 60
                let eased = t * t * (3 - 2 * t)
                clip.scroll(to: NSPoint(x: start.x + (target.x - start.x) * eased, y: start.y + (target.y - start.y) * eased))
                scrollView.reflectScrolledClipView(clip)
            }
        }
    }
}
