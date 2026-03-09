import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TabGroupWidthPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct QueryTabStrip: View {
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat

    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(TabStore.self) var tabStore

    @EnvironmentObject var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var appearanceStore: AppearanceStore

    @State var hoveredTabID: UUID?
    @State var dragState = TabDragState()
    @State private var measuredTabGroupWidth: CGFloat = 0

    private var tabStripStyle: TabStripBackground.Style {
        .standard(colorScheme)
    }

    struct TabDragState: Equatable {
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

    let tabReorderAnimation = Animation.interactiveSpring(response: 0.72, dampingFraction: 0.86, blendDuration: 0.30)
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
            let tabs = tabStore.tabs
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
                .animation(tabReorderAnimation, value: tabStore.tabs.map(\.id))
            }
        }
        .frame(height: tabStripHeight)
        .clipped()
        .onPreferenceChange(TabGroupWidthPreferenceKey.self) { width in
            measuredTabGroupWidth = width
        }
        .onChange(of: tabStore.tabs.isEmpty) { _, isEmpty in
            if isEmpty {
                hoveredTabID = nil
            }
        }
        .onChange(of: tabStore.tabs.map(\.id)) { _, ids in
            if let hovered = hoveredTabID, !ids.contains(hovered) {
                hoveredTabID = nil
            }
        }
    }

    func combinedTabs(from tabs: [WorkspaceTab]) -> [(WorkspaceTab, Bool)] {
        let pinned = tabs.filter { $0.isPinned }.map { ($0, true) }
        let regular = tabs.filter { !$0.isPinned }.map { ($0, false) }
        return pinned + regular
    }

    private func tabGroup(orderedTabs: [(WorkspaceTab, Bool)], tabWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(orderedTabs.enumerated()), id: \.element.0.id) { index, element in
                let tab = element.0

                tabButtonView(tab: tab, targetWidth: tabWidth, index: index, totalCount: orderedTabs.count, appearance: nil)
                    .offset(x: tabOffset(for: tab, index: index, tabWidth: tabWidth))
                    .zIndex(tabZIndex(for: tab))
                    .overlay(alignment: .trailing) {
                        if index < orderedTabs.count - 1 {
                            let nextTab = orderedTabs[index + 1].0
                            tabSeparator()
                                .padding(.vertical, SpacingTokens.xs)
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
}
