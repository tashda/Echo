import SwiftUI

extension QueryTabStrip {
    func tabOffset(for tab: WorkspaceTab, index: Int) -> CGFloat {
        guard dragState.isActive else { return 0 }
        return dragState.id == tab.id ? dragState.translation : dragState.offset(forTabAt: index)
    }

    func tabZIndex(for tab: WorkspaceTab) -> Double {
        liftedTabID == tab.id ? 1 : 0
    }

    /// `widths` are every tab's width in strip order: a tool tab showing its pages is wider than
    /// the rest, so the tabs make room by the dragged tab's own width (round 49).
    func dragGesture(for tab: WorkspaceTab, index: Int, widths: [CGFloat]) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if !dragState.isActive {
                    guard let bounds = boundsForDraggingTab(tab) else { return }
                    dragState.begin(id: tab.id, originalIndex: index, minIndex: bounds.min, maxIndex: bounds.max, widths: widths)
                    liftedTabID = tab.id
                }
                guard dragState.id == tab.id else { return }

                let translation = dragState.clamped(value.translation.width)
                let proposedIndex = dragState.proposedIndex(for: translation)
                if proposedIndex != dragState.currentIndex {
                    withAnimation(tabReorderAnimation) {
                        dragState.currentIndex = proposedIndex
                    }
                }
                dragState.translation = translation
            }
            .onEnded { _ in
                guard dragState.isActive, dragState.id == tab.id else { return }
                let finalIndex = dragState.currentIndex
                let shouldMove = finalIndex != dragState.originalIndex

                // The tab stays raised until it has settled, so it never slides under a neighbour.
                withAnimation(tabReorderAnimation) {
                    if shouldMove {
                        tabStore.moveTab(id: tab.id, to: finalIndex)
                    }
                    dragState.reset()
                } completion: {
                    if liftedTabID == tab.id { liftedTabID = nil }
                }
                hoveredTabID = nil
            }
    }

    func tabBounds(for tab: WorkspaceTab, totalCount: Int) -> (min: Int, max: Int) {
        let pinnedCount = tabStore.tabs.filter { $0.isPinned }.count
        if tab.isPinned {
            return (0, max(pinnedCount - 1, 0))
        } else {
            return (pinnedCount, max(totalCount - 1, pinnedCount))
        }
    }

    func boundsForDraggingTab(_ tab: WorkspaceTab) -> (min: Int, max: Int)? {
        let total = combinedTabs(from: tabStore.tabs).count
        guard total > 0 else { return nil }
        return tabBounds(for: tab, totalCount: total)
    }

    func currentTabOrderApplyingDrag(to tabs: [WorkspaceTab], draggingIndex: Int) -> ([WorkspaceTab], Int) {
        var result = tabs
        guard dragState.isActive,
              let bounds = boundsForDraggingTab(tabs[draggingIndex]) else {
            return (result, draggingIndex)
        }
        let dragged = result.remove(at: draggingIndex)
        let clamped = min(max(dragState.currentIndex, bounds.min), bounds.max)
        result.insert(dragged, at: clamped)
        return (result, clamped)
    }
}
