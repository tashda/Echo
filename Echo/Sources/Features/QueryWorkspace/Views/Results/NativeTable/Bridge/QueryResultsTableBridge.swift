#if os(macOS)
import SwiftUI
import AppKit
import Combine

extension QueryResultsTableView {
    @MainActor
    final class Coordinator: NSObject {
        var parent: QueryResultsTableView
        let clipboardHistory: ClipboardHistoryStore
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        weak var observedContentView: NSView?
        let headerMenu = NSMenu()
        let cellMenu = NSMenu()
        var menuColumnIndex: Int?
        var cachedColumnIDs: [String] = []
        var cachedColumnKinds: [ResultGridValueKind] = []
        var cachedRowOrder: [Int] = []
        var cachedSort: SortCriteria?
        var lastRowCount: Int = 0
        var lastResultTokenSnapshot: UInt64 = 0
        var persistedState: QueryResultsGridState?
        var selectionRegion: SelectedRegion?
        var selectionAnchor: QueryResultsTableView.SelectedCell?
        var isDraggingCellSelection = false
        var selectionFocus: QueryResultsTableView.SelectedCell?
        var columnSelectionAnchor: Int?
        var contextMenuCell: QueryResultsTableView.SelectedCell?
        weak var activeSelectableField: NSTextField?
        var cachedPaletteSignature: String?
        var cachedFontStyles: [SQLEditorTokenPalette.ResultGridStyle: NSFont] = [:]
        let cellBaseFont = NSFont.systemFont(ofSize: 12)
        var lastForeignKeySelection: QueryResultsTableView.ForeignKeySelection?
        var lastJsonSelection: QueryResultsTableView.JsonSelection?
        var cachedViewportSize: CGSize = .zero
        var pendingPaginationEvaluation = false
        var pendingTableSizeAdjustment = false
        var lastParentIsResizing = false
        var requestedForeignKeyColumns: Set<Int> = []
        var lastSelectionHighlightStyle: NSTableView.SelectionHighlightStyle?
        var cachedDisplayedRows = ResultTableRowCache()
        var cachedResultGridStyles: [ResultGridValueKind: SQLEditorTokenPalette.ResultGridStyle] = [:]
        var cachedTextColors: [ResultGridValueKind: NSColor] = [:]
        lazy var cachedRowBackgroundColor: NSColor = NSColor(ColorTokens.Background.tertiary)
        var autoscrollTimer: Timer?
        var autoscrollVelocity: CGPoint = .zero
        var lastDragLocationInWindow: NSPoint = .zero
        let autoscrollPadding: CGFloat = 28
        let autoscrollMaxSpeed: CGFloat = 900
        let defaultAutoscrollInterval: TimeInterval = 1.0 / 60.0
        var autoscrollTimerInterval: TimeInterval = 1.0 / 60.0
        var pendingReloadWorkItems: [DispatchWorkItem] = []
        var pendingRowCountCorrection = false
        var pendingPaletteRefresh: Task<Void, Never>?
        var scrollPaginationWorkItem: DispatchWorkItem?
        var lastPaginationVisibleRange: NSRange = NSRange(location: NSNotFound, length: 0)
        var isSplitResizing = false
        var isResizingColumn = false
        nonisolated(unsafe) var columnResizeObserver: NSObjectProtocol?
        nonisolated(unsafe) var rowCountObserver: NSObjectProtocol?
        var isPerformingUpdatePass = false
        nonisolated(unsafe) var rowCountUpdateWorkItem: DispatchWorkItem?
        static let isGridDiagnosticsEnabled: Bool = {
            ProcessInfo.processInfo.environment["ECHO_GRID_DEBUG"] == "1"
        }()

        init(_ parent: QueryResultsTableView, clipboardHistory: ClipboardHistoryStore, persistedState: QueryResultsGridState?) {
            self.parent = parent
            self.clipboardHistory = clipboardHistory
            self.persistedState = persistedState
            if let state = persistedState {
                self.cachedColumnIDs = state.cachedColumnIDs
                self.cachedRowOrder = state.cachedRowOrder
                self.cachedSort = state.cachedSort
                self.lastRowCount = state.lastRowCount
                self.lastResultTokenSnapshot = state.lastResultToken
            }
            super.init()
            headerMenu.delegate = self
            cellMenu.delegate = self
        }

        deinit {
            if let observer = rowCountObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            if let observer = columnResizeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            NotificationCenter.default.removeObserver(self)
            rowCountUpdateWorkItem?.cancel()
        }

        func configure(tableView: NSTableView, scrollView: NSScrollView) {
            self.tableView = tableView
            self.scrollView = scrollView
            registerScrollObservation(for: scrollView)
            registerColumnResizeObservation(for: tableView)
            tableView.delegate = self
            tableView.dataSource = self
            tableView.menu = cellMenu
            tableView.headerView?.menu = headerMenu
            tableView.headerView?.frame.size.height = max(tableView.headerView?.frame.size.height ?? 0, 28)
            tableView.headerView?.isHidden = false
            tableView.selectionHighlightStyle = .regular
            tableView.usesAlternatingRowBackgroundColors = false
            _ = reloadColumns()
            applyHeaderStyle(to: tableView)
            refreshVisibleRowBackgrounds(tableView)
            cachedPaletteSignature = paletteSignature()

            adjustTableSize()
            requestedForeignKeyColumns.removeAll()
        }

        func updatePersistedState(_ state: QueryResultsGridState?) {
            guard persistedState !== state else { return }
            persistedState = state
            installRowCountObserver(for: state)
            if let state {
                cachedColumnIDs = state.cachedColumnIDs
                cachedRowOrder = state.cachedRowOrder
                cachedSort = state.cachedSort
                lastRowCount = state.lastRowCount
                lastResultTokenSnapshot = state.lastResultToken
            }
        }

        // Helper methods
        func resolvedFont(for style: SQLEditorTokenPalette.ResultGridStyle) -> NSFont {
            if let cached = cachedFontStyles[style] {
                return cached
            }
            var traits: NSFontTraitMask = []
            if style.isBold { traits.insert(.boldFontMask) }
            if style.isItalic { traits.insert(.italicFontMask) }
            let font: NSFont
            if traits.isEmpty {
                font = cellBaseFont
            } else {
                font = NSFontManager.shared.convert(cellBaseFont, toHaveTrait: traits)
            }
            cachedFontStyles[style] = font
            return font
        }

        func paletteSignature() -> String {
            let overrides = parent.colorOverrides
            // Use override hex values and appearance as signature — avoid creating NSColor objects every call
            let appearance = AppearanceStore.shared.effectiveColorScheme == .dark ? "dark" : "light"
            return [
                appearance,
                overrides.nullHex ?? "",
                overrides.numericHex ?? "",
                overrides.booleanHex ?? "",
                overrides.temporalHex ?? "",
                overrides.binaryHex ?? "",
                overrides.identifierHex ?? "",
                overrides.jsonHex ?? "",
                overrides.textHex ?? ""
            ].joined(separator: "|")
        }

        func colorSignature(_ color: NSColor) -> String {
            guard let converted = color.usingColorSpace(.extendedSRGB) else { return color.description }
            func fmt(_ value: CGFloat) -> String { String(format: "%.4f", value) }
            return [converted.redComponent, converted.greenComponent, converted.blueComponent, converted.alphaComponent].map(fmt).joined(separator: ",")
        }

        func debugLog(_ message: String) {
            guard Coordinator.isGridDiagnosticsEnabled else { return }
            print("[GridDebug] \(message)")
        }
    }
}
#endif
