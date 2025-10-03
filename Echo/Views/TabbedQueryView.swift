import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

struct TabbedQueryView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            tabBar

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
            } else if let activeTab = appModel.tabManager.activeTab {
                WorkspaceContentView(
                    tab: activeTab,
                    runQuery: { sql in await runQuery(tabId: activeTab.id, sql: sql) },
                    cancelQuery: { cancelQuery(tabId: activeTab.id) }
                )
            } else {
                ContentUnavailableView {
                    Label("No Tabs", systemImage: "doc.text")
                } description: {
                    Text("Open a connection to start working")
                } actions: {
                    Button("New Query", action: createNewTab)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear(perform: createInitialTabIfNeeded)
        .onChange(of: appModel.selectedConnection) { _, _ in
            createInitialTabIfNeeded()
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(appModel.tabManager.tabs) { tab in
                        WorkspaceTabButton(
                            tab: tab,
                            isActive: appModel.tabManager.activeTabId == tab.id,
                            onSelect: { appModel.tabManager.activeTabId = tab.id },
                            onClose: { appModel.tabManager.closeTab(id: tab.id) }
                        )
                        .id(tab.id)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 40)
        .background(themeManager.windowBackground)
        .overlay(Divider(), alignment: .bottom)
    }

    private func createInitialTabIfNeeded() {
        guard appModel.tabManager.tabs.isEmpty,
              let activeSession = appModel.sessionManager.activeSession else { return }

        appModel.openQueryTab(for: activeSession)
    }

    private func createNewTab() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
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

// MARK: - Workspace Content

private struct WorkspaceContentView: View {
    @ObservedObject var tab: WorkspaceTab
    let runQuery: (String) async -> Void
    let cancelQuery: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
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
                    onCancel: cancelQuery
                )
                .frame(height: query.hasExecutedAtLeastOnce ? totalHeight * ratioBinding.wrappedValue : totalHeight)
                .background(editorBackground)

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
                        .background(resultsBackground)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(themeManager.windowBackground)
        .onAppear(perform: updateClipboardContext)
        .onChange(of: tab.connection.connectionName) { _ in
            updateClipboardContext()
        }
        .onChange(of: tab.connection.database) { _ in
            updateClipboardContext()
        }
    }

    private var editorBackground: Color { themeManager.windowBackground }

    private var resultsBackground: Color { themeManager.windowBackground }

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
        query.updateClipboardContext(serverName: connectionServerName, databaseName: connectionDatabaseName)
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
}

// MARK: - Tab Button

private struct WorkspaceTabButton: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    private var shouldShowClose: Bool {
#if os(macOS)
        return isHovering || isActive
#else
        return true
#endif
    }

    var body: some View {
        HStack(spacing: 6) {
            icon
            Text(tab.title)
                .font(.system(size: 11.5))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)

            if shouldShowClose {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.08))
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        onClose()
                    }
                    .help("Close tab")
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.clear)
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isActive ? Color.black.opacity(0.08) : (isHovering ? Color.black.opacity(0.04) : Color.clear))
        )
        .contentShape(Capsule())
#if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        .onMiddleClick(perform: onClose)
#endif
        .onTapGesture {
            onSelect()
        }
    }

    private var icon: some View {
        Group {
            switch tab.kind {
            case .structure:
                Image(systemName: "tablecells")
                    .font(.system(size: 10, weight: .medium))
            case .query:
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundStyle(isActive ? .primary : .secondary)
    }
}

// MARK: - Resize Handle

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
            recognizer.buttonMask = 0x2
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
extension View {
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        self
    }
}
#endif
