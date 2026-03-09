import SwiftUI

extension QueryTabStrip {
    func tabSeparator() -> some View {
        Capsule(style: .continuous)
            .fill(separatorFill)
            .frame(width: tabHairlineWidth(), height: 18)
            .animation(nil, value: dragState)
    }

    var separatorFill: LinearGradient {
#if os(macOS)
        if colorScheme == .dark {
            return LinearGradient(colors: [
                Color.white.opacity(0.28),
                Color.white.opacity(0.16)
            ], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [
            Color(white: 0.88),
            Color(white: 0.75)
        ], startPoint: .top, endPoint: .bottom)
#else
        return LinearGradient(colors: [Color(white: 0.8), Color(white: 0.7)], startPoint: .top, endPoint: .bottom)
#endif
    }

    func separatorOpacity(between current: WorkspaceTab, and next: WorkspaceTab, separatorIndex: Int) -> Double {
        if dragState.isActive,
           let draggingId = dragState.id {
            let orderedTabs = combinedTabs(from: tabStore.tabs).map { $0.0 }
            guard let originalIndex = orderedTabs.firstIndex(where: { $0.id == draggingId }) else {
                return 1
            }

            let (preview, destination) = currentTabOrderApplyingDrag(to: orderedTabs, draggingIndex: originalIndex)

            if separatorIndex == originalIndex - 1 || separatorIndex == originalIndex {
                return 0
            }

            if let gap = liveGapIndex(originalIndex: originalIndex, destinationIndex: destination, totalTabs: preview.count),
               separatorIndex == gap {
                return 0
            }

            if destination != originalIndex,
               (separatorIndex == destination - 1 || separatorIndex == destination) {
                return 0
            }

            if current.id == draggingId || next.id == draggingId {
                return 0
            }
        }

        if current.id == tabStore.activeTabId || next.id == tabStore.activeTabId {
            return 0
        }
        if current.id == hoveredTabID || next.id == hoveredTabID {
            return 0
        }

        return 1
    }

    func liveGapIndex(originalIndex: Int, destinationIndex: Int, totalTabs: Int) -> Int? {
        guard dragState.isActive, totalTabs > 1 else { return nil }

        let lastSeparator = max(totalTabs - 2, 0)

        if destinationIndex == originalIndex {
            if dragState.translation > 0 {
                let candidate = min(originalIndex, lastSeparator)
                return candidate >= 0 ? candidate : nil
            } else if dragState.translation < 0 {
                let candidate = originalIndex - 1
                return candidate >= 0 ? candidate : nil
            } else {
                return nil
            }
        }

        if destinationIndex > originalIndex {
            let candidate = destinationIndex - 1
            return candidate >= 0 && candidate <= lastSeparator ? candidate : nil
        } else {
            let candidate = destinationIndex
            return candidate >= 0 && candidate <= lastSeparator ? candidate : nil
        }
    }
}
