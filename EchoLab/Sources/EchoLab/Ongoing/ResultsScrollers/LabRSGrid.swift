import AppKit
import SwiftUI

/// Round 27: a real AppKit table with native overlay scroll bars, the footer's room and its soft
/// blur, set up as Echo's results grid is (ResultTableContainerView), with the scroller insets of
/// the placement being judged. `scrollToken` scrolls it diagonally so the bars show.
struct LabRSGrid: NSViewRepresentable {
    let columnCount: Int
    let footerZone: CGFloat
    let scrollerInsets: NSEdgeInsets
    let scrollToken: String
    var showsSystemBar = true
    let scroll: LabRSScroll

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let table = NSTableView()
        table.rowHeight = 24
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.gridStyleMask = []
        table.style = .plain
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.backgroundColor = .textBackgroundColor
        context.coordinator.columns = Self.columns(columnCount)
        for column in context.coordinator.columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
            tableColumn.title = column.id
            tableColumn.width = column.width
            table.addTableColumn(tableColumn)
        }
        table.dataSource = context.coordinator
        table.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = false
        context.coordinator.scrollView = scrollView
        context.coordinator.observe(scroll)

        let container = NSView()
        scrollView.frame = container.bounds
        scrollView.autoresizingMask = [.width, .height]
        container.addSubview(scrollView)
        context.coordinator.blur = BackdropEdgeBlur(container: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let scrollView = context.coordinator.scrollView else { return }
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: footerZone, right: 0)
        scrollView.scrollerInsets = scrollerInsets
        if scrollView.hasHorizontalScroller != showsSystemBar { scrollView.hasHorizontalScroller = showsSystemBar }
        context.coordinator.blur?.update(edge: .bottom, height: footerZone + LayoutTokens.EdgeBlur.fade,
                                         radii: LayoutTokens.EdgeBlur.radii)
        if context.coordinator.lastScrollToken != scrollToken {
            context.coordinator.lastScrollToken = scrollToken
            context.coordinator.glide()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.glideTask?.cancel()
    }

    private static func columns(_ count: Int) -> [LabColumn] {
        (0..<count).map { index in
            let base = LabResultsData.columns[index % LabResultsData.columns.count]
            let suffix = index < LabResultsData.columns.count ? "" : "_\(index / LabResultsData.columns.count + 1)"
            return LabColumn(id: base.id + suffix, type: base.type, isNumeric: base.isNumeric, width: base.width + 30)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var scrollView: NSScrollView?
        var blur: BackdropEdgeBlur?
        var columns: [LabColumn] = []
        var lastScrollToken = ""
        var glideTask: Task<Void, Never>?
        private weak var scroll: LabRSScroll?
        private let rows = Array(repeating: LabResultsData.rows, count: 12).flatMap { $0 }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn,
                  let index = columns.firstIndex(where: { $0.id == tableColumn.identifier.rawValue }) else { return nil }
            let column = columns[index]
            let values = rows[row]
            let value = values[index % values.count]
            let label = NSTextField(labelWithString: value)
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

        /// Reports the sideways position to the footer, and lets it scroll the grid.
        func observe(_ scroll: LabRSScroll) {
            self.scroll = scroll
            guard let clip = scrollView?.contentView else { return }
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged), name: NSView.boundsDidChangeNotification, object: clip)
            scroll.scrollTo = { [weak self] position in self?.scroll(to: position) }
            Task { @MainActor [weak self] in self?.report() }
        }

        @objc private func boundsChanged(_ notification: Notification) { report() }

        private func report() {
            guard let scroll, let scrollView, let table = scrollView.documentView as? NSTableView else { return }
            let visible = scrollView.contentView.bounds
            let width = max(table.frame.width, 1)
            let travel = max(width - visible.width, 1)
            scroll.visibleFraction = min(visible.width / width, 1)
            scroll.position = min(max(visible.minX / travel, 0), 1)
            let columns = table.columnIndexes(in: visible)
            scroll.firstColumn = (columns.first ?? 0) + 1
            scroll.lastColumn = (columns.last ?? 0) + 1
            scroll.columnCount = table.numberOfColumns
        }

        private func scroll(to position: CGFloat) {
            guard let scrollView, let document = scrollView.documentView else { return }
            let clip = scrollView.contentView
            let travel = max(document.frame.width - clip.bounds.width, 0)
            clip.scroll(to: NSPoint(x: travel * min(max(position, 0), 1), y: clip.bounds.minY))
            scrollView.reflectScrolledClipView(clip)
        }

        /// Scrolls right and down over a second, then back, so both bars show.
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
}
