import AppKit

/// Round 27: the grid's row numbers, a column left of the grid as in Echo
/// (ResultTableRowNumberView), following the rows as they scroll. The footer floats over it too.
final class LabRSRowNumbers: NSView {
    weak var scrollView: NSScrollView? {
        didSet {
            guard let clip = scrollView?.contentView else { return }
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: clip)
        }
    }

    override var isFlipped: Bool { true }

    @objc private func scrolled(_ notification: Notification) { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()
        guard let scrollView, let table = scrollView.documentView as? NSTableView else { return }
        let header = table.headerView?.frame.height ?? 0
        let offset = scrollView.contentView.bounds.minY
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        ("#" as NSString).draw(at: NSPoint(x: bounds.width - SpacingTokens.lg, y: (header - NSFont.smallSystemFontSize) / 2 - 2), withAttributes: attributes)
        let first = max(Int(offset / table.rowHeight), 0)
        let last = min(Int((offset + bounds.height) / table.rowHeight) + 1, table.numberOfRows - 1)
        guard first <= last else { return }
        for row in first...last {
            let y = header + CGFloat(row) * table.rowHeight - offset
            guard y >= header - 1 else { continue }
            let label = "\(row + 1)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: bounds.width - size.width - SpacingTokens.xs, y: y + (table.rowHeight - size.height) / 2),
                       withAttributes: attributes)
        }
    }
}

/// Round 27: the row numbers on the left and the grid with its blur on the right.
final class LabRSGridContainer: NSView {
    let rowNumbers = LabRSRowNumbers()
    let gridHost = NSView()
    var gutterWidth: CGFloat = 0 { didSet { needsLayout = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(gridHost)
        addSubview(rowNumbers)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        rowNumbers.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
        gridHost.frame = NSRect(x: gutterWidth, y: 0, width: max(bounds.width - gutterWidth, 0), height: bounds.height)
    }
}
