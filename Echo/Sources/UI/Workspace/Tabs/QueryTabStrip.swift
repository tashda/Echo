import SwiftUI
#if os(macOS)
import AppKit
#endif

struct QueryTabStrip: View {
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var hoveredTabID: UUID?
    @State private var dragState = TabDragState()
    @State private var measuredTabGroupWidth: CGFloat = 0

    private var themedAppearance: TabChromePalette? {
#if os(macOS)
        guard appState.themeTabs else { return nil }
        return TabChromePalette(
            theme: themeManager.activeTheme,
            accent: themeManager.accentNSColor,
            fallbackScheme: colorScheme
        )
#else
        return nil
#endif
    }

    private var tabStripStyle: TabStripBackground.Style {
        if let appearance = themedAppearance {
            return .themed(appearance)
        }
        return .standard(colorScheme)
    }

    private struct TabDragState: Equatable {
        var id: UUID?
        var originalIndex: Int = 0
        var currentIndex: Int = 0
        var translation: CGFloat = 0
        var minIndex: Int = 0
        var maxIndex: Int = 0

        var isActive: Bool { id != nil }

        mutating func begin(id: UUID, originalIndex: Int, minIndex: Int, maxIndex: Int) {
            self.id = id
            self.originalIndex = originalIndex
            self.currentIndex = originalIndex
            self.translation = 0
            self.minIndex = minIndex
            self.maxIndex = maxIndex
        }

        mutating func reset() {
            self = TabDragState()
        }
    }

    private let tabReorderAnimation = Animation.interactiveSpring(response: 0.72, dampingFraction: 0.86, blendDuration: 0.30)
    private let tabStripHeight: CGFloat = WorkspaceChromeMetrics.tabStripTotalHeight
    private let baseHorizontalInset: CGFloat = 4
    private let basePlateExtension: CGFloat = 0
    private let basePlateEdgeInset: CGFloat = 2
    private let basePlateCornerRadius: CGFloat = 14
    private var basePlateHeight: CGFloat { WorkspaceChromeMetrics.chromeBackgroundHeight }
    private var tabContentVerticalPadding: CGFloat {
        max((tabStripHeight - basePlateHeight) / 2, 0)
    }

    var body: some View {
        GeometryReader { geo in
            let tabs = appModel.tabManager.tabs
            let hasTabs = !tabs.isEmpty
            let orderedTabs = combinedTabs(from: tabs)

            let effectiveLeadingPadding = leadingPadding + baseHorizontalInset
            let effectiveTrailingPadding = trailingPadding + baseHorizontalInset
            let availableWidth = max(geo.size.width - effectiveLeadingPadding - effectiveTrailingPadding, 0)
            let separatorWidth = CGFloat(max(orderedTabs.count - 1, 0)) * tabHairlineWidth()
            let effectiveWidth = max(availableWidth - separatorWidth, 0)
            let tabWidth = orderedTabs.isEmpty ? 0 : effectiveWidth / CGFloat(orderedTabs.count)
            let tabContentWidth = max(tabWidth * CGFloat(orderedTabs.count), 0)
            let widthSource = measuredTabGroupWidth > 0 ? measuredTabGroupWidth : tabContentWidth
            let basePlateLeading = max(effectiveLeadingPadding - basePlateExtension - basePlateEdgeInset, 0)
            let basePlateTrailing = max(effectiveTrailingPadding - basePlateExtension - basePlateEdgeInset, 0)
            let plateAvailableWidth = max(geo.size.width - basePlateLeading - basePlateTrailing, 0)
            let desiredPlateWidth = min(max(widthSource + basePlateEdgeInset * 2, widthSource), plateAvailableWidth)
            let basePlateWidth = hasTabs ? desiredPlateWidth : 0
            let basePlateOffset = basePlateLeading

            ZStack(alignment: .leading) {
#if os(macOS)
                if hasTabs {
                    TabStripBackground(style: tabStripStyle, height: basePlateHeight, cornerRadius: basePlateCornerRadius)
                        .frame(width: basePlateWidth, height: basePlateHeight)
                        .offset(x: basePlateOffset)
                }
#endif

                HStack(spacing: 0) {
                    tabGroup(orderedTabs: orderedTabs, tabWidth: tabWidth)
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .preference(key: TabGroupWidthPreferenceKey.self, value: contentGeo.size.width)
                            }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, effectiveLeadingPadding)
                .padding(.trailing, effectiveTrailingPadding)
                .padding(.vertical, tabContentVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(tabReorderAnimation, value: appModel.tabManager.tabs.map(\.id))
            }
        }
        .frame(height: tabStripHeight)
        .clipped()
        .onPreferenceChange(TabGroupWidthPreferenceKey.self) { width in
            measuredTabGroupWidth = width
        }
        .onChange(of: appModel.tabManager.tabs.isEmpty) { _, isEmpty in
            if isEmpty {
                hoveredTabID = nil
            }
        }
        .onChange(of: appModel.tabManager.tabs.map(\.id)) { _, ids in
            if let hovered = hoveredTabID, !ids.contains(hovered) {
                hoveredTabID = nil
            }
        }
    }

    private func combinedTabs(from tabs: [WorkspaceTab]) -> [(WorkspaceTab, Bool)] {
        let pinned = tabs.filter { $0.isPinned }.map { ($0, true) }
        let regular = tabs.filter { !$0.isPinned }.map { ($0, false) }
        return pinned + regular
    }

    private func tabGroup(orderedTabs: [(WorkspaceTab, Bool)], tabWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(orderedTabs.enumerated()), id: \.element.0.id) { index, element in
                let tab = element.0

                tabButtonView(tab: tab, targetWidth: tabWidth, index: index, totalCount: orderedTabs.count, appearance: themedAppearance)
                    .offset(x: tabOffset(for: tab, index: index, tabWidth: tabWidth))
                    .zIndex(tabZIndex(for: tab))
                    .overlay(alignment: .trailing) {
                        if index < orderedTabs.count - 1 {
                            let nextTab = orderedTabs[index + 1].0
                            tabSeparator()
                                .padding(.vertical, 8)
                                .opacity(separatorOpacity(between: tab, and: nextTab, separatorIndex: index))
                        }
                    }
                    .highPriorityGesture(
                        dragGesture(
                            for: tab,
                            tabWidth: tabWidth,
                            index: index,
                            totalCount: orderedTabs.count
                        )
                    )
            }
        }
        .fixedSize()
    }

    private func tabOffset(for tab: WorkspaceTab, index: Int, tabWidth: CGFloat) -> CGFloat {
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

    private func tabZIndex(for tab: WorkspaceTab) -> Double {
        dragState.id == tab.id ? 1 : 0
    }

    private func tabSeparator() -> some View {
        Capsule(style: .continuous)
            .fill(separatorFill)
            .frame(width: tabHairlineWidth(), height: 18)
            .animation(nil, value: dragState)
    }

    private var separatorFill: LinearGradient {
#if os(macOS)
        if let palette = themedAppearance {
            return palette.separatorGradient
        }
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

    private func separatorOpacity(between current: WorkspaceTab, and next: WorkspaceTab, separatorIndex: Int) -> Double {
        if dragState.isActive,
           let draggingId = dragState.id {
            let orderedTabs = combinedTabs(from: appModel.tabManager.tabs).map { $0.0 }
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

        if current.id == appModel.tabManager.activeTabId || next.id == appModel.tabManager.activeTabId {
            return 0
        }
        if current.id == hoveredTabID || next.id == hoveredTabID {
            return 0
        }

        return 1
    }

    private func liveGapIndex(originalIndex: Int, destinationIndex: Int, totalTabs: Int) -> Int? {
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

    private func currentTabOrderApplyingDrag(to tabs: [WorkspaceTab], draggingIndex: Int) -> ([WorkspaceTab], Int) {
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

    private func boundsForDraggingTab(_ tab: WorkspaceTab) -> (min: Int, max: Int)? {
        let total = combinedTabs(from: appModel.tabManager.tabs).count
        guard total > 0 else { return nil }
        return tabBounds(for: tab, totalCount: total)
    }

    private func dragGesture(for tab: WorkspaceTab, tabWidth: CGFloat, index: Int, totalCount: Int) -> some Gesture {
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
                        appModel.tabManager.moveTab(id: tab.id, to: finalIndex)
                    }
                }

                withAnimation(tabReorderAnimation) {
                    dragState.reset()
                }
                hoveredTabID = nil
            }
    }

    private func clampTranslation(_ translation: CGFloat, for state: TabDragState, tabWidth: CGFloat) -> CGFloat {
        let maxRight = CGFloat(state.maxIndex - state.originalIndex) * tabWidth
        let maxLeft = CGFloat(state.originalIndex - state.minIndex) * tabWidth
        return min(max(translation, -maxLeft), maxRight)
    }

    private func tabBounds(for tab: WorkspaceTab, totalCount: Int) -> (min: Int, max: Int) {
        let pinnedCount = appModel.tabManager.tabs.filter { $0.isPinned }.count
        if tab.isPinned {
            return (0, max(pinnedCount - 1, 0))
        } else {
            return (pinnedCount, max(totalCount - 1, pinnedCount))
        }
    }

    @ViewBuilder
    private func tabButtonView(tab: WorkspaceTab, targetWidth: CGFloat, index: Int, totalCount: Int, appearance: TabChromePalette?) -> some View {
        let isActive = appModel.tabManager.activeTabId == tab.id
        let tabIndex = appModel.tabManager.index(of: tab.id) ?? 0
        let hasLeft = tabIndex > 0
        let hasRight = tabIndex < totalCount - 1
        let canDuplicate = tab.kind == .query
        let closeOthersDisabled = totalCount <= 1
        let isBeingDragged = dragState.isActive && dragState.id == tab.id

        QueryTabButton(
            tab: tab,
            isActive: isActive,
            onSelect: { appModel.tabManager.activeTabId = tab.id },
            onClose: { appModel.tabManager.closeTab(id: tab.id) },
            onAddBookmark: tab.query == nil ? nil : { bookmark(tab: tab) },
            onPinToggle: { appModel.tabManager.togglePin(for: tab.id) },
            onDuplicate: { appModel.duplicateTab(tab) },
            onCloseOthers: { appModel.tabManager.closeOtherTabs(keeping: tab.id) },
            onCloseLeft: { appModel.tabManager.closeTabsLeft(of: tab.id) },
            onCloseRight: { appModel.tabManager.closeTabsRight(of: tab.id) },
            canDuplicate: canDuplicate,
            closeOthersDisabled: closeOthersDisabled,
            closeTabsLeftDisabled: !hasLeft,
            closeTabsRightDisabled: !hasRight,
            isDropTarget: false,
            isBeingDragged: isBeingDragged,
            appearance: appearance,
            onHoverChanged: { hovering in
                if hovering {
                    hoveredTabID = tab.id
                } else if hoveredTabID == tab.id {
                    hoveredTabID = nil
                }
            }
        )
        .frame(width: targetWidth > 0 ? targetWidth : nil)
        .id(tab.id)
        .transaction { transaction in
            if isBeingDragged {
                transaction.animation = nil
            }
        }
    }

    private func bookmark(tab: WorkspaceTab) {
        guard let queryState = tab.query else { return }
        let trimmed = queryState.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let database = queryState.clipboardMetadata.databaseName ?? tab.connection.database
        Task {
            await appModel.addBookmark(
                for: tab.connection,
                databaseName: database,
                title: tab.title,
                query: trimmed,
                source: .tab
            )
        }
    }
}

struct TabGroupWidthPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
