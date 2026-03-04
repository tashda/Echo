#if os(iOS)
import UIKit

final class ResultGridLayout: UICollectionViewLayout {
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
        let height = indexPath.section == 0 ? ResultGridMetrics.headerHeight : ResultGridMetrics.rowHeight
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
            runningY += section == 0 ? ResultGridMetrics.headerHeight : ResultGridMetrics.rowHeight
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
            let height = index == 0 ? ResultGridMetrics.headerHeight : ResultGridMetrics.rowHeight
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
#endif
