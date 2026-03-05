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
        var lastForeignKeyDisplayMode: ForeignKeyDisplayMode?
        var lastForeignKeyInspectorBehavior: ForeignKeyInspectorBehavior?
        var lastJsonSelection: QueryResultsTableView.JsonSelection?
        var cachedViewportSize: CGSize = .zero
        var pendingPaginationEvaluation = false
        var pendingTableSizeAdjustment = false
        var lastParentIsResizing = false
        var requestedForeignKeyColumns: Set<Int> = []
        var lastSelectionHighlightStyle: NSTableView.SelectionHighlightStyle?
        var cachedDisplayedRows: [Int: [String?]] = [:]
        var cachedResultGridStyles: [ResultGridValueKind: SQLEditorTokenPalette.ResultGridStyle] = [:]
        var cachedTextColors: [ResultGridValueKind: NSColor] = [:]
        var autoscrollTimer: Timer?
        var autoscrollVelocity: CGPoint = .zero
        var lastDragLocationInWindow: NSPoint = .zero
        let autoscrollPadding: CGFloat = 28
        let autoscrollMaxSpeed: CGFloat = 900
        let defaultAutoscrollInterval: TimeInterval = 1.0 / 60.0
        var autoscrollTimerInterval: TimeInterval = 1.0 / 60.0
        var pendingReloadWorkItems: [DispatchWorkItem] = []
        var pendingRowCountCorrection = false
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
            NotificationCenter.default.removeObserver(self)
            rowCountUpdateWorkItem?.cancel()
        }

        func configure(tableView: NSTableView, scrollView: NSScrollView) {
            self.tableView = tableView
            self.scrollView = scrollView
            registerScrollObservation(for: scrollView)
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
            lastForeignKeyDisplayMode = parent.foreignKeyDisplayMode
            lastForeignKeyInspectorBehavior = parent.foreignKeyInspectorBehavior
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
            return [
                "true",
                "false",
                colorSignature(NSColor(ColorTokens.Background.tertiary)),
                colorSignature(NSColor(ColorTokens.Background.tertiary)),
                colorSignature(NSColor(ColorTokens.Text.primary)),
                colorSignature(NSColor(ColorTokens.Background.secondary)),
                colorSignature(NSColor(ColorTokens.Text.primary))
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
