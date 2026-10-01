import AppKit
import SwiftUI

/// Round 44: a real AppKit table set up as Echo's results grid is (room for the footer under the
/// rows, the system's overlay bars), with the chosen technique's blur in its clip view.
struct LabFBGrid: NSViewRepresentable {
    let look: LabFBLook
    let isScrolling: Bool

    func makeCoordinator() -> LabFBGridCoordinator { LabFBGridCoordinator() }

    func makeNSView(context: Context) -> NSView {
        let table = NSTableView()
        table.rowHeight = 24
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.gridStyleMask = []
        table.style = .plain
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.headerView = nil
        let columns = (LabResultsData.columns + LabResultsData.columns).enumerated().map { index, column in
            LabColumn(id: "\(column.id)_\(index)", type: column.type, isNumeric: column.isNumeric, width: column.width + 24)
        }
        context.coordinator.columns = columns
        for column in columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
            tableColumn.width = column.width
            table.addTableColumn(tableColumn)
        }
        table.dataSource = context.coordinator
        table.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: LabFBLook.footerZone, right: 0)
        context.coordinator.scrollView = scrollView
        let host = NSView()
        host.wantsLayer = true
        scrollView.frame = host.bounds
        scrollView.autoresizingMask = [.width, .height]
        host.addSubview(scrollView)
        context.coordinator.host = host
        return host
    }

    func updateNSView(_ host: NSView, context: Context) {
        context.coordinator.apply(look)
        context.coordinator.place()
        context.coordinator.setScrolling(isScrolling)
    }

    static func dismantleNSView(_ host: NSView, coordinator: LabFBGridCoordinator) {
        coordinator.stop()
    }
}
