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
    var appearanceStore: AppearanceStore
    var clipboardHistory: ClipboardHistoryStore

    func makeUIViewController(context: Context) -> ResultGridCoordinator {
        ResultGridCoordinator()
    }

    func updateUIViewController(_ controller: ResultGridCoordinator, context: Context) {
        controller.update(
            with: .init(
                query: query,
                highlightedColumnIndex: highlightedColumnIndex,
                activeSort: activeSort,
                rowOrder: rowOrder,
                onColumnTap: onColumnTap,
                onSort: onSort,
                onClearColumnHighlight: onClearColumnHighlight,
                appearanceStore: appearanceStore,
                clipboardHistory: clipboardHistory
            )
        )
    }
}

final class ResultGridCoordinator: UIViewController {
    struct Configuration {
        let query: QueryEditorState
        let highlightedColumnIndex: Int?
        let activeSort: SortCriteria?
        let rowOrder: [Int]
        let onColumnTap: (Int) -> Void
        let onSort: (Int, ResultGridSortAction) -> Void
        let onClearColumnHighlight: () -> Void
        let appearanceStore: AppearanceStore
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
    internal var appearanceStore: AppearanceStore?
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
        guard let appearanceStore else { return }
        palette = ResultGridPalette(appearanceStore: appearanceStore, traitCollection: traitCollection)
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
        appearanceStore = configuration.appearanceStore
        rowOrder = configuration.rowOrder
        palette = ResultGridPalette(appearanceStore: configuration.appearanceStore, traitCollection: traitCollection)

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
}
#endif
