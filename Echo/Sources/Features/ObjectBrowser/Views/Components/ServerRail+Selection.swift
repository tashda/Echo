import SwiftUI

extension ServerRail {
    // MARK: - Selection motion

    func offset(of id: UUID?, in ids: [UUID]) -> CGFloat? {
        guard let id, let index = ids.firstIndex(of: id) else { return nil }
        return CGFloat(index) * (itemSize + LayoutTokens.Rail.itemSpacing)
    }

    func placeSelection(on id: UUID?, in ids: [UUID], animated: Bool) {
        guard let top = offset(of: id, in: ids) else { return }
        let place = {
            selectionTop = top
            selectionBottom = top + itemSize
        }
        if animated {
            withAnimation(motion.standard, place)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, place)
        }
    }

    /// The leading edge races to the target and the trailing edge follows, so the disc stretches
    /// toward it like a drop of liquid and settles back (Design/04-motion.md).
    func moveSelection(from oldID: UUID?, to newID: UUID?, in ids: [UUID]) {
        guard let target = offset(of: newID, in: ids) else { return }
        guard !motion.reduceMotion, let origin = offset(of: oldID, in: ids), origin != target else {
            placeSelection(on: newID, in: ids, animated: true)
            return
        }
        if target > origin {
            withAnimation(motion.liquidLead) { selectionBottom = target + itemSize }
            withAnimation(motion.liquidTrail) { selectionTop = target }
        } else {
            withAnimation(motion.liquidLead) { selectionTop = target }
            withAnimation(motion.liquidTrail) { selectionBottom = target + itemSize }
        }
    }

}
