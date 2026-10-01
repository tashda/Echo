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
    /// Every number is one line of the same font, so its height is measured once: measuring each
    /// label on every scrolled frame was a steady cost while scrolling.
    private var labelHeight: CGFloat = 0
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

    /// Called when the header corner is clicked: selects every cell (round 47, GC2).
    var onSelectAll: (() -> Void)?

    /// Rows whose number turns accent: the selected rows and the hovered one (plans R3, R4).
    var accentRows: IndexSet = [] {
        didSet { if oldValue != accentRows { needsDisplay = true } }
    }

    /// The selected rows, whose gutter cell also carries the selection's tint (round 47, SR1).
    var selectedRows: IndexSet = [] {
        didSet { if oldValue != selectedRows { needsDisplay = true } }
    }

    /// Settings › Results › Row Number Style; the editor's own gutter has its own setting (round 47).
    var gutterStyle: EditorGutterStyle = .hairline {
        didSet {
            guard oldValue != gutterStyle else { return }
            digitWidth = computeWidth()
            needsDisplay = true
        }
    }

    /// The card's corner, for the lane's own (concentric, minus its inset).
    var cardCornerRadius: CGFloat = LayoutTokens.Workspace.cardCornerRadius {
        didSet { if oldValue != cardCornerRadius { needsDisplay = true } }
    }

    private var isCornerHovered = false {
        didSet { if oldValue != isCornerHovered { needsDisplay = true } }
    }
    private var hoverTrackingArea: NSTrackingArea?
    /// Kept for as long as the tooltip is, as AppKit doesn't retain its owner.
    private let selectAllToolTip: NSString = "Select All"
    private var laneInset: CGFloat { LayoutTokens.EditorGutter.laneInset }
    /// Space the lane takes either side of the numbers.
    private var sideInset: CGFloat { gutterStyle == .lane ? laneInset : 0 }

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
        labelHeight = ("8" as NSString).size(withAttributes: drawAttributes).height
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
        return ceil(size.width) + leadingPadding + trailingPadding + 2 * sideInset
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
        if point.y < contentAreaTop {
            window?.makeFirstResponder(self)
            onSelectAll?()
            return
        }
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

    // MARK: - Tints

    /// The selected rows' tint and the hovered row's, in the grid's shape (round 47): rounded blocks
    /// inset from the gutter's sides, one per run of selected rows with its ends 2pt in and 6pt
    /// round, as the selection beside it; the hover as the grid's hover.
    private func drawTints(tableView: NSTableView, firstRow: Int, lastRow: Int) {
        let inset = sideInset + ResultsGridMetrics.gutterTintInset
        let width = bounds.width - 2 * inset
        guard width > 0 else { return }
        func rowFrame(_ row: Int) -> NSRect {
            let rect = tableView.rect(ofRow: row)
            return NSRect(x: inset, y: tableView.convert(rect.origin, to: self).y, width: width, height: rect.height)
        }
        for run in selectedRows.rangeView {
            guard let first = run.first, let last = run.last, last >= firstRow, first <= lastRow else { continue }
            let top = rowFrame(first), bottom = rowFrame(last)
            let block = NSRect(x: inset, y: top.minY + ResultsGridMetrics.selectionEndInset, width: width,
                               height: bottom.maxY - top.minY - 2 * ResultsGridMetrics.selectionEndInset)
            AppearanceStore.shared.accentNSColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: block, xRadius: ResultsGridMetrics.selectionCornerRadius, yRadius: ResultsGridMetrics.selectionCornerRadius).fill()
        }
        for row in accentRows.subtracting(selectedRows) where row >= firstRow && row <= lastRow {
            let frame = rowFrame(row).insetBy(dx: 0, dy: ResultsGridMetrics.hoverVerticalInset)
            NSColor(ColorTokens.Sidebar.hoverFill).setFill()
            NSBezierPath(roundedRect: frame, xRadius: ResultsGridMetrics.hoverCornerRadius, yRadius: ResultsGridMetrics.hoverCornerRadius).fill()
        }
    }

    // MARK: - Header corner

    override func layout() {
        super.layout()
        removeAllToolTips()
        let corner = NSRect(x: 0, y: 0, width: bounds.width, height: contentAreaTop)
        if corner.height > 0 { addToolTip(corner, owner: selectAllToolTip, userData: nil) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        isCornerHovered = convert(event.locationInWindow, from: nil).y < contentAreaTop
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isCornerHovered = false
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

        // Header area background matching the table header.
        if contentTop > 0 {
            NSColor(ColorTokens.Background.primary).setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: contentTop).fill()
        }

        // The gutter's surface, as the editor's (round 47, SS0): a column the full height, or a lane.
        switch gutterStyle {
        case .tinted:
            NSColor(ColorTokens.Workspace.groupFill).setFill()
            bounds.fill()
        case .lane:
            NSColor(ColorTokens.Workspace.groupFill).setFill()
            let radius = max(cardCornerRadius - laneInset, SpacingTokens.xxs)
            NSBezierPath(roundedRect: bounds.insetBy(dx: laneInset, dy: laneInset), xRadius: radius, yRadius: radius).fill()
        case .subtle, .hairline:
            break
        }

        if contentTop > 0 {
            if isCornerHovered {
                NSColor(ColorTokens.Sidebar.hoverFill).setFill()
                let hover = NSRect(x: sideInset, y: 0, width: bounds.width - 2 * sideInset, height: contentTop).insetBy(dx: SpacingTokens.xxs, dy: SpacingTokens.xxs)
                NSBezierPath(roundedRect: hover, xRadius: SpacingTokens.xxs, yRadius: SpacingTokens.xxs).fill()
            }
            // The "#", vertically centered; a click on it selects everything.
            let headerLabel = "#" as NSString
            let headerTextSize = headerLabel.size(withAttributes: drawAttributes)
            let headerTextRect = NSRect(
                x: leadingPadding + sideInset,
                y: floor(contentTop / 2 - headerTextSize.height / 2),
                width: bounds.width - leadingPadding - trailingPadding - 2 * sideInset,
                height: headerTextSize.height
            )
            headerLabel.draw(in: headerTextRect, withAttributes: drawAttributes)
        }

        // One line under the header, level with the columns'; the lane keeps its own shape.
        if gutterStyle != .lane {
            NSColor.separatorColor.setFill()
            NSRect(x: 0, y: contentTop - lineWidth, width: bounds.width, height: lineWidth).fill()
        }

        // The edge: below the header only for Hairline (round 47: none in the header row), the full
        // height for the Column; Subtle and Lane have none.
        if gutterStyle == .hairline || gutterStyle == .tinted {
            NSColor.separatorColor.setFill()
            let top = gutterStyle == .hairline ? contentTop : 0
            NSRect(x: bounds.width - lineWidth, y: top, width: lineWidth, height: bounds.height - top).fill()
        }

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

        drawTints(tableView: tableView, firstRow: firstRow, lastRow: lastRow)

        for row in firstRow...lastRow {
            let rowRect = tableView.rect(ofRow: row)
            let convertedOrigin = tableView.convert(rowRect.origin, to: self)
            let convertedRowRect = NSRect(x: 0, y: convertedOrigin.y, width: bounds.width, height: rowRect.height)
            guard convertedRowRect.maxY >= dirtyRect.minY, convertedRowRect.minY <= dirtyRect.maxY else { continue }
            let label = "\(row + 1)" as NSString
            let textRect = NSRect(
                x: leadingPadding + sideInset,
                y: floor(convertedRowRect.midY - labelHeight / 2),
                width: bounds.width - leadingPadding - trailingPadding - 2 * sideInset,
                height: labelHeight
            )
            if accentRows.contains(row) {
                var accentAttributes = drawAttributes
                accentAttributes[.foregroundColor] = AppearanceStore.shared.accentNSColor
                label.draw(in: textRect, withAttributes: accentAttributes)
            } else {
                label.draw(in: textRect, withAttributes: drawAttributes)
            }
        }

        NSGraphicsContext.restoreGraphicsState()
    }
}
#endif
