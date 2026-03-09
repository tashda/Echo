#if os(iOS)
import UIKit

extension ResultGridCoordinator: UICollectionViewDelegate {
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
#endif
