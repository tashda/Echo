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

    internal let layout = ResultGridLayout()
    internal lazy var collectionView: UICollectionView = {
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

    internal var columns: [ColumnInfo] = []
    internal var rowOrder: [Int] = []
    internal var displayedRowCount: Int = 0
    internal weak var query: QueryEditorState?
    internal var highlightedColumnIndex: Int?
    internal var activeSort: SortCriteria?
    internal var onColumnTap: ((Int) -> Void)?
    internal var onSort: ((Int, ResultGridSortAction) -> Void)?
    internal var onClearColumnHighlight: (() -> Void)?
    internal var palette = ResultGridPalette.default
    internal var themeManager: ThemeManager?
    internal var cachedColumnIDs: [String] = []
    internal var cachedRowCount: Int = 0
    internal var cachedRowOrder: [Int] = []
    internal weak var clipboardHistory: ClipboardHistoryStore?
    internal var selectionRegion: SelectedRegion?
    internal var selectionAnchor: SelectedCell?
    internal var selectionFocus: SelectedCell?
    internal var rowSelectionAnchor: Int?
    internal var columnSelectionAnchor: Int?
    internal var dragContext: DragContext?

    internal lazy var tapGesture: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        recognizer.delegate = self
        return recognizer
    }()

    internal lazy var doubleTapGesture: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        recognizer.delegate = self
        return recognizer
    }()

    internal lazy var longPressGesture: UILongPressGestureRecognizer = {
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

    internal func updateLayoutIfNeeded() {
        guard !columns.isEmpty else {
            layout.configure(columnWidths: [], numberOfSections: 0)
            return
        }

        var widths: [CGFloat] = [ResultGridMetrics.indexColumnWidth]
        widths.append(contentsOf: columns.map(widthForColumn(_:)))
        layout.configure(columnWidths: widths, numberOfSections: displayedRowCount + 1)
        collectionView.backgroundColor = palette.background
    }

    internal func reloadIfNeeded() {
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

    internal func refreshVisibleCells() {
        guard !columns.isEmpty else { return }
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? ResultGridCell else { continue }
            configure(cell: cell, at: indexPath)
        }
    }

    internal func widthForColumn(_ column: ColumnInfo) -> CGFloat {
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

    internal func resolvedDataRowIndex(forDisplayed row: Int) -> Int {
        if !rowOrder.isEmpty, row >= 0, row < rowOrder.count {
            return rowOrder[row]
        }
        return row
    }

    internal func valueForDisplay(row: Int, column: Int) -> String? {
        guard let query = query else { return nil }
        let dataRow = resolvedDataRowIndex(forDisplayed: row)
        guard dataRow >= 0, dataRow < query.totalAvailableRowCount else { return nil }
        return query.valueForDisplay(row: dataRow, column: column)
    }

    internal func isRowInSelection(_ row: Int) -> Bool {
        selectionRegion?.containsRow(row) ?? false
    }

    internal func isColumnInSelection(_ column: Int) -> Bool {
        selectionRegion?.containsColumn(column) ?? false
    }

    internal func isColumnHighlighted(_ column: Int) -> Bool {
        if isColumnInSelection(column) { return true }
        if let highlightedColumnIndex, highlightedColumnIndex == column { return true }
        return false
    }

    internal func isCellSelected(row: Int, column: Int) -> Bool {
        guard let region = selectionRegion else { return false }
        return region.contains(SelectedCell(row: row, column: column))
    }

    internal func isAlternateRow(_ row: Int) -> Bool {
        palette.alternateRow != nil && row % 2 == 1
    }

    internal func sortIndicator(for columnIndex: Int) -> SortIndicator? {
        guard columnIndex >= 0, columnIndex < columns.count else { return nil }
        guard let activeSort else { return nil }
        return activeSort.column == columns[columnIndex].name
            ? (activeSort.ascending ? .ascending : .descending)
            : nil
    }

    internal func configure(cell: ResultGridCell, at indexPath: IndexPath) {
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
}

final class ResultGridValuePreviewController: UIViewController {
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
#endif
