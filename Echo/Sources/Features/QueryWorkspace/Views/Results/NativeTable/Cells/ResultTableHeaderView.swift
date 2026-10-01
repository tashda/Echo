#if os(macOS)
import AppKit
import SwiftUI
import QuartzCore

final class ResultTableHeaderView: NSTableHeaderView {
    weak var coordinator: QueryResultsTableView.Coordinator?
    private var isDraggingColumns = false
    private var separatorLayers: [CALayer] = []
    private let resizeEdgeTolerance: CGFloat = 5
    private var hoverTrackingArea: NSTrackingArea?
    private var hoveredColumn: Int?

    init(coordinator: QueryResultsTableView.Coordinator?) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw bottom separator line spanning full width — the native header view
        // doesn't always draw this depending on table configuration.
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth = 1 / max(scale, 1)
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: bounds.height - lineWidth, width: bounds.width, height: lineWidth).fill()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth = 1 / max(scale, 1)
        updateSeparatorFrames(lineWidth: lineWidth)
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              let tableView = tableView else {
            super.mouseDown(with: event)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let column = tableView.column(at: location)
        if column >= 0 {
            let columnRect = headerRect(ofColumn: column)
            // The sort arrow sorts (plan R2); anywhere else selects the column.
            let arrowRect = ResultTableHeaderCell.sortIndicatorRect(in: columnRect)
                .insetBy(dx: -ResultsGridMetrics.sortIndicatorHitSlop, dy: -ResultsGridMetrics.sortIndicatorHitSlop)
            if arrowRect.contains(location) {
                isDraggingColumns = false
                coordinator?.cycleSort(forVisibleColumn: column)
                return
            }
            let isNearLeftEdge = column > 0 && abs(location.x - columnRect.minX) <= resizeEdgeTolerance
            let isNearRightEdge = abs(location.x - columnRect.maxX) <= resizeEdgeTolerance
            if isNearLeftEdge || isNearRightEdge {
                isDraggingColumns = false
                super.mouseDown(with: event)
                return
            }
            coordinator?.beginColumnSelection(at: column, modifiers: event.modifierFlags)
            isDraggingColumns = true
        } else {
            isDraggingColumns = false
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              isDraggingColumns,
              let tableView = tableView else {
            super.mouseDragged(with: event)
            return
        }
        guard !tableView.tableColumns.isEmpty else {
            super.mouseDragged(with: event)
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        var column = tableView.column(at: location)
        if column < 0 {
            column = location.x < 0 ? 0 : tableView.tableColumns.count - 1
        }
        coordinator?.continueColumnSelection(to: column)
    }

    override func mouseUp(with event: NSEvent) {
        if isDraggingColumns, event.buttonNumber == 0 {
            coordinator?.endColumnSelection()
        } else {
            super.mouseUp(with: event)
        }
        isDraggingColumns = false
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let tableView else { return }
        let column = tableView.column(at: convert(event.locationInWindow, from: nil))
        setHoveredColumn(column >= 0 ? column : nil)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoveredColumn(nil)
    }

    /// Shows the sort arrow on the column under the pointer.
    private func setHoveredColumn(_ column: Int?) {
        guard column != hoveredColumn, let tableView else { return }
        for index in [hoveredColumn, column].compactMap({ $0 }) where index < tableView.tableColumns.count {
            (tableView.tableColumns[index].headerCell as? ResultTableHeaderCell)?.isHovered = index == column
            setNeedsDisplay(headerRect(ofColumn: index))
        }
        hoveredColumn = column
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let location = convert(event.locationInWindow, from: nil)
        let column = tableView?.column(at: location) ?? -1
        coordinator?.prepareHeaderContextMenu(at: column >= 0 ? column : nil)
        return menu ?? super.menu(for: event)
    }

    private func updateSeparatorFrames(lineWidth: CGFloat) {
        guard let tableView else {
            separatorLayers.forEach { $0.removeFromSuperlayer() }
            separatorLayers.removeAll()
            return
        }

        let columnCount = tableView.numberOfColumns
        let required = max(columnCount - 1, 0)
        let separatorColor = NSColor.separatorColor.cgColor

        if separatorLayers.count != required {
            separatorLayers.forEach { $0.removeFromSuperlayer() }
            separatorLayers.removeAll()

            guard required > 0 else { return }

            for _ in 0..<required {
                let layer = CALayer()
                layer.zPosition = 1
                layer.backgroundColor = separatorColor
                self.layer?.addSublayer(layer)
                separatorLayers.append(layer)
            }
        }

        guard !separatorLayers.isEmpty else { return }

        for (index, layer) in separatorLayers.enumerated() {
            let columnRect = tableView.rect(ofColumn: index)
            let converted = convert(columnRect, from: tableView)
            let xPosition = converted.maxX - lineWidth / 2
            layer.backgroundColor = separatorColor
            layer.frame = CGRect(x: xPosition, y: 0, width: lineWidth, height: bounds.height)
        }
    }
}
#endif
