import SwiftUI

extension QueryTabStrip {
    func tabOffset(for tab: WorkspaceTab, index: Int, tabWidth: CGFloat) -> CGFloat {
        guard dragState.isActive, let draggingId = dragState.id else { return 0 }
        if draggingId == tab.id {
            return dragState.translation
        }
        guard tabWidth > 0 else { return 0 }

        if dragState.currentIndex > dragState.originalIndex {
            if index > dragState.originalIndex && index <= dragState.currentIndex {
                return -tabWidth
            }
        } else if dragState.currentIndex < dragState.originalIndex {
            if index >= dragState.currentIndex && index < dragState.originalIndex {
                return tabWidth
            }
        }

        return 0
    }

    func tabZIndex(for tab: WorkspaceTab) -> Double {
        dragState.id == tab.id ? 1 : 0
    }

    func dragGesture(for tab: WorkspaceTab, tabWidth: CGFloat, index: Int, totalCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if !dragState.isActive {
                    if let bounds = boundsForDraggingTab(tab) {
                        dragState.begin(
                            id: tab.id,
                            originalIndex: index,
                            minIndex: bounds.min,
                            maxIndex: bounds.max
                        )
                    } else {
                        return
                    }
                }

                let translation = value.translation.width
                let clampedTranslation = clampTranslation(translation, for: dragState, tabWidth: tabWidth)
                let moveThreshold = tabWidth * 0.4
                var remainder = clampedTranslation
                var proposedIndex = dragState.originalIndex

                while remainder > moveThreshold && proposedIndex < dragState.maxIndex {
                    remainder -= tabWidth
                    proposedIndex += 1
                }

                while remainder < -moveThreshold && proposedIndex > dragState.minIndex {
                    remainder += tabWidth
                    proposedIndex -= 1
                }

                if proposedIndex != dragState.currentIndex {
                    withAnimation(tabReorderAnimation) {
                        dragState.currentIndex = proposedIndex
                    }
                }

                dragState.translation = clampedTranslation
            }
            .onEnded { _ in
                guard dragState.isActive, dragState.id == tab.id else { return }
                let finalIndex = dragState.currentIndex
                let shouldMove = finalIndex != dragState.originalIndex

                if shouldMove {
                    withAnimation(tabReorderAnimation) {
                        tabStore.moveTab(id: tab.id, to: finalIndex)
                    }
                }

                withAnimation(tabReorderAnimation) {
                    dragState.reset()
                }
                hoveredTabID = nil
            }
    }

    func clampTranslation(_ translation: CGFloat, for state: TabDragState, tabWidth: CGFloat) -> CGFloat {
        let maxRight = CGFloat(state.maxIndex - state.originalIndex) * tabWidth
        let maxLeft = CGFloat(state.originalIndex - state.minIndex) * tabWidth
        return min(max(translation, -maxLeft), maxRight)
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
