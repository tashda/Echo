#if DEBUG
import AppKit
import SwiftUI

/// A real AppKit table with the lab's sample rows, so options that blur the content under the
/// footer are judged over the same kind of view as Echo's results grid. It can drift slowly so
/// the rows keep passing under the footer.
struct LabAppKitGrid: NSViewRepresentable {
    var isDrifting: Bool
    /// Room left at the bottom so the last rows can scroll clear of the footer.
    var bottomInset: CGFloat
    /// Height of the blur along the bottom edge, and its radii; empty radii mean no blur.
    var blurHeight: CGFloat = 0
    var blurRadii: [CGFloat] = []

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = false
        table.rowHeight = 22
        table.intercellSpacing = NSSize(width: 10, height: 0)
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.backgroundColor = .textBackgroundColor
        table.style = .plain
        for column in LabResultsData.columns {
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
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = false
        context.coordinator.scrollView = scrollView

        // The blur goes in the same container as the table, above it, so it can see the rows.
        let container = NSView()
        scrollView.frame = container.bounds
        scrollView.autoresizingMask = [.width, .height]
        container.addSubview(scrollView)
        context.coordinator.blur = BackdropEdgeBlur(container: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        context.coordinator.scrollView?.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        context.coordinator.blur?.update(edge: .bottom, height: blurHeight, radii: blurRadii)
        context.coordinator.setDrifting(isDrifting)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.setDrifting(false)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var scrollView: NSScrollView?
        var blur: BackdropEdgeBlur?
        private var driftTask: Task<Void, Never>?
        private let rows = Array(repeating: LabResultsData.rows, count: 8).flatMap { $0 }

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn,
                  let columnIndex = LabResultsData.columns.firstIndex(where: { $0.id == tableColumn.identifier.rawValue })
            else { return nil }
            let column = LabResultsData.columns[columnIndex]
            let value = rows[row][columnIndex]
            let label = NSTextField(labelWithString: value)
            label.font = .systemFont(ofSize: 12)
            label.alignment = column.isNumeric ? .right : .left
            label.textColor = value == "NULL" ? .tertiaryLabelColor : value == "false" ? .systemRed : value == "true" ? .systemGreen : .labelColor
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        func setDrifting(_ drifting: Bool) {
            guard drifting != (driftTask != nil) else { return }
            driftTask?.cancel()
            driftTask = nil
            guard drifting else { return }
            driftTask = Task(name: "lab-grid-drift") { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(33))
                    guard let scrollView = self?.scrollView, let document = scrollView.documentView else { return }
                    let clip = scrollView.contentView
                    let maxY = max(document.frame.height - clip.bounds.height + scrollView.contentInsets.bottom, 0)
                    var y = clip.bounds.origin.y + 0.6
                    if y > maxY { y = 0 }
                    clip.scroll(to: NSPoint(x: 0, y: y))
                    scrollView.reflectScrolledClipView(clip)
                }
            }
        }
    }
}
#endif
