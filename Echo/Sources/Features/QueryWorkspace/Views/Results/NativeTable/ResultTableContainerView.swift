import SwiftUI
import AppKit

final class ResultTableContainerView: NSView {
    private let scrollView: NSScrollView
    private let rowNumberView: ResultTableRowNumberView
    private var leadingWidthConstraint: NSLayoutConstraint?
    private var backgroundColor: NSColor
    private var showRowNumbers: Bool
    private var reservedRowNumberCount: Int = 0
    private lazy var footerOverlay = FooterScrollOverlay(scrollView: scrollView, softEdges: true)

    init(scrollView: NSScrollView, showRowNumbers: Bool) {
        self.scrollView = scrollView
        self.showRowNumbers = showRowNumbers
        self.backgroundColor = .clear
        self.rowNumberView = ResultTableRowNumberView()
        super.init(frame: .zero)

        rowNumberView.wantsLayer = true
        addSubview(rowNumberView)
        addSubview(scrollView)

        setupConstraints()
        rowNumberView.attach(to: scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        rowNumberView.translatesAutoresizingMaskIntoConstraints = false

        let widthConstraint = rowNumberView.widthAnchor.constraint(equalToConstant: 0)
        leadingWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            rowNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowNumberView.topAnchor.constraint(equalTo: topAnchor),
            rowNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthConstraint,

            scrollView.leadingAnchor.constraint(equalTo: rowNumberView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// Room for the footer floating over the grid, the soft blur of the rows under it (round 9,
    /// FB1), the scroll bars just above its pills and soft edges where more columns wait
    /// (round 27). Zero removes the room and the blur.
    func setFooterOverlay(height: CGFloat) {
        footerOverlay.update(footerHeight: height)
    }

    /// Accent row numbers for the selected rows and the hovered row.
    func setAccentRows(_ rows: IndexSet) {
        rowNumberView.accentRows = rows
    }

    func updateRowNumbers(count: Int) {
        reservedRowNumberCount = max(reservedRowNumberCount, count)
        rowNumberView.update(rowCount: count, reservedCount: reservedRowNumberCount)
        let width = showRowNumbers ? rowNumberView.requiredWidth : 0
        updateLeadingWidth(width)
    }

    func updateShowRowNumbers(_ show: Bool) {
        guard showRowNumbers != show else { return }
        showRowNumbers = show
        let width = show ? rowNumberView.requiredWidth : 0
        updateLeadingWidth(width)
    }

    private func updateLeadingWidth(_ width: CGFloat) {
        guard leadingWidthConstraint?.constant != width else { return }
        leadingWidthConstraint?.constant = width
        rowNumberView.isHidden = width == 0
        needsLayout = true
    }

    func updateBackgroundColor(_ color: NSColor) {
        backgroundColor = color
        rowNumberView.layer?.backgroundColor = color.cgColor
        footerOverlay.update(edgeColor: color)
    }

    func setRowNumberCallbacks(
        onSelect: @escaping (Int) -> Void,
        onExtendSelect: @escaping (Int) -> Void,
        onDrag: @escaping (NSEvent) -> Void,
        onDragEnded: @escaping () -> Void,
        onContextMenu: @escaping (Int) -> NSMenu?
    ) {
        rowNumberView.onRowSelect = onSelect
        rowNumberView.onRowExtendSelect = onExtendSelect
        rowNumberView.onRowDragEvent = onDrag
        rowNumberView.onRowDragEnded = onDragEnded
        rowNumberView.onRowContextMenu = onContextMenu
    }

    var tableView: NSTableView? {
        scrollView.documentView as? NSTableView
    }
}
