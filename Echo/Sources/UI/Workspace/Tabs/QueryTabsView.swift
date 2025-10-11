import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
private func tabHairlineWidth() -> CGFloat {
    let scale = NSScreen.main?.backingScaleFactor ?? 2
    return max(1.0 / scale, 0.5)
}
#else
private func tabHairlineWidth() -> CGFloat { 1 }
#endif

private struct TabGroupWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct QueryTabsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.hostedWorkspaceTabID) private var hostedWorkspaceTabID

    var showsTabStrip: Bool = true
    var tabBarLeadingPadding: CGFloat = 12
    var tabBarTrailingPadding: CGFloat = 12
    private var recentConnectionItems: [RecentConnectionItem] {
        appModel.recentConnections.compactMap { record in
            guard let connection = appModel.connections.first(where: { $0.id == record.connectionID }) else {
                return nil
            }

            let trimmedName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = trimmedName.isEmpty ? connection.host : trimmedName
            let trimmedDatabase = record.databaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let database = (trimmedDatabase?.isEmpty == false) ? trimmedDatabase : nil

            return RecentConnectionItem(
                id: record.id,
                record: record,
                name: displayName,
                server: connection.host,
                database: database,
                lastConnectedAt: record.lastConnectedAt,
                databaseType: connection.databaseType
            )
        }
    }
    private var currentWorkspaceTab: WorkspaceTab? {
        if let hostedWorkspaceTabID,
           let hostedTab = appModel.tabManager.getTab(id: hostedWorkspaceTabID) {
            return hostedTab
        }

        return appModel.tabManager.activeTab
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabStrip {
                QueryTabStrip(
                    leadingPadding: tabBarLeadingPadding,
                    trailingPadding: tabBarTrailingPadding
                )
            }

            if appState.showTabOverview {
                TabOverviewView(
                    tabs: appModel.tabManager.tabs,
                    activeTabId: appModel.tabManager.activeTabId,
                    onSelectTab: { tabId in
                        appModel.tabManager.activeTabId = tabId
                        appState.showTabOverview = false
                    },
                    onCloseTab: { tabId in
                        appModel.tabManager.closeTab(id: tabId)
                    }
                )
            } else if let currentTab = currentWorkspaceTab {
                WorkspaceContentView(
                    tab: currentTab,
                    runQuery: { sql in await runQuery(tabId: currentTab.id, sql: sql) },
                    cancelQuery: { cancelQuery(tabId: currentTab.id) }
                )
            } else {
                RecentConnectionsPlaceholder(
                    connections: recentConnectionItems,
                    onSelectConnection: connectToRecentConnection
                )
            }
        }
        .onAppear(perform: createInitialTabIfNeeded)
        .onChange(of: appModel.selectedConnection) { _, _ in
            createInitialTabIfNeeded()
        }
    }

    private func createInitialTabIfNeeded() {
        guard appModel.tabManager.tabs.isEmpty,
              let activeSession = appModel.sessionManager.activeSession else { return }

        appModel.openQueryTab(for: activeSession)
    }

    private func runQuery(tabId: UUID, sql: String) async {
        guard let tab = appModel.tabManager.getTab(id: tabId),
              let queryState = tab.query else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL
        while effectiveSQL.last == ";" {
            effectiveSQL.removeLast()
        }
        effectiveSQL = effectiveSQL.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveSQL.isEmpty {
            effectiveSQL = trimmedSQL.isEmpty ? sql : trimmedSQL
        }
        let inferredObject = inferPrimaryObjectName(from: effectiveSQL)
        await MainActor.run {
            queryState.updateClipboardObjectName(inferredObject)
        }
        let task = Task { [weak queryState] in
            guard let state = await MainActor.run(body: { queryState }) else { return }

            do {
                let result = try await tab.session.simpleQuery(effectiveSQL) { [weak state] update in
                    guard let state else { return }
                    Task { @MainActor in
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            state.applyStreamUpdate(update)
                        }
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    state.consumeFinalResult(result)
                    state.finishExecution()

                    var metadata: [String: String] = [
                        "rows": "\(result.rows.count)"
                    ]
                    let columnNames = result.columns.map(\.name).joined(separator: ", ")
                    if !columnNames.isEmpty {
                        metadata["columns"] = columnNames
                    }
                    if let commandTag = result.commandTag, !commandTag.isEmpty {
                        metadata["commandTag"] = commandTag
                    }

                    state.appendMessage(
                        message: "Returned \(result.rows.count) row\(result.rows.count == 1 ? "" : "s")",
                        severity: .info,
                        metadata: metadata
                    )
                    appState.addToQueryHistory(effectiveSQL, resultCount: result.rows.count, duration: state.lastExecutionTime ?? 0)
                }
            } catch is CancellationError {
                await MainActor.run {
                    state.markCancellationCompleted()
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = error.localizedDescription
                    state.failExecution(with: "Query execution failed: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            queryState.errorMessage = nil
            queryState.startExecution()
            queryState.setExecutingTask(task)
        }
    }

    private func cancelQuery(tabId: UUID) {
        guard let tab = appModel.tabManager.getTab(id: tabId),
              let queryState = tab.query else { return }
        queryState.cancelExecution()
    }

    private func connectToRecentConnection(_ item: RecentConnectionItem) {
        Task {
            await appModel.connectToRecentConnection(item.record)
        }
    }

    private func inferPrimaryObjectName(from sql: String) -> String? {
        let cleanedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSQL.isEmpty else { return nil }

        let patterns = [
            #"(?i)\bfrom\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\binto\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bupdate\s+([A-Za-z0-9_\.\"`]+)"#,
            #"(?i)\bdelete\s+from\s+([A-Za-z0-9_\.\"`]+)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(in: cleanedSQL, pattern: pattern) {
                return normalizeIdentifier(match)
            }
        }

        return nil
    }

    private func firstMatch(in sql: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (sql as NSString).length)
        guard let match = regex.firstMatch(in: sql, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        let matchRange = match.range(at: 1)
        guard let rangeInString = Range(matchRange, in: sql) else { return nil }
        return String(sql[rangeInString])
    }

    private func normalizeIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'[]"))
        return trimmed
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "].[", with: ".")
    }

}

struct QueryTabStrip: View {
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var hoveredTabID: UUID?
    @State private var dragState = TabDragState()
    @State private var tabGroupWidth: CGFloat = 0

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
    private let baseHorizontalInset: CGFloat = 12
    private let basePlateExtension: CGFloat = 0

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
            let measuredWidth = tabGroupWidth > 0 ? (tabGroupWidth + separatorWidth) : max(tabWidth * CGFloat(orderedTabs.count) + separatorWidth, 0)
            let basePlateWidth = hasTabs ? min(measuredWidth + basePlateExtension * 2, availableWidth + basePlateExtension * 2) : 0

            ZStack(alignment: .leading) {
#if os(macOS)
                if hasTabs {
                    TabStripBackground(style: tabStripStyle)
                        .frame(width: basePlateWidth, height: 24)
                        .offset(x: effectiveLeadingPadding - basePlateExtension)
                }
#endif

                HStack(spacing: 0) {
                    tabGroup(orderedTabs: orderedTabs, tabWidth: tabWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, effectiveLeadingPadding)
                .padding(.trailing, effectiveTrailingPadding)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(tabReorderAnimation, value: appModel.tabManager.tabs.map(\.id))
            }
        }
        .frame(height: 34)
        .clipped()
        .onPreferenceChange(TabGroupWidthPreferenceKey.self) { width in
            tabGroupWidth = width
        }
        .onChange(of: appModel.tabManager.tabs.isEmpty) { isEmpty in
            if isEmpty {
                hoveredTabID = nil
                tabGroupWidth = 0
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
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: TabGroupWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
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

            // Hide separators adjacent to the original slot while the tab occupies it
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
        let bounds = tabBounds(for: tab, totalCount: total)
        return bounds
    }

    private func dragGesture(for tab: WorkspaceTab, tabWidth: CGFloat, index: Int, totalCount: Int) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard tabWidth > 0 else { return }

                if !dragState.isActive {
                    let bounds = tabBounds(for: tab, totalCount: totalCount)
                    dragState.begin(
                        id: tab.id,
                        originalIndex: index,
                        minIndex: bounds.min,
                        maxIndex: bounds.max
                    )
                    hoveredTabID = tab.id
                }

                guard dragState.id == tab.id else { return }

                let rawTranslation = value.translation.width
                let clampedTranslation = clampTranslation(rawTranslation, for: dragState, tabWidth: tabWidth)

                let moveThreshold = tabWidth * 0.5
                var proposedIndex = dragState.originalIndex
                var remainder = clampedTranslation

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

        return QueryTabButton(
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

private struct RecentConnectionItem: Identifiable {
    let id: String
    let record: RecentConnectionRecord
    let name: String
    let server: String
    let database: String?
    let lastConnectedAt: Date
    let databaseType: DatabaseType

    var subtitle: String {
        if let database, !database.isEmpty {
            return "\(database) @ \(server)"
        }
        return server
    }
}

private struct RecentConnectionsPlaceholder: View {
    let connections: [RecentConnectionItem]
    let onSelectConnection: (RecentConnectionItem) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(connections.isEmpty ? "No Recent Connections" : "Recent Connections")
                .font(.title3.weight(.semibold))

            if connections.isEmpty {
                EmptyRecentConnectionsView()
            } else {
                RecentConnectionsList(
                    connections: connections,
                    onSelectConnection: onSelectConnection
                )
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .padding(.vertical, 44)
    }
}

private struct RecentConnectionsList: View {
    let connections: [RecentConnectionItem]
    let onSelectConnection: (RecentConnectionItem) -> Void

    var body: some View {
        VStack(spacing: 8) {
            let lastID = connections.last?.id
            ForEach(connections) { connection in
                RecentConnectionRow(
                    item: connection,
                    onTap: { onSelectConnection(connection) }
                )
                .padding(.horizontal, 12)

                if connection.id != lastID {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }
}

private struct RecentConnectionRow: View {
    let item: RecentConnectionItem
    let onTap: () -> Void

    private var formattedTimestamp: String {
        item.lastConnectedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                ConnectionIconView(databaseType: item.databaseType)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formattedTimestamp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct ConnectionIconView: View {
    let databaseType: DatabaseType

    var body: some View {
#if os(macOS)
        if let nsImage = NSImage(named: databaseType.iconName) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            fallbackIcon
        }
#else
        if let uiImage = UIImage(named: databaseType.iconName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            fallbackIcon
        }
#endif
    }

    private var fallbackIcon: some View {
        Image(systemName: "server.rack")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
    }
}

private struct EmptyRecentConnectionsView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("You have not connected to any servers yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Use the sidebar to add a server and it will appear here next time.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workspace Content

private struct WorkspaceContentView: View {
    @ObservedObject var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.windowBackground
                .ignoresSafeArea()

            Group {
                if let structureEditor = tab.structureEditor {
                    TableStructureEditorView(tab: tab, viewModel: structureEditor)
                        .background(themeManager.windowBackground)
                } else if let query = tab.query {
                    QueryEditorContainer(
                        tab: tab,
                        query: query,
                        runQuery: runQuery,
                        cancelQuery: cancelQuery
                    )
                } else {
                    EmptyView()
                }
            }
        }
    }
}

private struct QueryEditorContainer: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var query: QueryEditorState
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appModel: AppModel

    private let minRatio: CGFloat = 0.25
    private let maxRatio: CGFloat = 0.8

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let backgroundColor = themeManager.windowBackground
            let ratioBinding = Binding<CGFloat>(
                get: { min(max(query.splitRatio, minRatio), maxRatio) },
                set: { newValue in
                    query.splitRatio = min(max(newValue, minRatio), maxRatio)
                }
            )

            VStack(spacing: 0) {
                QueryInputSection(
                    query: query,
                    onExecute: { sql in await runQuery(sql) },
                    onCancel: cancelQuery,
                    onAddBookmark: handleBookmarkRequest,
                    completionContext: editorCompletionContext
                )
                .frame(height: query.hasExecutedAtLeastOnce ? totalHeight * ratioBinding.wrappedValue : totalHeight)
                .background(backgroundColor)

                if query.hasExecutedAtLeastOnce {
                    ResizeHandle(
                        ratio: ratioBinding,
                        minRatio: minRatio,
                        maxRatio: maxRatio,
                        availableHeight: totalHeight
                    )

                    QueryResultsSection(
                        query: query,
                        connection: connectionForDisplay,
                        activeDatabaseName: connectionDatabaseName
                    )
                        .frame(height: totalHeight * (1 - ratioBinding.wrappedValue))
                        .background(backgroundColor)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(backgroundColor)
        }
        .background(themeManager.windowBackground)
        .onAppear(perform: updateClipboardContext)
        .onChange(of: tab.connection.connectionName) { _, _ in
            updateClipboardContext()
        }
        .onChange(of: tab.connection.database) { _, _ in
            updateClipboardContext()
        }
    }

    private var connectionSession: ConnectionSession? {
        appModel.sessionManager.activeSessions.first { $0.id == tab.connectionSessionID }
    }

    private var connectionServerName: String? {
        let name = (connectionSession?.connection.connectionName ?? tab.connection.connectionName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let host = (connectionSession?.connection.host ?? tab.connection.host)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? nil : host
    }

    private var connectionDatabaseName: String? {
        if let selected = connectionSession?.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty {
            return selected
        }
        let database = tab.connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return database.isEmpty ? nil : database
    }

    private func updateClipboardContext() {
        query.updateClipboardContext(
            serverName: connectionServerName,
            databaseName: connectionDatabaseName,
            connectionColorHex: connectionColorHex
        )
    }

    private var connectionServerVersion: String? {
        let candidates: [String?] = [
            connectionSession?.databaseStructure?.serverVersion,
            connectionSession?.connection.serverVersion,
            tab.connection.serverVersion
        ]
        for candidate in candidates {
            if let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private var connectionForDisplay: SavedConnection {
        var snapshot = connectionSession?.connection ?? tab.connection
        snapshot.serverVersion = connectionServerVersion
        return snapshot
    }

    private var connectionColorHex: String? {
        if let sessionHex = connectionSession?.connection.metadataColorHex {
            return sessionHex
        }
        return tab.connection.metadataColorHex
    }

    private var editorCompletionContext: SQLEditorCompletionContext? {
        let session = connectionSession
        let baseConnection = session?.connection ?? tab.connection
        let databaseType = baseConnection.databaseType
        let selectedDatabase = normalized(session?.selectedDatabaseName)
            ?? normalized(baseConnection.database)
        let structure = session?.databaseStructure
            ?? session?.connection.cachedStructure
            ?? tab.connection.cachedStructure
        let defaultSchema = defaultSchema(for: databaseType)

        return SQLEditorCompletionContext(
            databaseType: databaseType,
            selectedDatabase: selectedDatabase,
            defaultSchema: defaultSchema,
            structure: structure
        )
    }

    private func defaultSchema(for type: DatabaseType) -> String? {
        switch type {
        case .microsoftSQL:
            return "dbo"
        case .postgresql:
            return "public"
        case .mysql, .sqlite:
            return nil
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func handleBookmarkRequest(_ sql: String) {
        Task {
            await appModel.addBookmark(
                for: tab.connection,
                databaseName: connectionDatabaseName,
                title: tabTitleForBookmark,
                query: sql,
                source: .queryEditorSelection
            )
        }
    }

    private var tabTitleForBookmark: String? {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Tab Button

private struct QueryTabButton: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onAddBookmark: (() -> Void)?
    let onPinToggle: () -> Void
    let onDuplicate: () -> Void
    let onCloseOthers: () -> Void
    let onCloseLeft: () -> Void
    let onCloseRight: () -> Void
    let canDuplicate: Bool
    let closeOthersDisabled: Bool
    let closeTabsLeftDisabled: Bool
    let closeTabsRightDisabled: Bool
    let isDropTarget: Bool
    let isBeingDragged: Bool
    let appearance: TabChromePalette?
    let onHoverChanged: (Bool) -> Void

    @State private var isHovering = false
    @State private var isHoveringClose = false

    private var shouldShowClose: Bool {
        guard !tab.isPinned else { return false }
#if os(macOS)
        return isHovering
#else
        return true
#endif
    }

#if os(macOS)
    @Environment(\.colorScheme) private var colorScheme
#endif

    private var tabCornerRadius: CGFloat { 15 }

    private var tabShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
    }

    private var hairlineWidth: CGFloat { tabHairlineWidth() }

    var body: some View {
        HStack(spacing: 3) {
            leadingControl

            Text(displayedTitle)
                .font(tabTitleFont)
                .lineLimit(1)
                .foregroundStyle(tabTitleColor)
                .frame(maxWidth: .infinity, alignment: .center)

            closeButtonPlaceholder
        }
        .padding(.horizontal, tab.isPinned ? 13 : 18)
        .padding(.vertical, 3)
        .frame(minHeight: 24)
        .background(tabBackground)
        .overlay(tabStroke)
        .overlay(hoverOutline)
        .shadow(color: tabShadowColor, radius: tabShadowRadius, y: tabShadowYOffset)
        .contentShape(tabShape)
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
            if !hovering { isHoveringClose = false }
            onHoverChanged(hovering)
        }
        .onMiddleClick(perform: onClose)
#endif
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab", action: onPinToggle)

            Button("Duplicate Tab", action: onDuplicate)
                .disabled(!canDuplicate)

            Divider()

            Button("Close Tab", action: onClose)

            Button("Close Other Tabs", action: onCloseOthers)
                .disabled(closeOthersDisabled)

            Button("Close Tabs to the Left", action: onCloseLeft)
                .disabled(closeTabsLeftDisabled)

            Button("Close Tabs to the Right", action: onCloseRight)
                .disabled(closeTabsRightDisabled)

            if let onAddBookmark {
                Divider()
                Button("Add to Bookmarks", action: onAddBookmark)
            }
        }
        .onChange(of: shouldShowClose) { visible in
            if !visible {
                isHoveringClose = false
            }
        }
    }

    private var leadingControl: some View {
        Group {
            if tab.isPinned {
                closeButtonPlaceholder
            } else {
                closeButtonArea
            }
        }
    }

    private var displayedTitle: String {
        let trimmed = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if tab.isPinned {
            if let first = trimmed.first {
                return String(first).uppercased()
            }
            return "•"
        }
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var tabTitleFont: Font {
        if tab.isPinned {
            return .system(size: 11, weight: .semibold)
        }
        return .system(size: 11)
    }

    @ViewBuilder
    private var tabBackground: some View {
#if os(macOS)
        if let gradient = macTabFillGradient {
            tabShape.fill(gradient)
        } else {
            tabShape.fill(Color.clear)
        }
#else
        tabShape.fill(tabFillGradient)
#endif
    }

    @ViewBuilder
    private var tabStroke: some View {
#if os(macOS)
        if isDropTarget {
            tabShape.stroke(tabDropBorderColor, lineWidth: hairlineWidth)
        } else if let color = macTabBorderColor {
            tabShape.stroke(color, lineWidth: hairlineWidth)
        }
#else
        tabShape.stroke(isDropTarget ? tabDropBorderColor : tabBorderColor, lineWidth: hairlineWidth)
#endif
    }

    @ViewBuilder
    private var hoverOutline: some View {
#if os(macOS)
        if shouldShowHoverOutline {
            tabShape
                .stroke(hoverHighlightColor, lineWidth: 1.1)
        }
#else
        tabShape
            .stroke(hoverHighlightColor, lineWidth: 1.1)
            .opacity(shouldShowHoverOutline ? 1 : 0)
#endif
    }

#if os(macOS)
    private var macTabFillGradient: LinearGradient? {
        if let appearance {
            if isDropTarget {
                return appearance.dropTabFill
            }

            if isActive {
                return appearance.activeTabFill
            }

            if shouldTreatAsHover {
                return appearance.hoverTabFill
            }

            return appearance.inactiveTabFill
        }
        if isDropTarget {
            return tabDropHighlightGradient
        }

        if isActive {
            if effectiveHovering {
                if colorScheme == .dark {
                    return LinearGradient(colors: [Color.white.opacity(0.48), Color.white.opacity(0.32)], startPoint: .top, endPoint: .bottom)
                } else {
                    return LinearGradient(colors: [Color(white: 0.93), Color(white: 0.86)], startPoint: .top, endPoint: .bottom)
                }
            } else {
                if colorScheme == .dark {
                    return LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.26)], startPoint: .top, endPoint: .bottom)
                } else {
                    return LinearGradient(colors: [Color(white: 0.998), Color(white: 0.965)], startPoint: .top, endPoint: .bottom)
                }
            }
        }

        if shouldTreatAsHover {
            if colorScheme == .dark {
                return LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.17)], startPoint: .top, endPoint: .bottom)
            } else {
                return LinearGradient(colors: [Color(white: 0.92), Color(white: 0.88)], startPoint: .top, endPoint: .bottom)
            }
        }

        return nil
    }

    private var macTabBorderColor: Color? {
        if let appearance {
            if isDropTarget {
                return appearance.dropTabBorder
            }

            if isActive {
                return appearance.activeTabBorder
            }

            if shouldTreatAsHover {
                return appearance.hoverTabBorder
            }

            return appearance.inactiveTabBorder
        }
        if isDropTarget {
            return tabDropBorderColor
        }

        if isActive {
            return colorScheme == .dark ? Color.white.opacity(0.34) : Color(white: 0.82)
        }

        return nil
    }

    private var effectiveHovering: Bool {
        isHovering || isBeingDragged
    }

    private var shouldTreatAsHover: Bool {
        !isActive && effectiveHovering && !isDropTarget
    }
#else
    private var tabFillGradient: LinearGradient {
        LinearGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }
#endif

    private var tabDropHighlightGradient: LinearGradient {
#if os(macOS)
        if let appearance {
            return appearance.dropTabFill
        }
        if colorScheme == .dark {
            return LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.18)], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [Color(white: 0.90), Color(white: 0.86)], startPoint: .top, endPoint: .bottom)
        }
#else
        LinearGradient(colors: [Color.accentColor.opacity(0.4), Color.accentColor.opacity(0.28)], startPoint: .top, endPoint: .bottom)
#endif
    }

    private var tabBorderColor: Color {
#if os(macOS)
        Color.clear
#else
        return Color.black.opacity(0.1)
#endif
    }

    private var tabDropBorderColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.dropTabBorder
        }
        if colorScheme == .dark {
            return Color.white.opacity(0.15)
        } else {
            return Color.black.opacity(0.05)
        }
#else
        return Color.accentColor.opacity(0.6)
#endif
    }

    private var hoverHighlightColor: Color {
#if os(macOS)
        if let appearance {
            return appearance.hoverTabBorder
        }
        return colorScheme == .dark ? Color.white.opacity(0.38) : Color.white.opacity(0.55)
#else
        return Color.white.opacity(0.4)
#endif
    }

    private var shouldShowHoverOutline: Bool {
#if os(macOS)
        false
#else
        return false
#endif
    }

    private var tabShadowColor: Color {
#if os(macOS)
        if !isActive { return Color.clear }
        return colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.10)
#else
        return Color.black.opacity(isActive ? 0.2 : 0)
#endif
    }

    private var tabShadowRadius: CGFloat { isActive ? 2.5 : 0 }
    private var tabShadowYOffset: CGFloat { isActive ? 1.2 : 0 }

    private var tabTitleColor: Color {
#if os(macOS)
        if isDropTarget {
            return Color.white
        }
        if let appearance {
            return isActive ? appearance.activeTitle : appearance.inactiveTitle
        }
        if tab.isPinned {
            return Color(nsColor: isActive ? .labelColor : .secondaryLabelColor.withAlphaComponent(0.75))
        }
        return Color(nsColor: isActive ? .labelColor : .secondaryLabelColor)
#else
        if isDropTarget {
            return .white
        }
        return isActive ? .primary : .secondary
#endif
    }

    private var closeButtonForeground: Color {
#if os(macOS)
        if let appearance {
            if isDropTarget { return Color.white }
            if isHoveringClose { return appearance.closeHoverForeground }
            if isActive { return appearance.closeForeground }
            return appearance.closeForeground.opacity(0.85)
        }
        if isDropTarget { return Color.white }
        if isHoveringClose {
            return Color(nsColor: .labelColor)
        }
        if isActive {
            return Color(nsColor: .secondaryLabelColor)
        }
        return Color(nsColor: .tertiaryLabelColor)
#else
        return .secondary
#endif
    }

    private var closeButtonBackground: Color {
#if os(macOS)
        if let appearance, shouldShowClose, isHoveringClose {
            return appearance.closeHoverBackground
        }
        guard shouldShowClose, isHoveringClose else { return Color.clear }
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        } else {
            return Color.black.opacity(0.08)
        }
#else
        return Color.black.opacity(0.12)
#endif
    }

    private var closeButtonArea: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(closeButtonForeground)
                .frame(width: closeButtonSize, height: closeButtonSize)
                .background(
                    Circle()
                        .fill(closeButtonBackground)
                )
        }
        .buttonStyle(.plain)
        .opacity(shouldShowClose ? 1 : 0)
        .allowsHitTesting(shouldShowClose)
        .contentShape(Circle())
#if os(macOS)
        .help("Close tab")
        .onHover { hovering in
            isHoveringClose = hovering
        }
#endif
        .frame(width: closeButtonSize, height: closeButtonSize, alignment: .leading)
    }

    private var closeButtonPlaceholder: some View {
        let width: CGFloat
#if os(macOS)
        if tab.isPinned {
            width = 0
        } else {
            width = closeButtonSize
        }
#else
        width = closeButtonSize
#endif
        return Rectangle()
            .fill(Color.clear)
            .frame(width: width, height: closeButtonSize)
    }

    private var closeButtonSize: CGFloat { 16 }
}

private struct ResizeHandle: View {
    @Binding var ratio: CGFloat
    let minRatio: CGFloat
    let maxRatio: CGFloat
    let availableHeight: CGFloat

    @State private var dragStartRatio: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 2)
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 60, height: 3)
        }
        .frame(height: 8)
        .background(Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        dragStartRatio = ratio
                        isDragging = true
                    }

                    let delta = value.translation.height / max(availableHeight, 1)
                    let proposed = dragStartRatio + delta
                    self.ratio = min(max(proposed, minRatio), maxRatio)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
#if os(macOS)
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.set()
            } else {
                NSCursor.arrow.set()
            }
        }
#endif
    }
}

// MARK: - Tab Overview

private struct TabOverviewView: View {
    let tabs: [WorkspaceTab]
    let activeTabId: UUID?
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appModel: AppModel

    @State private var animateIn = false
    @State private var collapsedServers: Set<UUID> = []
    @State private var collapsedDatabases: Set<String> = []

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)
    ]

    private var orderedTabIDs: [UUID] { tabs.map(\.id) }
    private var animation: Animation { .spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2) }

    var body: some View {
        VStack(spacing: 16) {
            header

            ScrollView {
                if groupedTabs.isEmpty {
                    emptyState
                        .padding(.top, 80)
                        .padding(.horizontal, 24)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedTabs) { serverGroup in
                            serverGroupView(serverGroup)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(themeManager.windowBackground)
        .onAppear(perform: triggerAnimation)
        .onChange(of: tabs.map(\.id)) { _, _ in resetAnimation() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Tab Overview")
                .font(.system(size: 18, weight: .semibold))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No tabs open")
                .font(.title3.weight(.semibold))
            Text("Create a new tab to see it appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func serverGroupView(_ group: ServerGroup) -> some View {
        let serverID = group.connection.id
        let isExpanded = !collapsedServers.contains(serverID)
        let isActiveServer = group.connection.id == activeConnectionID

        return VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    toggleServerExpansion(serverID: serverID)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    serverHeader(for: group.connection)

                    Spacer(minLength: 0)

                    Text("\(group.totalTabCount) tab\(group.totalTabCount == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(group.databaseGroups) { databaseGroup in
                        databaseSectionView(databaseGroup, serverID: serverID)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isActiveServer ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08),
                    lineWidth: isActiveServer ? 1.5 : 1
                )
        )
    }

    private func serverHeader(for connection: SavedConnection) -> some View {
        let displayName = connection.connectionName.isEmpty ? connection.host : connection.connectionName
        let rawInitials = displayName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()
        let initials = String(rawInitials.prefix(2))

        return HStack(spacing: 12) {
            Circle()
                .fill(connection.color.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initials.isEmpty ? "DB" : initials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(connection.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(connection.host) • \(connection.databaseType.displayName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func databaseSectionView(_ databaseGroup: DatabaseGroup, serverID: UUID) -> some View {
        let identifier = databaseIdentifier(for: databaseGroup.key, serverID: serverID)
        let isExpanded = !collapsedDatabases.contains(identifier)
        let isActiveDatabase = activeDatabaseName(for: serverID) == databaseGroup.activeDatabaseComparisonKey

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    toggleDatabaseExpansion(identifier: identifier)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(databaseGroup.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActiveDatabase ? .primary : .secondary)

                    Spacer(minLength: 0)

                    Text("\(databaseGroup.totalTabCount) tab\(databaseGroup.totalTabCount == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(databaseGroup.sections) { section in
                    tabSectionView(section)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func tabSectionView(_ section: TabSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(section.tabs) { tab in
                    tabCard(for: tab)
                }
            }
        }
        .animation(animation, value: section.tabs.map(\.id))
    }

    private func tabCard(for tab: WorkspaceTab) -> some View {
        TabPreviewCard(
            tab: tab,
            isActive: tab.id == activeTabId,
            onSelect: { onSelectTab(tab.id) },
            onClose: { onCloseTab(tab.id) }
        )
        .environmentObject(themeManager)
        .scaleEffect(animateIn ? 1 : 0.92)
        .opacity(animateIn ? 1 : 0)
        .animation(animation.delay(0.03 * Double(appearIndex(for: tab))), value: animateIn)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func triggerAnimation() {
        guard !animateIn else { return }
        resetAnimation()
    }

    private func resetAnimation() {
        animateIn = false
        DispatchQueue.main.async {
            withAnimation(animation) {
                animateIn = true
            }
        }
    }

    private func appearIndex(for tab: WorkspaceTab) -> Int {
        orderedTabIDs.firstIndex(of: tab.id) ?? 0
    }

    private var groupedTabs: [ServerGroup] {
        var orderedServerIDs: [UUID] = []
        var seenServers = Set<UUID>()
        for tab in tabs {
            if seenServers.insert(tab.connection.id).inserted {
                orderedServerIDs.append(tab.connection.id)
            }
        }

        if let activeID = activeConnectionID,
           let activeIndex = orderedServerIDs.firstIndex(of: activeID) {
            orderedServerIDs.remove(at: activeIndex)
            orderedServerIDs.insert(activeID, at: 0)
        }

        return orderedServerIDs.compactMap { connectionID in
            let serverTabs = tabs.filter { $0.connection.id == connectionID }
            guard let connection = serverTabs.first?.connection else { return nil }
            let databaseGroups = databaseGroupsForTabs(serverTabs)
            return ServerGroup(connection: connection, databaseGroups: databaseGroups, totalTabCount: serverTabs.count)
        }
    }

    private func databaseGroupsForTabs(_ serverTabs: [WorkspaceTab]) -> [DatabaseGroup] {
        var orderedDatabaseKeys: [DatabaseKey] = []
        var seenDatabases = Set<String>()
        var includedNil = false

        for tab in serverTabs {
            let key = databaseKey(for: tab)
            switch key {
            case .named(let name):
                if seenDatabases.insert(name).inserted {
                    orderedDatabaseKeys.append(.named(name))
                }
            case .none:
                if !includedNil {
                    includedNil = true
                    orderedDatabaseKeys.append(.none)
                }
            }
        }

        if orderedDatabaseKeys.isEmpty {
            orderedDatabaseKeys.append(.none)
        }

        return orderedDatabaseKeys.map { key in
            let matchingTabs = serverTabs.filter { databaseKey(for: $0) == key }
            return DatabaseGroup(
                key: key,
                sections: sections(for: matchingTabs),
                totalTabCount: matchingTabs.count
            )
        }
    }

    private func sections(for tabs: [WorkspaceTab]) -> [TabSection] {
        guard !tabs.isEmpty else { return [] }

        return [TabSection(id: "all", title: nil, tabs: tabs)]
    }

    private enum DatabaseKey: Equatable {
        case named(String)
        case none
    }

    private func databaseKey(for tab: WorkspaceTab) -> DatabaseKey {
        guard let name = databaseName(for: tab) else { return .none }
        return .named(name)
    }

    private func databaseName(for tab: WorkspaceTab) -> String? {
        if let session = appModel.sessionManager.activeSessions.first(where: { $0.id == tab.connectionSessionID }),
           let selected = session.selectedDatabaseName, !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selected
        }

        let trimmed = tab.connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private struct ServerGroup: Identifiable {
        let connection: SavedConnection
        let databaseGroups: [DatabaseGroup]
        let totalTabCount: Int

        var id: UUID { connection.id }
    }

    private struct DatabaseGroup: Identifiable {
        let key: DatabaseKey
        let sections: [TabSection]
        let totalTabCount: Int

        var id: String {
            switch key {
            case .named(let name): return name
            case .none: return "__none"
            }
        }

        var title: String {
            switch key {
            case .named(let name): return "Database • \(name)"
            case .none: return "Database • Not Selected"
            }
        }

        var activeDatabaseComparisonKey: String? {
            switch key {
            case .named(let name): return name.lowercased()
            case .none: return nil
            }
        }
    }

    private var activeConnectionID: UUID? {
        appModel.sessionManager.activeSession?.connection.id
    }

    private func activeDatabaseName(for serverID: UUID) -> String? {
        guard let session = appModel.sessionManager.activeSessions.first(where: { $0.connection.id == serverID }) else {
            return nil
        }
        return session.selectedDatabaseName?.lowercased()
    }

    private func databaseIdentifier(for key: DatabaseKey, serverID: UUID) -> String {
        switch key {
        case .named(let name):
            return "\(serverID.uuidString)|\(name.lowercased())"
        case .none:
            return "\(serverID.uuidString)|__none"
        }
    }

    private func toggleServerExpansion(serverID: UUID) {
        if collapsedServers.contains(serverID) {
            collapsedServers.remove(serverID)
        } else {
            collapsedServers.insert(serverID)
        }
    }

    private func toggleDatabaseExpansion(identifier: String) {
        if collapsedDatabases.contains(identifier) {
            collapsedDatabases.remove(identifier)
        } else {
            collapsedDatabases.insert(identifier)
        }
    }

    private struct TabSection: Identifiable {
        let id: String
        let title: String?
        let tabs: [WorkspaceTab]
    }

}

private struct TabPreviewCard: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tab.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(tab.connection.connectionName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                previewContent

                if let query = tab.query {
                    if query.isExecuting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text("Running")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                    } else if query.hasExecutedAtLeastOnce {
                        if query.errorMessage != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("Error")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.orange)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("Success")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.green)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.12) : themeManager.windowBackground.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: isActive ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isActive ? 0.18 : 0.1), radius: isActive ? 12 : 8, x: 0, y: isActive ? 8 : 5)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#if os(macOS)
        .onMiddleClick(perform: onClose)
#endif
        .onTapGesture(perform: onSelect)
        .platformHover { hovering in isHovering = hovering }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let query = tab.query {
            if !query.sql.isEmpty {
                Text(query.sql)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("Empty query")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        } else if let editor = tab.structureEditor {
            VStack(alignment: .leading, spacing: 4) {
                Text("Structure view")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(editor.schemaName).\(editor.tableName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}


#if os(macOS)
// MARK: - Safari-Style Tab Bar Chrome

private struct TabChromePalette {
    let baseFill: LinearGradient
    let baseStroke: Color
    let baseShadow: Color
    let activeTabFill: LinearGradient
    let inactiveTabFill: LinearGradient
    let hoverTabFill: LinearGradient
    let dropTabFill: LinearGradient
    let activeTabBorder: Color
    let hoverTabBorder: Color
    let inactiveTabBorder: Color
    let dropTabBorder: Color
    let activeTitle: Color
    let inactiveTitle: Color
    let activeIcon: Color
    let inactiveIcon: Color
    let closeForeground: Color
    let closeHoverForeground: Color
    let closeHoverBackground: Color
    let shadowColor: Color
    let actionButtonFill: LinearGradient
    let actionButtonFillHover: LinearGradient
    let actionButtonFillInactive: LinearGradient
    let actionButtonBorder: Color
    let actionButtonIcon: Color
    let separatorGradient: LinearGradient

    init(theme: AppColorTheme, accent: NSColor, fallbackScheme: ColorScheme) {
        let baseBackground = theme.surfaceBackground.nsColor.usingColorSpace(.deviceRGB) ?? theme.surfaceBackground.nsColor
        let selection = theme.editorSelection.nsColor.usingColorSpace(.deviceRGB) ?? theme.editorSelection.nsColor
        let textColor = theme.surfaceForeground.nsColor
        let accentColor = (theme.accent?.nsColor ?? accent).usingColorSpace(.deviceRGB) ?? accent
        let toneIsDark = theme.tone == .dark

        let baseTop = lighten(baseBackground, by: toneIsDark ? 0.05 : 0.14)
        let baseBottom = darken(baseBackground, by: toneIsDark ? 0.12 : 0.08)
        baseFill = LinearGradient(colors: [Color(nsColor: baseTop), Color(nsColor: baseBottom)], startPoint: .top, endPoint: .bottom)
        baseStroke = Color(nsColor: darken(baseBackground, by: toneIsDark ? 0.18 : 0.12))
        baseShadow = toneIsDark ? Color.black.opacity(0.55) : Color.black.opacity(0.08)

        let accentTop = lighten(accentColor, by: 0.18)
        let accentBottom = darken(accentColor, by: 0.12)
        activeTabFill = LinearGradient(colors: [Color(nsColor: accentTop), Color(nsColor: accentBottom)], startPoint: .top, endPoint: .bottom)

        let inactiveTop = lighten(baseBackground, by: toneIsDark ? 0.08 : 0.06)
        let inactiveBottom = darken(baseBackground, by: toneIsDark ? 0.10 : 0.05)
        inactiveTabFill = LinearGradient(colors: [Color(nsColor: inactiveTop), Color(nsColor: inactiveBottom)], startPoint: .top, endPoint: .bottom)

        let hoverTop = lighten(selection, by: 0.12)
        let hoverBottom = darken(selection, by: 0.08)
        hoverTabFill = LinearGradient(colors: [Color(nsColor: hoverTop), Color(nsColor: hoverBottom)], startPoint: .top, endPoint: .bottom)
        dropTabFill = LinearGradient(colors: [Color(nsColor: accentTop), Color(nsColor: accentBottom)], startPoint: .top, endPoint: .bottom)

        activeTabBorder = Color(nsColor: darken(accentColor, by: 0.18))
        hoverTabBorder = Color(nsColor: darken(selection, by: 0.16))
        inactiveTabBorder = Color(nsColor: darken(baseBackground, by: toneIsDark ? 0.16 : 0.10))
        dropTabBorder = Color(nsColor: darken(accentColor, by: 0.25))

        activeTitle = Color(nsColor: textColor)
        inactiveTitle = Color(nsColor: lighten(textColor, by: toneIsDark ? 0.12 : 0.28))
        activeIcon = activeTitle
        inactiveIcon = inactiveTitle
        closeForeground = Color(nsColor: lighten(textColor, by: 0.1))
        closeHoverForeground = Color.white
        closeHoverBackground = Color(nsColor: lighten(accentColor, by: 0.25)).opacity(0.9)
        shadowColor = baseShadow
        actionButtonFill = LinearGradient(colors: [Color(nsColor: lighten(accentColor, by: 0.2)), Color(nsColor: darken(accentColor, by: 0.12))], startPoint: .top, endPoint: .bottom)
        actionButtonFillHover = LinearGradient(colors: [Color(nsColor: lighten(accentColor, by: 0.24)), Color(nsColor: darken(accentColor, by: 0.08))], startPoint: .top, endPoint: .bottom)
        let inactiveActionTop = lighten(baseBackground, by: 0.12)
        let inactiveActionBottom = darken(baseBackground, by: 0.06)
        actionButtonFillInactive = LinearGradient(colors: [Color(nsColor: inactiveActionTop), Color(nsColor: inactiveActionBottom)], startPoint: .top, endPoint: .bottom)
        actionButtonBorder = Color(nsColor: darken(accentColor, by: 0.2))
        actionButtonIcon = Color.white
        let separatorTop = lighten(baseBackground, by: toneIsDark ? 0.10 : 0.05)
        let separatorBottom = darken(baseBackground, by: toneIsDark ? 0.20 : 0.12)
        separatorGradient = LinearGradient(
            colors: [
                Color(nsColor: separatorTop).opacity(toneIsDark ? 0.65 : 0.8),
                Color(nsColor: separatorBottom).opacity(toneIsDark ? 0.75 : 0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private func clamp(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }

private func lighten(_ color: NSColor, by amount: CGFloat) -> NSColor {
    let rgb = color.usingColorSpace(.deviceRGB) ?? color
    return NSColor(red: clamp(rgb.redComponent + amount),
                   green: clamp(rgb.greenComponent + amount),
                   blue: clamp(rgb.blueComponent + amount),
                   alpha: rgb.alphaComponent)
}

private func darken(_ color: NSColor, by amount: CGFloat) -> NSColor {
    let rgb = color.usingColorSpace(.deviceRGB) ?? color
    return NSColor(red: clamp(rgb.redComponent - amount),
                   green: clamp(rgb.greenComponent - amount),
                   blue: clamp(rgb.blueComponent - amount),
                   alpha: rgb.alphaComponent)
}

private struct TabStripBackground: View {
    enum Style {
        case standard(ColorScheme)
        case themed(TabChromePalette)
    }

    var style: Style

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
    }

    var body: some View {
        shape
            .fill(fillGradient)
            .overlay(shape.stroke(strokeColor, lineWidth: tabHairlineWidth()))
            .shadow(color: shadowColor, radius: 2.5, y: 1)
            .frame(height: 24)
            .allowsHitTesting(false)
    }

    private var fillGradient: LinearGradient {
        switch style {
        case .standard(let scheme):
            if scheme == .dark {
                return LinearGradient(colors: [
                    Color.white.opacity(0.20),
                    Color.white.opacity(0.13)
                ], startPoint: .top, endPoint: .bottom)
            } else {
                return LinearGradient(colors: [
                    Color(white: 0.96),
                    Color(white: 0.90)
                ], startPoint: .top, endPoint: .bottom)
            }
        case .themed(let palette):
            return palette.baseFill
        }
    }

    private var strokeColor: Color {
        switch style {
        case .standard(let scheme):
            return scheme == .dark ? Color.white.opacity(0.24) : Color(white: 0.84)
        case .themed(let palette):
            return palette.baseStroke
        }
    }

    private var shadowColor: Color {
        switch style {
        case .standard(let scheme):
            return scheme == .dark ? Color.black.opacity(0.26) : Color.black.opacity(0.06)
        case .themed(let palette):
            return palette.baseShadow
        }
    }
}

private struct SafariTabBarBackground: View {
    var body: some View {
        LinearGradient(colors: [Color.white.opacity(0.16), Color.black.opacity(0.14)], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

private struct SafariTabBarTopEdge: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.45))
            .frame(height: tabHairlineWidth())
    }
}

// MARK: - Middle Click Support

private struct MiddleClickGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(MiddleClickCapture(onMiddleClick: action))
    }
}

private struct MiddleClickCapture: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMiddleClick: onMiddleClick)
    }

    func makeNSView(context: Context) -> MiddleClickReceiverView {
        let view = MiddleClickReceiverView()
        view.onSuperviewReady = { superview in
            context.coordinator.attach(to: superview)
        }
        return view
    }

    func updateNSView(_ nsView: MiddleClickReceiverView, context: Context) {
        context.coordinator.onMiddleClick = onMiddleClick
        if let superview = nsView.superview {
            context.coordinator.attach(to: superview)
        }
    }

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var onMiddleClick: () -> Void
        private weak var recognizer: NSClickGestureRecognizer?
        private weak var attachedView: NSView?

        init(onMiddleClick: @escaping () -> Void) {
            self.onMiddleClick = onMiddleClick
        }

        func attach(to view: NSView) {
            guard attachedView !== view else { return }
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }

            let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleMiddleClick(_:)))
            recognizer.buttonMask = 0x4
            recognizer.numberOfClicksRequired = 1
            recognizer.delegate = self
            view.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
            attachedView = view
        }

        @objc private func handleMiddleClick(_ recognizer: NSClickGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onMiddleClick()
        }

        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            true
        }
    }
}

private final class MiddleClickReceiverView: NSView {
    var onSuperviewReady: ((NSView) -> Void)?

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let superview {
            onSuperviewReady?(superview)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        modifier(MiddleClickGestureModifier(action: action))
    }
}
#else
private struct TabChromePalette {}

private struct TabStripBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(white: 0.92))
            .allowsHitTesting(false)
    }
}

extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        self
    }
}
#endif
