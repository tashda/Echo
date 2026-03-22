import SwiftUI
import AppKit

/// Enables double-click-to-fit on column dividers for SwiftUI `Table` views.
///
/// SwiftUI's `Table` wraps `NSTableView` but does not expose the delegate method
/// `tableView(_:sizeToFitWidthOfColumn:)`. This modifier introspects the view
/// hierarchy to find the underlying `NSTableView` and installs a delegate proxy
/// that provides the auto-resize behavior.
///
/// Usage:
/// ```swift
/// Table(data, selection: $selection, sortOrder: $sortOrder) {
///     TableColumn("Name") { ... }
/// }
/// .tableStyle(.inset(alternatesRowBackgrounds: true))
/// .tableColumnAutoResize()
/// ```
struct TableColumnAutoResizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TableColumnAutoResizeInstaller())
    }
}

extension View {
    /// Enables double-click-to-fit column resizing on SwiftUI Tables.
    func tableColumnAutoResize() -> some View {
        modifier(TableColumnAutoResizeModifier())
    }
}

// MARK: - NSView Introspection

/// An invisible NSViewRepresentable that walks the view hierarchy to find
/// the enclosing NSTableView and installs a delegate proxy.
private struct TableColumnAutoResizeInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = TableAutoResizeAnchorView()
        view.setFrameSize(.zero)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Anchor view that finds and configures the parent NSTableView on layout.
private final class TableAutoResizeAnchorView: NSView {
    private var isInstalled = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installIfNeeded()
    }

    override func layout() {
        super.layout()
        installIfNeeded()
    }

    private func installIfNeeded() {
        guard !isInstalled, window != nil else { return }
        // Walk up the hierarchy to find the NSTableView
        if let tableView = findTableView(in: self) {
            TableDelegateProxy.install(on: tableView)
            isInstalled = true
        }
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        // Walk up the superview chain
        var current: NSView? = view.superview
        while let v = current {
            if let tableView = v as? NSTableView {
                return tableView
            }
            // Also check inside scroll views
            if let scrollView = v as? NSScrollView,
               let tableView = scrollView.documentView as? NSTableView {
                return tableView
            }
            current = v.superview
        }
        return nil
    }
}

// MARK: - Delegate Proxy

/// A delegate proxy that intercepts `sizeToFitWidthOfColumn` while forwarding
/// all other delegate calls to the original SwiftUI-managed delegate.
private final class TableDelegateProxy: NSObject, NSTableViewDelegate {
    private weak var originalDelegate: (any NSTableViewDelegate)?
    private weak var tableView: NSTableView?

    @MainActor
    static func install(on tableView: NSTableView) {
        // Don't install twice
        if tableView.delegate is TableDelegateProxy { return }

        let proxy = TableDelegateProxy()
        proxy.originalDelegate = tableView.delegate
        proxy.tableView = tableView
        // Hold a strong reference via associated objects so it stays alive
        objc_setAssociatedObject(tableView, &AssociatedKeys.proxy, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        tableView.delegate = proxy
    }

    // MARK: - Size to Fit

    func tableView(_ tableView: NSTableView, sizeToFitWidthOfColumn column: Int) -> CGFloat {
        guard column >= 0, column < tableView.tableColumns.count else {
            return tableView.tableColumns[safe: column]?.width ?? 80
        }

        let tableColumn = tableView.tableColumns[column]
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return tableColumn.width }

        // Measure the header
        var maxWidth: CGFloat = 0
        let headerCell = tableColumn.headerCell
        let headerSize = headerCell.cellSize(forBounds: NSRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: tableView.headerView?.frame.height ?? 22))
        maxWidth = headerSize.width + 8

        // Measure visible rows for performance (don't scan thousands of rows)
        let visibleRange = tableView.rows(in: tableView.visibleRect)
        let scanRange = visibleRange.length > 0 ? visibleRange : NSRange(location: 0, length: min(rowCount, 100))

        for row in scanRange.location ..< (scanRange.location + scanRange.length) {
            guard row < rowCount else { break }
            if let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: true) {
                let fittingSize = cellView.fittingSize
                maxWidth = max(maxWidth, fittingSize.width + 12) // padding for cell margins
            }
        }

        // Clamp to reasonable bounds
        return max(maxWidth, 30).rounded(.up)
    }

    // MARK: - Forwarding

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(NSTableViewDelegate.tableView(_:sizeToFitWidthOfColumn:)) {
            return true
        }
        return super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if originalDelegate?.responds(to: aSelector) == true {
            return originalDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }

    private enum AssociatedKeys {
        nonisolated(unsafe) static var proxy: UInt8 = 0
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
