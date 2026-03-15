#if os(macOS)
import AppKit
import SwiftUI

final class ResultTableRowNumberView: NSView {
    override var isFlipped: Bool { true }

    private var rowCount: Int = 0
    private var digitWidth: CGFloat = 0
    private let leadingPadding: CGFloat = SpacingTokens.xxs
    private let trailingPadding: CGFloat = SpacingTokens.xs
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let textColor = NSColor(ColorTokens.Text.tertiary)
    private var drawAttributes: [NSAttributedString.Key: Any] = [:]
    private var cachedBackgroundColor: NSColor = .controlBackgroundColor
    private weak var observedContentView: NSClipView?
    private weak var tableView: NSTableView?

    /// Called when the user clicks/drags on row numbers. Passes the row index.
    var onRowSelect: ((Int) -> Void)?
    /// Called when the user extends selection by dragging. Passes the row index.
    var onRowExtendSelect: ((Int) -> Void)?

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

    func update(rowCount: Int) {
        guard self.rowCount != rowCount else { return }
        self.rowCount = rowCount
        digitWidth = computeWidth()
        needsDisplay = true
    }

    var requiredWidth: CGFloat {
        digitWidth
    }

    private func computeWidth() -> CGFloat {
        guard rowCount > 0 else { return 0 }
        let maxLabel = "\(rowCount)" as NSString
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
        let tablePoint = convert(point, to: tableView)
        let row = tableView.row(at: tablePoint)
        guard row >= 0, row < rowCount else { return nil }
        return row
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let row = rowIndex(at: point) {
            onRowSelect?(row)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let row = rowIndex(at: point) {
            onRowExtendSelect?(row)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard rowCount > 0, let tableView else { return }

        cachedBackgroundColor.setFill()
        dirtyRect.fill()

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let lineWidth = 1 / max(scale, 1)
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.width - lineWidth, y: 0, width: lineWidth, height: bounds.height).fill()

        let contentTop = contentAreaTop

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

        let rowHeight = tableView.rowHeight
        let centeringOffset = (rowHeight - font.ascender + font.descender) / 2

        for row in firstRow...lastRow {
            let rowRect = tableView.rect(ofRow: row)
            let convertedOrigin = tableView.convert(rowRect.origin, to: self)
            let y = convertedOrigin.y
            guard y + rowHeight >= dirtyRect.minY, y <= dirtyRect.maxY else { continue }
            let textRect = NSRect(
                x: leadingPadding,
                y: y + centeringOffset,
                width: bounds.width - leadingPadding - trailingPadding,
                height: rowHeight
            )
            let label = "\(row + 1)" as NSString
            label.draw(in: textRect, withAttributes: drawAttributes)
        }

        NSGraphicsContext.restoreGraphicsState()
    }
}
#endif
