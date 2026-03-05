#if os(iOS)
import UIKit

extension ResultGridCoordinator: UICollectionViewDataSource {
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
#endif
