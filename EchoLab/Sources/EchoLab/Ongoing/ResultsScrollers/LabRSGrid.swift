import AppKit
import SwiftUI

/// What the grid needs from the round's options.
struct LabRSGridSetup: Equatable {
    var footerZone: CGFloat
    /// The system bar's place; nil hides it (F, G, or a drawn style).
    var horizontal: LabRSBarFrame?
    /// Where the vertical bar ends; nil hides it (R3, or a drawn style).
    var verticalBottom: CGFloat?
    var visibility: LabRSVisibility
    /// The bars' lane, for V3's reach.
    var lane: CGFloat
}

/// Round 27: a real AppKit table, set up as Echo's results grid is (ResultTableContainerView): the
/// footer's room under the rows, its soft blur, and the system's overlay bars, placed by
/// LabRSScrollView. It reports where it is scrolled to `scroll`, and `scrollToken` scrolls it
/// diagonally so the bars show.
struct LabRSGrid: NSViewRepresentable {
    let columnCount: Int
    let setup: LabRSGridSetup
    let scrollToken: String
    let scroll: LabRSScroll

    func makeCoordinator() -> LabRSGridCoordinator { LabRSGridCoordinator() }

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

        let scrollView = LabRSScrollView()
        scrollView.documentView = table
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = false
        context.coordinator.scrollView = scrollView

        let container = NSView()
        scrollView.frame = container.bounds
        scrollView.autoresizingMask = [.width, .height]
        container.addSubview(scrollView)
        // Above the scroll view, as Echo has it: a blur inside a scroll view sees nothing to blur.
        context.coordinator.blur = BackdropEdgeBlur(container: container)
        context.coordinator.observe(scroll)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let scrollView = context.coordinator.scrollView else { return }
        context.coordinator.apply(setup)
        context.coordinator.blur?.update(edge: .bottom, height: setup.footerZone + LayoutTokens.EdgeBlur.fade,
                                         radii: LayoutTokens.EdgeBlur.radii)
        scrollView.tile()
        if context.coordinator.lastScrollToken != scrollToken {
            context.coordinator.lastScrollToken = scrollToken
            context.coordinator.glide()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: LabRSGridCoordinator) {
        coordinator.glideTask?.cancel()
    }

    private static func columns(_ count: Int) -> [LabColumn] {
        (0..<count).map { index in
            let base = LabResultsData.columns[index % LabResultsData.columns.count]
            let suffix = index < LabResultsData.columns.count ? "" : "_\(index / LabResultsData.columns.count + 1)"
            return LabColumn(id: base.id + suffix, type: base.type, isNumeric: base.isNumeric, width: base.width + 30)
        }
    }
}
