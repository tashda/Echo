#if os(iOS)
import SwiftUI
import UIKit

struct QueryResultsGridRepresentable: UIViewControllerRepresentable {
    var query: QueryEditorState
    var highlightedColumnIndex: Int?
    var activeSort: SortCriteria?
    var rowOrder: [Int]
    var onColumnTap: (Int) -> Void
    var onSort: (Int, ResultGridSortAction) -> Void
    var onClearColumnHighlight: () -> Void
    var themeManager: ThemeManager
    var clipboardHistory: ClipboardHistoryStore

    func makeUIViewController(context: Context) -> ResultGridViewController {
        ResultGridViewController()
    }

    func updateUIViewController(_ controller: ResultGridViewController, context: Context) {
        controller.update(
            with: .init(
                query: query,
                highlightedColumnIndex: highlightedColumnIndex,
                activeSort: activeSort,
                rowOrder: rowOrder,
                onColumnTap: onColumnTap,
                onSort: onSort,
                onClearColumnHighlight: onClearColumnHighlight,
                themeManager: themeManager,
                clipboardHistory: clipboardHistory
            )
        )
    }
}

final class ResultGridViewController: UIViewController {
    struct Configuration {
        let query: QueryEditorState
        let highlightedColumnIndex: Int?
        let activeSort: SortCriteria?
        let rowOrder: [Int]
        let onColumnTap: (Int) -> Void
        let onSort: (Int, ResultGridSortAction) -> Void
        let onClearColumnHighlight: () -> Void
        let themeManager: ThemeManager
        let clipboardHistory: ClipboardHistoryStore
    }

    private let layout = ResultGridLayout()
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.contentInset = .zero
        view.scrollIndicatorInsets = .zero
        view.keyboardDismissMode = .interactive
        view.showsVerticalScrollIndicator = true
        view.showsHorizontalScrollIndicator = true
        view.register(ResultGridCell.self, forCellWithReuseIdentifier: ResultGridCell.reuseIdentifier)
        return view
    }()

    private var columns: [ColumnInfo] = []
    private var rowOrder: [Int] = []
    private var displayedRowCount: Int = 0
    private weak var query: QueryEditorState?
    private var highlightedColumnIndex: Int?
    private var activeSort: SortCriteria?
    private var onColumnTap: ((Int) -> Void)?
    private var onSort: ((Int, ResultGridSortAction) -> Void)?
    private var onClearColumnHighlight: (() -> Void)?
    private var palette = ResultGridPalette.default
    private var themeManager: ThemeManager?
    private var cachedColumnIDs: [String] = []
    private var cachedRowCount: Int = 0
    private var cachedRowOrder: [Int] = []
    private weak var clipboardHistory: ClipboardHistoryStore?
    private var selectionRegion: SelectedRegion?
    private var selectionAnchor: SelectedCell?
    private var selectionFocus: SelectedCell?
    private var rowSelectionAnchor: Int?
    private var columnSelectionAnchor: Int?
    private var dragContext: DragContext?

    private lazy var tapGesture: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        recognizer.delegate = self
        return recognizer
    }()

    private lazy var doubleTapGesture: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        recognizer.delegate = self
        return recognizer
    }()

    private lazy var longPressGesture: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.15
        recognizer.delegate = self
        return recognizer
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        collectionView.addGestureRecognizer(doubleTapGesture)
        collectionView.addGestureRecognizer(tapGesture)
        tapGesture.require(toFail: doubleTapGesture)
        collectionView.addGestureRecognizer(longPressGesture)
        collectionView.delaysContentTouches = false
        collectionView.canCancelContentTouches = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let themeManager else { return }
        palette = ResultGridPalette(themeManager: themeManager, traitCollection: traitCollection)
        refreshVisibleCells()
    }

    override var canBecomeFirstResponder: Bool { true }

    func update(with configuration: Configuration) {
        query = configuration.query
        onColumnTap = configuration.onColumnTap
        onSort = configuration.onSort
        onClearColumnHighlight = configuration.onClearColumnHighlight
        highlightedColumnIndex = configuration.highlightedColumnIndex
        activeSort = configuration.activeSort
        clipboardHistory = configuration.clipboardHistory
        themeManager = configuration.themeManager
        rowOrder = configuration.rowOrder
        palette = ResultGridPalette(themeManager: configuration.themeManager, traitCollection: traitCollection)

        columns = configuration.query.displayedColumns
        let resolvedRowCount: Int
        if !rowOrder.isEmpty {
            resolvedRowCount = rowOrder.count
        } else {
            resolvedRowCount = configuration.query.displayedRowCount
        }
        displayedRowCount = max(0, resolvedRowCount)

        updateLayoutIfNeeded()
        reloadIfNeeded()
        refreshVisibleCells()
    }

    private func updateLayoutIfNeeded() {
        guard !columns.isEmpty else {
            layout.configure(columnWidths: [], numberOfSections: 0)
            return
        }

        var widths: [CGFloat] = [Metrics.indexColumnWidth]
        widths.append(contentsOf: columns.map(widthForColumn(_:)))
        layout.configure(columnWidths: widths, numberOfSections: displayedRowCount + 1)
        collectionView.backgroundColor = palette.background
    }

    private func reloadIfNeeded() {
        let columnIDs = columns.map(\.id)
        let columnsChanged = columnIDs != cachedColumnIDs
        let rowCountChanged = displayedRowCount != cachedRowCount
        let rowOrderChanged = rowOrder != cachedRowOrder

        if columnsChanged || rowCountChanged || rowOrderChanged {
            cachedColumnIDs = columnIDs
            cachedRowCount = displayedRowCount
            cachedRowOrder = rowOrder
            selectionRegion = nil
            selectionAnchor = nil
            selectionFocus = nil
            rowSelectionAnchor = nil
            columnSelectionAnchor = nil
            dragContext = nil
            collectionView.reloadData()
        }
    }

    private func refreshVisibleCells() {
        guard !columns.isEmpty else { return }
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? ResultGridCell else { continue }
            configure(cell: cell, at: indexPath)
        }
    }

    private func widthForColumn(_ column: ColumnInfo) -> CGFloat {
        let type = column.dataType.lowercased()
        if type.contains("bool") { return 80 }
        if type.contains("int") || type.contains("numeric") || type.contains("decimal") || type.contains("float") || type.contains("double") || type.contains("money") {
            return 120
        }
        if type.contains("date") || type.contains("time") {
            return 160
        }
        return 200
    }

    private func resolvedDataRowIndex(forDisplayed row: Int) -> Int {
        if !rowOrder.isEmpty, row >= 0, row < rowOrder.count {
            return rowOrder[row]
        }
        return row
    }

    private func valueForDisplay(row: Int, column: Int) -> String? {
        guard let query = query else { return nil }
        let dataRow = resolvedDataRowIndex(forDisplayed: row)
        guard dataRow >= 0, dataRow < query.totalAvailableRowCount else { return nil }
        return query.valueForDisplay(row: dataRow, column: column)
    }

    private func isRowInSelection(_ row: Int) -> Bool {
        selectionRegion?.containsRow(row) ?? false
    }

    private func isColumnInSelection(_ column: Int) -> Bool {
        selectionRegion?.containsColumn(column) ?? false
    }

    private func isColumnHighlighted(_ column: Int) -> Bool {
        if isColumnInSelection(column) { return true }
        if let highlightedColumnIndex, highlightedColumnIndex == column { return true }
        return false
    }

    private func isCellSelected(row: Int, column: Int) -> Bool {
        guard let region = selectionRegion else { return false }
        return region.contains(SelectedCell(row: row, column: column))
    }

    private func isAlternateRow(_ row: Int) -> Bool {
        palette.alternateRow != nil && row % 2 == 1
    }

    private func sortIndicator(for columnIndex: Int) -> SortIndicator? {
        guard columnIndex >= 0, columnIndex < columns.count else { return nil }
        guard let activeSort else { return nil }
        return activeSort.column == columns[columnIndex].name
            ? (activeSort.ascending ? .ascending : .descending)
            : nil
    }

    private func configure(cell: ResultGridCell, at indexPath: IndexPath) {
        guard !columns.isEmpty else { return }
        if indexPath.section == 0 {
            if indexPath.item == 0 {
                cell.configure(
                    text: "#",
                    kind: .headerIndex,
                    palette: palette,
                    isHighlightedColumn: false,
                    isRowSelected: false,
                    isCellSelected: false,
                    sortIndicator: nil,
                    isNullValue: false,
                    isAlternateRow: false
                )
            } else {
                let columnIndex = indexPath.item - 1
                guard columnIndex < columns.count else { return }
                let column = columns[columnIndex]
                let highlighted = isColumnHighlighted(columnIndex)
                cell.configure(
                    text: column.name,
                    kind: .header,
                    palette: palette,
                    isHighlightedColumn: highlighted,
                    isRowSelected: false,
                    isCellSelected: false,
                    sortIndicator: sortIndicator(for: columnIndex),
                    isNullValue: false,
                    isAlternateRow: false
                )
            }
        } else {
            let rowIndex = indexPath.section - 1
            guard rowIndex < displayedRowCount else { return }
            if indexPath.item == 0 {
                let rowSelected = isRowInSelection(rowIndex)
                cell.configure(
                    text: "\(rowIndex + 1)",
                    kind: .rowIndex,
                    palette: palette,
                    isHighlightedColumn: false,
                    isRowSelected: rowSelected,
                    isCellSelected: rowSelected,
                    sortIndicator: nil,
                    isNullValue: false,
                    isAlternateRow: false
                )
            } else {
                let columnIndex = indexPath.item - 1
                guard columnIndex < columns.count else { return }
                let value = valueForDisplay(row: rowIndex, column: columnIndex)
                let column = columns[columnIndex]
                let valueKind = ResultGridValueClassifier.kind(for: column, value: value)
                let text = value ?? "NULL"
                let isNull = value == nil
                let highlighted = isColumnHighlighted(columnIndex)
                let rowSelected = isRowInSelection(rowIndex)
                let cellSelected = isCellSelected(row: rowIndex, column: columnIndex)
                cell.configure(
                    text: text,
                    kind: .data,
                    palette: palette,
                    isHighlightedColumn: highlighted,
                    isRowSelected: rowSelected,
                    isCellSelected: cellSelected,
                    sortIndicator: nil,
                    isNullValue: isNull,
                    isAlternateRow: isAlternateRow(rowIndex),
                    valueKind: valueKind
                )
            }
        }
    }

    private func beginColumnSelection(at column: Int) {
        guard !columns.isEmpty, displayedRowCount > 0 else { return }
        let clamped = max(0, min(column, columns.count - 1))
        columnSelectionAnchor = clamped
        let lastRow = max(0, displayedRowCount - 1)
        let start = SelectedCell(row: 0, column: clamped)
        let end = SelectedCell(row: lastRow, column: clamped)
        selectionAnchor = start
        selectionFocus = end
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollColumnIntoView(clamped)
        becomeFirstResponder()
    }

    private func continueColumnSelection(to column: Int) {
        guard let anchor = columnSelectionAnchor,
              displayedRowCount > 0,
              !columns.isEmpty else { return }
        let clamped = max(0, min(column, columns.count - 1))
        let lower = min(anchor, clamped)
        let upper = max(anchor, clamped)
        let lastRow = max(0, displayedRowCount - 1)
        let start = SelectedCell(row: 0, column: lower)
        let end = SelectedCell(row: lastRow, column: upper)
        selectionAnchor = start
        selectionFocus = SelectedCell(row: lastRow, column: clamped)
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollColumnIntoView(clamped)
        becomeFirstResponder()
    }

    private func beginRowSelection(at row: Int) {
        guard !columns.isEmpty, displayedRowCount > 0 else { return }
        let clamped = max(0, min(row, displayedRowCount - 1))
        rowSelectionAnchor = clamped
        let lastColumn = columns.count - 1
        let start = SelectedCell(row: clamped, column: 0)
        let end = SelectedCell(row: clamped, column: lastColumn)
        selectionAnchor = start
        selectionFocus = end
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollRowIntoView(clamped)
        becomeFirstResponder()
    }

    private func continueRowSelection(to row: Int) {
        guard let anchor = rowSelectionAnchor,
              !columns.isEmpty,
              displayedRowCount > 0 else { return }
        let clamped = max(0, min(row, displayedRowCount - 1))
        let lower = min(anchor, clamped)
        let upper = max(anchor, clamped)
        let lastColumn = columns.count - 1
        let start = SelectedCell(row: lower, column: 0)
        let end = SelectedCell(row: upper, column: lastColumn)
        selectionAnchor = start
        selectionFocus = SelectedCell(row: clamped, column: lastColumn)
        setSelectionRegion(SelectedRegion(start: start, end: end))
        scrollRowIntoView(clamped)
        becomeFirstResponder()
    }

    private func beginCellSelection(at cell: SelectedCell) {
        selectionAnchor = cell
        selectionFocus = cell
        setSelectionRegion(SelectedRegion(start: cell, end: cell))
        scrollRowIntoView(cell.row)
        scrollColumnIntoView(cell.column)
        becomeFirstResponder()
    }

    private func continueCellSelection(to cell: SelectedCell, extend: Bool) {
        ensureSelectionSeed()
        if extend, let anchor = selectionAnchor {
            let region = SelectedRegion(start: anchor, end: cell)
            selectionFocus = cell
            setSelectionRegion(region)
        } else {
            selectionAnchor = cell
            selectionFocus = cell
            setSelectionRegion(SelectedRegion(start: cell, end: cell))
        }
        scrollRowIntoView(cell.row)
        scrollColumnIntoView(cell.column)
        becomeFirstResponder()
    }

    private func finalizeDragSelection() {
        dragContext = nil
        columnSelectionAnchor = nil
        rowSelectionAnchor = nil
    }

    private func scrollRowIntoView(_ row: Int) {
        guard row >= 0, row < displayedRowCount else { return }
        let indexPath = IndexPath(item: 1, section: row + 1)
        collectionView.scrollToItem(at: indexPath, at: [.centeredVertically], animated: false)
    }

    private func scrollColumnIntoView(_ column: Int) {
        guard column >= 0, column < columns.count else { return }
        let indexPath = IndexPath(item: column + 1, section: 1)
        collectionView.scrollToItem(at: indexPath, at: [.centeredHorizontally], animated: false)
    }

    private func moveSelection(rowDelta: Int, columnDelta: Int, extend: Bool) {
        guard displayedRowCount > 0, !columns.isEmpty else { return }
        ensureSelectionSeed()
        guard var focus = selectionFocus ?? selectionRegion?.end else { return }

        if rowDelta == Int.max {
            focus.row = displayedRowCount - 1
        } else if rowDelta == -Int.max {
            focus.row = 0
        } else {
            focus.row = max(0, min(displayedRowCount - 1, focus.row + rowDelta))
        }

        if columnDelta == Int.max {
            focus.column = columns.count - 1
        } else if columnDelta == -Int.max {
            focus.column = 0
        } else {
            focus.column = max(0, min(columns.count - 1, focus.column + columnDelta))
        }

        if extend, let anchor = selectionAnchor {
            selectionFocus = focus
            setSelectionRegion(SelectedRegion(start: anchor, end: focus))
        } else {
            selectionAnchor = focus
            selectionFocus = focus
            setSelectionRegion(SelectedRegion(start: focus, end: focus))
        }

        scrollRowIntoView(focus.row)
        scrollColumnIntoView(focus.column)
    }

    private func pageJumpAmount() -> Int {
        let visibleHeight = collectionView.bounds.height
        return max(1, Int(visibleHeight / Metrics.rowHeight) - 1)
    }

    private func copySelection(includeHeaders: Bool) {
        guard let query = query, !columns.isEmpty else { return }
        let totalRows = query.totalAvailableRowCount
        guard totalRows > 0 else { return }

        let columnIndices: [Int]
        let rowIndices: [Int]

        if let region = selectionRegion {
            let lowerColumn = max(0, min(columns.count - 1, region.normalizedColumnRange.lowerBound))
            let upperColumn = max(0, min(columns.count - 1, region.normalizedColumnRange.upperBound))
            guard upperColumn >= lowerColumn else { return }
            columnIndices = Array(lowerColumn...upperColumn)

            let lowerRow = max(0, min(displayedRowCount - 1, region.normalizedRowRange.lowerBound))
            let upperRow = max(0, min(displayedRowCount - 1, region.normalizedRowRange.upperBound))
            guard upperRow >= lowerRow else { return }
            rowIndices = Array(lowerRow...upperRow)
        } else {
            rowIndices = Array(0..<displayedRowCount)
            columnIndices = Array(0..<columns.count)
        }

        guard !rowIndices.isEmpty, !columnIndices.isEmpty else { return }

        var lines: [String] = []
        if includeHeaders {
            let headers = columnIndices.map { columns[$0].name }
            lines.append(headers.joined(separator: "\t"))
        }

        for displayedRow in rowIndices {
            let dataRow = resolvedDataRowIndex(forDisplayed: displayedRow)
            guard dataRow >= 0, dataRow < totalRows else { continue }
            let values = columnIndices.map { query.valueForDisplay(row: dataRow, column: $0) ?? "" }
            lines.append(values.joined(separator: "\t"))
        }

        guard !lines.isEmpty else { return }

        let export = lines.joined(separator: "\n")
        PlatformClipboard.copy(export)
        clipboardHistory?.record(
            .resultGrid(includeHeaders: includeHeaders),
            content: export,
            metadata: query.clipboardMetadata
        )
    }

    private lazy var keyCommandList: [UIKeyCommand] = {
        [
            UIKeyCommand(input: "c", modifierFlags: .command, action: #selector(handleCopyCommand(_:)), discoverabilityTitle: "Copy"),
            UIKeyCommand(input: "c", modifierFlags: [.command, .shift], action: #selector(handleCopyWithHeadersCommand(_:)), discoverabilityTitle: "Copy with Headers"),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [.shift], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [.shift], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [.shift], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [.shift], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputPageUp, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputPageDown, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputHome, modifierFlags: [], action: #selector(handleArrowKey(_:))),
            UIKeyCommand(input: UIKeyCommand.inputEnd, modifierFlags: [], action: #selector(handleArrowKey(_:)))
        ]
    }()

    override var keyCommands: [UIKeyCommand]? {
        keyCommandList
    }

    @objc private func handleCopyCommand(_ command: UIKeyCommand) {
        copySelection(includeHeaders: false)
    }

    @objc private func handleCopyWithHeadersCommand(_ command: UIKeyCommand) {
        copySelection(includeHeaders: true)
    }

    @objc private func handleArrowKey(_ command: UIKeyCommand) {
        let extend = command.modifierFlags.contains(.shift)
        switch command.input {
        case UIKeyCommand.inputUpArrow:
            moveSelection(rowDelta: -1, columnDelta: 0, extend: extend)
        case UIKeyCommand.inputDownArrow:
            moveSelection(rowDelta: 1, columnDelta: 0, extend: extend)
        case UIKeyCommand.inputLeftArrow:
            moveSelection(rowDelta: 0, columnDelta: -1, extend: extend)
        case UIKeyCommand.inputRightArrow:
            moveSelection(rowDelta: 0, columnDelta: 1, extend: extend)
        case UIKeyCommand.inputPageUp:
            moveSelection(rowDelta: -pageJumpAmount(), columnDelta: 0, extend: extend)
        case UIKeyCommand.inputPageDown:
            moveSelection(rowDelta: pageJumpAmount(), columnDelta: 0, extend: extend)
        case UIKeyCommand.inputHome:
            moveSelection(rowDelta: -Int.max, columnDelta: 0, extend: extend)
        case UIKeyCommand.inputEnd:
            moveSelection(rowDelta: Int.max, columnDelta: 0, extend: extend)
        default:
            break
        }
    }

    private func setSelectionRegion(_ region: SelectedRegion?) {
        selectionRegion = region
        refreshVisibleCells()
    }

    private func ensureSelectionSeed() {
        guard selectionRegion == nil else { return }
        guard displayedRowCount > 0, !columns.isEmpty else { return }
        let seed = SelectedCell(row: 0, column: 0)
        selectionRegion = SelectedRegion(start: seed, end: seed)
        selectionAnchor = seed
        selectionFocus = seed
        refreshVisibleCells()
    }
}

// MARK: - Metrics & Supporting Types

private enum Metrics {
    static let indexColumnWidth: CGFloat = 56
    static let rowHeight: CGFloat = 32
    static let headerHeight: CGFloat = 36
    static let cellHorizontalPadding: CGFloat = 10
}

private struct SelectedCell: Equatable {
    var row: Int
    var column: Int
}

private struct SelectedRegion: Equatable {
    var start: SelectedCell
    var end: SelectedCell

    var normalizedRowRange: ClosedRange<Int> {
        let lower = min(start.row, end.row)
        let upper = max(start.row, end.row)
        return lower...upper
    }

    var normalizedColumnRange: ClosedRange<Int> {
        let lower = min(start.column, end.column)
        let upper = max(start.column, end.column)
        return lower...upper
    }

    func contains(_ cell: SelectedCell) -> Bool {
        normalizedRowRange.contains(cell.row) && normalizedColumnRange.contains(cell.column)
    }

    func containsRow(_ row: Int) -> Bool {
        normalizedRowRange.contains(row)
    }

    func containsColumn(_ column: Int) -> Bool {
        normalizedColumnRange.contains(column)
    }
}

private enum DragContext {
    case cells(anchor: SelectedCell)
    case row(anchor: Int)
    case column(anchor: Int)
}

private enum SortIndicator {
    case ascending
    case descending
}

private struct ResultGridPalette {
    struct ResultGridTextStyle {
        let color: UIColor
        let isBold: Bool
        let isItalic: Bool
    }

    let background: UIColor
    let headerBackground: UIColor
    let headerText: UIColor
    let primaryText: UIColor
    let secondaryText: UIColor
    let accent: UIColor
    let selectionFill: UIColor
    let columnHighlight: UIColor
    let rowHighlight: UIColor
    let alternateRow: UIColor?
    private let dataStyles: [ResultGridValueKind: ResultGridTextStyle]
    private let defaultDataStyle: ResultGridTextStyle

    static let `default` = ResultGridPalette(
        background: .systemBackground,
        headerBackground: .secondarySystemBackground,
        headerText: .label,
        primaryText: .label,
        secondaryText: .secondaryLabel,
        accent: .systemBlue,
        selectionFill: UIColor.systemBlue.withAlphaComponent(0.18),
        columnHighlight: UIColor.systemBlue.withAlphaComponent(0.1),
        rowHighlight: UIColor.systemBlue.withAlphaComponent(0.12),
        alternateRow: UIColor.systemGray6.withAlphaComponent(0.35),
        dataStyles: [
            .null: ResultGridTextStyle(color: .secondaryLabel, isBold: false, isItalic: true),
            .numeric: ResultGridTextStyle(color: .systemBlue, isBold: false, isItalic: false),
            .boolean: ResultGridTextStyle(color: .systemGreen, isBold: false, isItalic: false),
            .temporal: ResultGridTextStyle(color: .systemOrange, isBold: false, isItalic: false),
            .binary: ResultGridTextStyle(color: .systemPurple, isBold: false, isItalic: false),
            .identifier: ResultGridTextStyle(color: .systemIndigo, isBold: false, isItalic: false),
            .json: ResultGridTextStyle(color: .systemTeal, isBold: false, isItalic: false)
        ],
        defaultDataStyle: ResultGridTextStyle(color: .label, isBold: false, isItalic: false)
    )

    init(themeManager: ThemeManager, traitCollection: UITraitCollection) {
        let backgroundColor = themeManager.resultsGridBackgroundUIColor.resolvedColor(with: traitCollection)
        let accentColor = UIColor(themeManager.accentColor).resolvedColor(with: traitCollection)
        background = backgroundColor

        if themeManager.useAppThemeForResultsGrid {
            let surfaceBackground = UIColor(themeManager.surfaceBackground).resolvedColor(with: traitCollection)
            let surfaceForeground = UIColor(themeManager.surfaceForeground).resolvedColor(with: traitCollection)
            headerBackground = surfaceBackground
            headerText = surfaceForeground
            primaryText = surfaceForeground
            secondaryText = surfaceForeground.withAlphaComponent(0.7)
        } else {
            headerBackground = UIColor.secondarySystemBackground
            headerText = UIColor.label
            primaryText = UIColor.label
            secondaryText = UIColor.secondaryLabel
        }

        accent = accentColor
        selectionFill = accentColor.withAlphaComponent(0.18)
        columnHighlight = accentColor.withAlphaComponent(0.1)
        rowHighlight = accentColor.withAlphaComponent(0.12)

        if themeManager.resultsAlternateRowShading {
            let alternateBase = themeManager.resultsGridAlternateRowUIColor
            alternateRow = alternateBase.resolvedColor(with: traitCollection)
        } else {
            alternateRow = nil
        }

        if themeManager.useAppThemeForResultsGrid {
            func makeStyle(_ kind: ResultGridValueKind) -> ResultGridTextStyle {
                let style = themeManager.resultGridStyle(for: kind)
                return ResultGridTextStyle(
                    color: UIColor(style.swiftColor).resolvedColor(with: traitCollection),
                    isBold: style.isBold,
                    isItalic: style.isItalic
                )
            }
            dataStyles = [
                .null: makeStyle(.null),
                .numeric: makeStyle(.numeric),
                .boolean: makeStyle(.boolean),
                .temporal: makeStyle(.temporal),
                .binary: makeStyle(.binary),
                .identifier: makeStyle(.identifier),
                .json: makeStyle(.json)
            ]
            defaultDataStyle = makeStyle(.text)
        } else {
            dataStyles = [
                .null: ResultGridTextStyle(color: UIColor.secondaryLabel.withAlphaComponent(0.7), isBold: false, isItalic: true),
                .numeric: ResultGridTextStyle(color: .systemBlue, isBold: false, isItalic: false),
                .boolean: ResultGridTextStyle(color: .systemGreen, isBold: false, isItalic: false),
                .temporal: ResultGridTextStyle(color: .systemOrange, isBold: false, isItalic: false),
                .binary: ResultGridTextStyle(color: .systemPurple, isBold: false, isItalic: false),
                .identifier: ResultGridTextStyle(color: .systemIndigo, isBold: false, isItalic: false),
                .json: ResultGridTextStyle(color: .systemTeal, isBold: false, isItalic: false)
            ]
            defaultDataStyle = ResultGridTextStyle(color: .label, isBold: false, isItalic: false)
        }
    }

    private init(
        background: UIColor,
        headerBackground: UIColor,
        headerText: UIColor,
        primaryText: UIColor,
        secondaryText: UIColor,
        accent: UIColor,
        selectionFill: UIColor,
        columnHighlight: UIColor,
        rowHighlight: UIColor,
        alternateRow: UIColor?,
        dataStyles: [ResultGridValueKind: ResultGridTextStyle],
        defaultDataStyle: ResultGridTextStyle
    ) {
        self.background = background
        self.headerBackground = headerBackground
        self.headerText = headerText
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.selectionFill = selectionFill
        self.columnHighlight = columnHighlight
        self.rowHighlight = rowHighlight
        self.alternateRow = alternateRow
        self.dataStyles = dataStyles
        self.defaultDataStyle = defaultDataStyle
    }

    private static func mix(color: UIColor, with accent: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              accent.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return color.withAlphaComponent(0.9)
        }
        let inverse = 1 - amount
        return UIColor(red: r1 * inverse + r2 * amount,
                       green: g1 * inverse + g2 * amount,
                       blue: b1 * inverse + b2 * amount,
                       alpha: a1)
    }

    func style(for kind: ResultGridValueKind) -> ResultGridTextStyle {
        if let style = dataStyles[kind] {
            return style
        }
        return defaultDataStyle
    }
}

private final class ResultGridLayout: UICollectionViewLayout {
    private var columnWidths: [CGFloat] = []
    private var columnOffsets: [CGFloat] = []
    private var rowOffsets: [CGFloat] = []
    private var sections: Int = 0
    private var cachedBounds: CGRect = .zero
    private var contentSize: CGSize = .zero
    private var needsRecompute = true

    func configure(columnWidths: [CGFloat], numberOfSections: Int) {
        self.columnWidths = columnWidths
        sections = max(0, numberOfSections)
        needsRecompute = true
        invalidateLayout()
    }

    override func prepare() {
        super.prepare()
        if cachedBounds != bounds || needsRecompute {
            cachedBounds = bounds
            recomputeOffsets()
            needsRecompute = false
        }
    }

    override var collectionViewContentSize: CGSize { contentSize }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard !columnWidths.isEmpty, sections > 0 else { return [] }
        var attributes: [UICollectionViewLayoutAttributes] = []
        var visited = Set<IndexPath>()

        let rowRange = visibleRowRange(for: rect)
        let columnRange = visibleColumnRange(for: rect)

        func appendAttributes(for indexPath: IndexPath) {
            guard !visited.contains(indexPath),
                  let attr = layoutAttributesForItem(at: indexPath) else { return }
            visited.insert(indexPath)
            attributes.append(attr)
        }

        for section in rowRange {
            for item in columnRange {
                appendAttributes(for: IndexPath(item: item, section: section))
            }
        }

        // Ensure pinned header row and index column are included.
        for item in columnRange {
            appendAttributes(for: IndexPath(item: item, section: 0))
        }
        for section in rowRange {
            appendAttributes(for: IndexPath(item: 0, section: section))
        }
        appendAttributes(for: IndexPath(item: 0, section: 0))

        return attributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section >= 0,
              indexPath.section < sections,
              indexPath.item >= 0,
              indexPath.item < columnWidths.count,
              let collectionView else { return nil }

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        let x = columnOffsets[indexPath.item]
        let y = rowOffsets[indexPath.section]
        let width = columnWidths[indexPath.item]
        let height = indexPath.section == 0 ? Metrics.headerHeight : Metrics.rowHeight
        var frame = CGRect(x: x, y: y, width: width, height: height)

        let contentOffset = collectionView.contentOffset
        if indexPath.section == 0 {
            frame.origin.y = contentOffset.y
        }
        if indexPath.item == 0 {
            frame.origin.x = contentOffset.x
        }
        attributes.frame = frame
        if indexPath.section == 0 && indexPath.item == 0 {
            attributes.zIndex = 1000
        } else if indexPath.section == 0 {
            attributes.zIndex = 900
        } else if indexPath.item == 0 {
            attributes.zIndex = 800
        } else {
            attributes.zIndex = 0
        }
        return attributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        cachedBounds = newBounds
        return true
    }

    private var bounds: CGRect {
        collectionView?.bounds ?? .zero
    }

    private func recomputeOffsets() {
        columnOffsets = []
        var runningX: CGFloat = 0
        for width in columnWidths {
            columnOffsets.append(runningX)
            runningX += width
        }

        rowOffsets = []
        var runningY: CGFloat = 0
        for section in 0..<sections {
            rowOffsets.append(runningY)
            runningY += section == 0 ? Metrics.headerHeight : Metrics.rowHeight
        }

        contentSize = CGSize(width: runningX, height: runningY)
    }

    private func visibleRowRange(for rect: CGRect) -> ClosedRange<Int> {
        guard sections > 0 else { return 0...0 }
        let minRow = max(0, rowIndex(for: rect.minY))
        let maxRow = min(sections - 1, rowIndex(for: rect.maxY))
        return minRow...maxRow
    }

    private func visibleColumnRange(for rect: CGRect) -> ClosedRange<Int> {
        guard !columnWidths.isEmpty else { return 0...0 }
        let minColumn = max(0, columnIndex(for: rect.minX))
        let maxColumn = min(columnWidths.count - 1, columnIndex(for: rect.maxX))
        return minColumn...maxColumn
    }

    private func rowIndex(for position: CGFloat) -> Int {
        guard !rowOffsets.isEmpty else { return 0 }
        let clamped = max(0, min(position, contentSize.height))
        for index in 0..<rowOffsets.count {
            let origin = rowOffsets[index]
            let height = index == 0 ? Metrics.headerHeight : Metrics.rowHeight
            let maxY = origin + height
            if clamped < maxY {
                return index
            }
        }
        return max(0, rowOffsets.count - 1)
    }

    private func columnIndex(for position: CGFloat) -> Int {
        guard !columnOffsets.isEmpty else { return 0 }
        let clamped = max(0, min(position, contentSize.width))
        for index in 0..<columnOffsets.count {
            let origin = columnOffsets[index]
            let width = columnWidths[index]
            let maxX = origin + width
            if clamped < maxX {
                return index
            }
        }
        return max(0, columnOffsets.count - 1)
    }
}

private final class ResultGridCell: UICollectionViewCell {
    enum Kind {
        case headerIndex
        case header
        case rowIndex
        case data
    }

    static let reuseIdentifier = "ResultGridCell"

    private let titleLabel = UILabel()
    private let indicatorView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        indicatorView.isHidden = true
        indicatorView.image = nil
    }

    private func configureView() {
        contentView.layer.cornerRadius = 6
        contentView.layer.masksToBounds = false
        contentView.backgroundColor = .clear

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.contentMode = .scaleAspectFit
        indicatorView.isHidden = true

        contentView.addSubview(titleLabel)
        contentView.addSubview(indicatorView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metrics.cellHorizontalPadding),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            indicatorView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            indicatorView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Metrics.cellHorizontalPadding),
            indicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indicatorView.widthAnchor.constraint(equalToConstant: 12),
            indicatorView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    func configure(
        text: String,
        kind: Kind,
        palette: ResultGridPalette,
        isHighlightedColumn: Bool,
        isRowSelected: Bool,
        isCellSelected: Bool,
        sortIndicator: SortIndicator?,
        isNullValue: Bool,
        isAlternateRow: Bool,
        valueKind: ResultGridValueKind = .text
    ) {
        titleLabel.text = text
        titleLabel.textColor = palette.primaryText
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textAlignment = .left
        indicatorView.isHidden = true

        var background = palette.background

        switch kind {
        case .headerIndex:
            titleLabel.textAlignment = .center
            titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            titleLabel.textColor = palette.headerText.withAlphaComponent(0.9)
            background = palette.headerBackground
        case .header:
            titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = palette.headerText
            background = isHighlightedColumn ? palette.columnHighlight : palette.headerBackground
            if let sortIndicator {
                indicatorView.isHidden = false
                let symbolName = sortIndicator == .ascending ? "arrow.up" : "arrow.down"
                indicatorView.image = UIImage(systemName: symbolName)
                indicatorView.tintColor = palette.headerText.withAlphaComponent(0.8)
            }
        case .rowIndex:
            titleLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            titleLabel.textAlignment = .right
            titleLabel.textColor = palette.secondaryText
            background = isRowSelected ? palette.rowHighlight : palette.headerBackground
        case .data:
            titleLabel.textAlignment = .left
            let textStyle = palette.style(for: valueKind)
            titleLabel.font = font(for: textStyle)
            titleLabel.textColor = textStyle.color
            if isCellSelected {
                background = palette.selectionFill
            } else if isHighlightedColumn {
                background = palette.columnHighlight
            } else if isRowSelected {
                background = palette.rowHighlight
            } else if isAlternateRow, let alternate = palette.alternateRow {
                background = alternate
            } else {
                background = palette.background
            }
        }

        contentView.backgroundColor = background
        contentView.layer.borderWidth = isCellSelected ? 1 : 0
        contentView.layer.borderColor = isCellSelected ? palette.accent.withAlphaComponent(0.6).cgColor : UIColor.clear.cgColor
        if isCellSelected {
            titleLabel.textColor = palette.primaryText
        }
    }

    private func font(for style: ResultGridPalette.ResultGridTextStyle) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: 13, weight: .regular).fontDescriptor
        var traits = descriptor.symbolicTraits
        if style.isBold {
            traits.insert(.traitBold)
        }
        if style.isItalic {
            traits.insert(.traitItalic)
        }
        if let resolved = descriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: resolved, size: 13)
        }
        if style.isBold {
            return UIFont.boldSystemFont(ofSize: 13)
        }
        return UIFont.systemFont(ofSize: 13)
    }
}

private final class ResultGridValuePreviewController: UIViewController {
    private let value: String
    private let titleText: String?

    init(value: String, title: String?) {
        self.value = value
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
        preferredContentSize = CGSize(width: 420, height: 320)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = value
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        if let titleText, !titleText.isEmpty {
            let titleLabel = UILabel()
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            titleLabel.text = titleText
            container.addArrangedSubview(titleLabel)
        }

        container.addArrangedSubview(textView)

        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}

// MARK: - UICollectionViewDataSource

extension ResultGridViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        guard !columns.isEmpty else { return 0 }
        return displayedRowCount + 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard !columns.isEmpty else { return 0 }
        return columns.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ResultGridCell.reuseIdentifier, for: indexPath) as? ResultGridCell else {
            return UICollectionViewCell()
        }
        configure(cell: cell, at: indexPath)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension ResultGridViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.section > 0, indexPath.item == 1, let query else { return }
        let displayedRow = indexPath.section - 1
        query.revealMoreRowsIfNeeded(forDisplayedRow: displayedRow)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == 0, indexPath.item > 0 else { return nil }
        let columnIndex = indexPath.item - 1
        guard columnIndex < columns.count else { return nil }
        let column = columns[columnIndex]
        let sortState = activeSort
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            let ascending = UIAction(title: "Sort Ascending", image: UIImage(systemName: "arrow.up")) { [weak self] _ in
                self?.onSort?(columnIndex, .ascending(columnIndex: columnIndex))
            }
            let descending = UIAction(title: "Sort Descending", image: UIImage(systemName: "arrow.down")) { [weak self] _ in
                self?.onSort?(columnIndex, .descending(columnIndex: columnIndex))
            }
            if let sortState, sortState.column == column.name {
                if sortState.ascending {
                    ascending.state = .on
                } else {
                    descending.state = .on
                }
            }
            var children: [UIMenuElement] = [ascending, descending]
            if let sortState, sortState.column == column.name {
                let clear = UIAction(title: "Clear Sort", image: UIImage(systemName: "line.3.horizontal.decrease.circle")) { [weak self] _ in
                    self?.onSort?(columnIndex, .clear)
                }
                children.append(clear)
            }
            return UIMenu(title: "", children: children)
        }
    }
}

// MARK: - Gesture Handling

extension ResultGridViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === longPressGesture && otherGestureRecognizer === collectionView.panGestureRecognizer
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        if indexPath.section == 0 {
            if indexPath.item > 0 {
                let columnIndex = indexPath.item - 1
                onColumnTap?(columnIndex)
                beginColumnSelection(at: columnIndex)
            }
        } else if indexPath.item == 0 {
            let rowIndex = indexPath.section - 1
            beginRowSelection(at: rowIndex)
        } else {
            let cell = SelectedCell(row: indexPath.section - 1, column: indexPath.item - 1)
            beginCellSelection(at: cell)
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
        guard indexPath.section > 0, indexPath.item > 0 else { return }
        let rowIndex = indexPath.section - 1
        let columnIndex = indexPath.item - 1
        guard columnIndex < columns.count else { return }
        let value = valueForDisplay(row: rowIndex, column: columnIndex) ?? "NULL"
        let header = columns[columnIndex].name
        let controller = ResultGridValuePreviewController(value: value, title: header)
        if let cell = collectionView.cellForItem(at: indexPath) {
            controller.modalPresentationStyle = .popover
            if let popover = controller.popoverPresentationController {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        present(controller, animated: true)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: location)

        switch gesture.state {
        case .began:
            guard let indexPath else { return }
            if indexPath.section == 0, indexPath.item > 0 {
                let columnIndex = indexPath.item - 1
                dragContext = .column(anchor: columnIndex)
                beginColumnSelection(at: columnIndex)
            } else if indexPath.item == 0, indexPath.section > 0 {
                let rowIndex = indexPath.section - 1
                dragContext = .row(anchor: rowIndex)
                beginRowSelection(at: rowIndex)
            } else if indexPath.section > 0, indexPath.item > 0 {
                let cell = SelectedCell(row: indexPath.section - 1, column: indexPath.item - 1)
                dragContext = .cells(anchor: cell)
                beginCellSelection(at: cell)
            }
        case .changed:
            guard let indexPath else { return }
            switch dragContext {
            case .column(let anchor):
                let current = max(0, min(columns.count - 1, indexPath.item - 1))
                continueColumnSelection(to: current)
                columnSelectionAnchor = anchor
            case .row(let anchor):
                let current = max(0, min(displayedRowCount - 1, indexPath.section - 1))
                continueRowSelection(to: current)
                rowSelectionAnchor = anchor
            case .cells(let anchor):
                let current = SelectedCell(row: max(0, indexPath.section - 1), column: max(0, indexPath.item - 1))
                selectionAnchor = anchor
                continueCellSelection(to: current, extend: true)
            case .none:
                break
            }
        case .ended, .cancelled, .failed:
            finalizeDragSelection()
        default:
            break
        }
    }
}
#endif
