#if os(macOS)
import SwiftUI
import AppKit
import Combine
import OSLog

extension QueryResultsTableView {
    @MainActor
    final class Coordinator: NSObject {
        var parent: QueryResultsTableView
        var queryState: QueryEditorState
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
        var isDraggingRowSelection = false
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
        var pendingClearColumnHighlightNotification = false
        nonisolated(unsafe) var rowCountUpdateWorkItem: DispatchWorkItem?
        var lastObservedExecutionGeneration: Int = 0
        static let isGridDiagnosticsEnabled = false

        init(_ parent: QueryResultsTableView, queryState: QueryEditorState, clipboardHistory: ClipboardHistoryStore, persistedState: QueryResultsGridState?) {
            self.parent = parent
            self.queryState = queryState
            self.clipboardHistory = clipboardHistory
            self.persistedState = persistedState
            // Sync with the current execution generation so that a tab switch
            // (which creates a fresh Coordinator) is not mistaken for a new query run.
            self.lastObservedExecutionGeneration = parent.executionGeneration
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

        /// Resets all cached state for a new query execution. This is called when
        /// `executionGeneration` changes, replacing the old `.id()` approach that
        /// destroyed and recreated the entire NSViewRepresentable + Coordinator.
        func resetForNewExecution(tableView: NSTableView) {
            // Cancel pending work
            autoscrollTimer?.invalidate(); autoscrollTimer = nil
            pendingPaletteRefresh?.cancel(); pendingPaletteRefresh = nil
            for item in pendingReloadWorkItems { item.cancel() }
            pendingReloadWorkItems.removeAll()
            rowCountUpdateWorkItem?.cancel(); rowCountUpdateWorkItem = nil
            scrollPaginationWorkItem?.cancel(); scrollPaginationWorkItem = nil

            // Clear column caches
            cachedColumnIDs.removeAll()
            cachedColumnKinds.removeAll()

            // Clear row state
            cachedRowOrder.removeAll()
            cachedSort = nil
            lastRowCount = 0
            lastResultTokenSnapshot = 0
            cachedDisplayedRows.clear()
            pendingRowCountCorrection = false

            // Clear selection
            selectionRegion = nil
            selectionAnchor = nil
            selectionFocus = nil
            columnSelectionAnchor = nil
            isDraggingCellSelection = false
            isDraggingRowSelection = false
            contextMenuCell = nil
            activeSelectableField = nil
            autoscrollVelocity = .zero
            lastDragLocationInWindow = .zero
            tableView.deselectAll(nil)

            // Clear style/appearance caches
            cachedPaletteSignature = nil
            cachedFontStyles.removeAll(keepingCapacity: true)
            cachedResultGridStyles.removeAll(keepingCapacity: true)
            cachedTextColors.removeAll(keepingCapacity: true)

            // Clear foreign key state
            requestedForeignKeyColumns.removeAll()
            lastForeignKeySelection = nil
            lastJsonSelection = nil

            // Clear viewport/pagination state
            cachedViewportSize = .zero
            lastPaginationVisibleRange = NSRange(location: NSNotFound, length: 0)
            pendingPaginationEvaluation = false
            pendingTableSizeAdjustment = false
            pendingClearColumnHighlightNotification = false
            lastParentIsResizing = false
            lastSelectionHighlightStyle = nil

            // Clear persisted grid state caches (not column widths — those survive)
            if let state = persistedState {
                state.cachedColumnIDs.removeAll()
                state.cachedRowOrder.removeAll()
                state.cachedSort = nil
                state.lastRowCount = 0
                state.lastResultToken = 0
                state.hiddenColumnIndices.removeAll()
                state.selectedRowIndex = nil
                state.selectedColumnIndex = nil
            }

            // Rebuild columns and reload table from scratch
            while tableView.tableColumns.count > 0 {
                tableView.removeTableColumn(tableView.tableColumns[0])
            }
            addDataColumns(to: tableView)
            applyHeaderStyle(to: tableView)
            tableView.reloadData()
            refreshVisibleRowBackgrounds(tableView)
            adjustTableSize()
            requestPaginationEvaluation()
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
            tableView.usesAlternatingRowBackgroundColors = parent.alternateRowShading
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

        func syncPersistedSelection() {
            guard let persistedState else { return }
            persistedState.selectedRowIndex = selectionFocus?.row ?? selectionRegion?.normalizedRowRange.lowerBound
            persistedState.selectedColumnIndex = selectionFocus?.column ?? selectionRegion?.normalizedColumnRange.lowerBound
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
            Logger.grid.debug("\(message)")
        }

        var isDraggingSelection: Bool {
            isDraggingCellSelection || isDraggingRowSelection
        }

        func notifyClearColumnHighlight() {
            if isPerformingUpdatePass {
                guard !pendingClearColumnHighlightNotification else { return }
                pendingClearColumnHighlightNotification = true
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    pendingClearColumnHighlightNotification = false
                    parent.onClearColumnHighlight()
                }
                return
            }

            parent.onClearColumnHighlight()
        }
    }
}
#endif
