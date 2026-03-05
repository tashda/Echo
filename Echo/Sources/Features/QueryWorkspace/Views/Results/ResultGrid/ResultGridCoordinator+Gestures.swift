#if os(iOS)
import UIKit

extension ResultGridCoordinator {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === longPressGesture && otherGestureRecognizer === collectionView.panGestureRecognizer
    }

    @objc internal func handleTap(_ gesture: UITapGestureRecognizer) {
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

    @objc internal func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
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

    @objc internal func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
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
