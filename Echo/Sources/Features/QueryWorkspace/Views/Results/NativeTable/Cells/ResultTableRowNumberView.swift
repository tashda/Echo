#if os(macOS)
import AppKit
import SwiftUI

final class ResultTableRowNumberView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private var rowCount: Int = 0
    private var reservedCount: Int = 0
    private var digitWidth: CGFloat = 0
    private let leadingPadding = ResultsGridMetrics.rowNumberLeadingPadding
    private let trailingPadding = ResultsGridMetrics.rowNumberTrailingPadding
    private let font = NSFont.monospacedDigitSystemFont(ofSize: ResultsGridMetrics.rowNumberFontSize, weight: .regular)
    private let textColor = NSColor(ColorTokens.Text.tertiary)
    private var drawAttributes: [NSAttributedString.Key: Any] = [:]
    private var cachedBackgroundColor: NSColor = .controlBackgroundColor
    private weak var observedContentView: NSClipView?
    private weak var tableView: NSTableView?

    /// Called when the user clicks/drags on row numbers. Passes the row index.
    var onRowSelect: ((Int) -> Void)?
    /// Called when the user extends selection by dragging. Passes the row index.
    var onRowExtendSelect: ((Int) -> Void)?
    /// Called on every drag event so the coordinator can drive autoscroll.
    var onRowDragEvent: ((NSEvent) -> Void)?
    /// Called when a row-number drag ends.
    var onRowDragEnded: (() -> Void)?
    /// Called when the user opens a context menu on a row number.
    var onRowContextMenu: ((Int) -> NSMenu?)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        cachedBackgroundColor = NSColor(ColorTokens.Background.tertiary)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        drawAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let cv = observedContentView {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: cv)
        }
    }

    func attach(to scrollView: NSScrollView) {
        let contentView = scrollView.contentView
        tableView = scrollView.documentView as? NSTableView
        if observedContentView === contentView { return }
        if let old = observedContentView {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: old)
        }
        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentViewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )
        observedContentView = contentView
    }

    @objc private func contentViewBoundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    func update(rowCount: Int, reservedCount: Int) {
        guard self.rowCount != rowCount || self.reservedCount != reservedCount else { return }
        self.rowCount = rowCount
        self.reservedCount = max(reservedCount, rowCount)
        digitWidth = computeWidth()
        needsDisplay = true
    }

    var requiredWidth: CGFloat {
        digitWidth
    }

    private func computeWidth() -> CGFloat {
        let effectiveCount = max(reservedCount, rowCount)
        let digitCount = max(
            ResultsGridMetrics.minimumRowNumberDigits,
            max(1, "\(effectiveCount)".count)
        )
        let maxLabel = String(repeating: "8", count: digitCount) as NSString
        let size = maxLabel.size(withAttributes: drawAttributes)
        return ceil(size.width) + leadingPadding + trailingPadding
    }

    /// The y in our coordinate system where the data rows begin (below the header).
    /// Uses coordinate conversion from the header view for correctness across
    /// flipped/unflipped view hierarchies.
    private var contentAreaTop: CGFloat {
        guard let tableView, let headerView = tableView.headerView else { return 0 }
        let headerBottom = headerView.convert(NSPoint(x: 0, y: headerView.bounds.height), to: self)
        return headerBottom.y
    }

    // MARK: - Mouse Handling

    private func rowIndex(at point: NSPoint) -> Int? {
        guard let tableView else { return nil }
        guard point.y >= contentAreaTop else { return nil }
        let converted = convert(point, to: tableView)
        let probeX = max(tableView.visibleRect.minX + 1, 1)
        let row = tableView.row(at: NSPoint(x: probeX, y: converted.y))
        guard row >= 0, row < rowCount else { return nil }
        return row
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let row = rowIndex(at: point) {
            window?.makeFirstResponder(self)
            onRowSelect?(row)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        onRowDragEvent?(event)
        let point = convert(event.locationInWindow, from: nil)
        if let row = rowIndex(at: point) {
            onRowExtendSelect?(row)
        }
    }

    override func mouseUp(with event: NSEvent) {
        onRowDragEnded?()
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let row = rowIndex(at: point), let menu = onRowContextMenu?(row) else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        if let tableView = tableView as? ResultTableView {
            tableView.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard rowCount > 0, let tableView else { return }

        cachedBackgroundColor.setFill()
        dirtyRect.fill()

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth = 1 / max(scale, 1)

        let contentTop = contentAreaTop

        // Draw header area background matching the table header.
        if contentTop > 0 {
            NSColor(ColorTokens.Background.primary).setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: contentTop).fill()

            // Draw "#" header label, vertically centered.
            let headerLabel = "#" as NSString
            let headerTextSize = headerLabel.size(withAttributes: drawAttributes)
            let headerTextRect = NSRect(
                x: leadingPadding,
                y: floor(contentTop / 2 - headerTextSize.height / 2),
                width: bounds.width - leadingPadding - trailingPadding,
                height: headerTextSize.height
            )
            headerLabel.draw(in: headerTextRect, withAttributes: drawAttributes)
        }

        // Draw horizontal separator under the header area.
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: contentTop - lineWidth, width: bounds.width, height: lineWidth).fill()

        // Draw vertical separator on right edge.
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.width - lineWidth, y: 0, width: lineWidth, height: bounds.height).fill()

        let rowArea = NSRect(x: 0, y: contentTop, width: bounds.width, height: bounds.height - contentTop)
        guard rowArea.intersects(dirtyRect) else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rowArea).addClip()

        let visibleRows = tableView.rows(in: tableView.visibleRect)
        let firstRow = max(visibleRows.location, 0)
        let lastRow = min(rowCount - 1, firstRow + visibleRows.length)

        guard firstRow <= lastRow else {
            NSGraphicsContext.restoreGraphicsState()
            return
        }

        for row in firstRow...lastRow {
            let rowRect = tableView.rect(ofRow: row)
            let convertedOrigin = tableView.convert(rowRect.origin, to: self)
            let convertedRowRect = NSRect(x: 0, y: convertedOrigin.y, width: bounds.width, height: rowRect.height)
            guard convertedRowRect.maxY >= dirtyRect.minY, convertedRowRect.minY <= dirtyRect.maxY else { continue }
            let label = "\(row + 1)" as NSString
            let textSize = label.size(withAttributes: drawAttributes)
            let textRect = NSRect(
                x: leadingPadding,
                y: floor(convertedRowRect.midY - textSize.height / 2),
                width: bounds.width - leadingPadding - trailingPadding,
                height: textSize.height
            )
            label.draw(in: textRect, withAttributes: drawAttributes)
        }

        NSGraphicsContext.restoreGraphicsState()
    }
}
#endif
