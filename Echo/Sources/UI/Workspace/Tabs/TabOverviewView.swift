import SwiftUI
import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct TabOverviewView: View {
    let tabs: [WorkspaceTab]
    let activeTabId: UUID?
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var animateIn = false
    @State private var collapsedServers: Set<UUID> = []
    @State private var collapsedDatabases: Set<String> = []
    @State private var focusedTabId: UUID?
    @State private var columnCount: Int = 1
    @State private var lastVisibleTabIDs: [UUID] = []
    @State private var draggingTabId: UUID?
    @State private var dropTargetTabId: UUID?

    private let minCardWidth: CGFloat = 260
    private let maxCardWidth: CGFloat = 360
    private let gridSpacing: CGFloat = 18

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: minCardWidth, maximum: maxCardWidth), spacing: gridSpacing),
            count: max(columnCount, 1)
        )
    }

    private var orderedTabIDs: [UUID] { tabs.map(\.id) }
    private var visibleTabIDs: [UUID] {
        groupedTabs.reduce(into: [UUID]()) { result, serverGroup in
            let serverID = serverGroup.connection.id
            guard !collapsedServers.contains(serverID) else { return }
            for databaseGroup in serverGroup.databaseGroups {
                let identifier = databaseIdentifier(for: databaseGroup.key, serverID: serverID)
                guard !collapsedDatabases.contains(identifier) else { continue }
                for section in databaseGroup.sections {
                    result.append(contentsOf: section.tabs.map(\.id))
                }
            }
        }
    }

    private var animation: Animation { .spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2) }

    var body: some View {
        VStack(spacing: 28) {
            overviewHero

            ScrollView {
                if groupedTabs.isEmpty {
                    emptyState
                        .padding(.top, 120)
                        .padding(.horizontal, 32)
                } else {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(groupedTabs) { serverGroup in
                            serverGroupView(serverGroup)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
#if os(macOS)
                    Color.clear
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
                            targetTabID: nil,
                            isTrailingPlaceholder: true,
                            appModel: appModel,
                            draggingTabId: $draggingTabId,
                            dropTargetTabId: $dropTargetTabId
                        ))
#endif
                }
            }
        }
        .padding(.bottom, 40)
        .background(overviewBackground)
        .onAppear {
            triggerAnimation()
            initializeFocus()
        }
        .onDisappear {
            draggingTabId = nil
            dropTargetTabId = nil

            if let active = activeTabId {
                focusedTabId = active
            }
        }
#if os(macOS)
        .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
            targetTabID: nil,
            isTrailingPlaceholder: true,
            appModel: appModel,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId
        ))
#endif
        .onChange(of: tabs.map(\.id)) { _, ids in
            updateFocusForTabChanges(ids: ids)
        }
        .onChange(of: focusedTabId) { _, _ in
            ensureFocusedTabVisible()
        }
        .animation(animation, value: animateIn)
    }

    private var overviewHero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tab Overview")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(heroSubtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button("Collapse All") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            collapseAll()
                        }
                    }
                    .buttonStyle(.borderless)

                    Button("Expand All") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            expandAll()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack(alignment: .center, spacing: 16) {
                heroStat(icon: "rectangle.grid.2x2.fill", title: formattedCount(totalTabs), subtitle: "Open Tabs")
                heroStat(icon: "bolt.fill", title: formattedCount(runningQueriesCount), subtitle: "Running")
                heroStat(icon: "tablecells", title: formattedCount(totalRowCount), subtitle: "Rows Fetched")

                Spacer(minLength: 0)

                if let last = latestActivityDate {
                    Label("Updated " + relativeDateString(from: last), systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Label("No activity yet", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                }
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: heroShadowColor, radius: 18, y: 10)
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func heroStat(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(heroAccentColor)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(minWidth: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.06), lineWidth: 0.6)
        )
    }

    private var overviewBackground: some View {
#if os(macOS)
        let top = Color(nsColor: .windowBackgroundColor)
        let bottom = Color(nsColor: .windowBackgroundColor).opacity(0.97)
#else
        let top = Color(.systemBackground)
        let bottom = Color(.systemBackground)
#endif
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var heroBackground: LinearGradient {
        LinearGradient(
            colors: [
                heroAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.16),
                heroAccentColor.opacity(colorScheme == .dark ? 0.08 : 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroAccentColor: Color {
#if os(macOS)
        Color(nsColor: NSColor.controlAccentColor)
#else
        Color.accentColor
#endif
    }

    private var heroShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12)
    }

    private var heroSubtitle: String {
        "\(formattedCount(totalTabs)) open tabs across \(formattedCount(activeConnectionCount)) connection\(activeConnectionCount == 1 ? "" : "s")"
    }

    private var totalTabs: Int { tabs.count }

    private var activeConnectionCount: Int {
        Set(tabs.map { $0.connection.id }).count
    }

    private var runningQueriesCount: Int {
        tabs.filter { $0.query?.isExecuting == true }.count
    }

    private var totalRowCount: Int {
        tabs.reduce(0) { $0 + ($1.query?.rowProgress.displayCount ?? 0) }
    }

    private var latestActivityDate: Date? {
        tabs.compactMap { latestExecutionDate(for: $0) }.max()
    }

    private func latestExecutionDate(for tab: WorkspaceTab) -> Date? {
        if let message = tab.query?.messages.last(where: { $0.severity != .debug }) {
            return message.timestamp
        }
        if let diagram = tab.diagram {
            switch diagram.loadSource {
            case .live(let date): return date
            case .cache(let date): return date
            }
        }
        return nil
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func triggerAnimation() {
        animateIn = true
    }

    private func initializeFocus() {
        let visible = visibleTabIDs
        lastVisibleTabIDs = visible

        if let active = activeTabId, visible.contains(active) {
            focusedTabId = active
        } else if let firstVisible = visible.first {
            focusedTabId = firstVisible
        } else {
            focusedTabId = tabs.first?.id
        }

        ensureFocusedTabVisible()
    }

    private func ensureFocusedTabVisible() {
        let visible = visibleTabIDs
        lastVisibleTabIDs = visible
        guard let focusedTabId else { return }
        if !visible.contains(focusedTabId) {
            withAnimation(animation) {
                focusedTabIdChanged(focusedTabId)
            }
        }
    }

    private func focusedTabIdChanged(_ tabId: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabId }) else { return }
        collapsedServers.remove(tab.connection.id)
        let key = databaseKey(for: tab)
        let identifier = databaseIdentifier(for: key, serverID: tab.connection.id)
        collapsedDatabases.remove(identifier)
        lastVisibleTabIDs = visibleTabIDs
    }

    private func updateFocusForTabChanges(ids: [UUID]) {
        lastVisibleTabIDs = visibleTabIDs
        guard let focusedTabId else { return }
        if !ids.contains(focusedTabId) {
            self.focusedTabId = ids.first
        }
    }

    private var groupedTabs: [ServerGroup] {
        let grouped = Dictionary(grouping: tabs) { $0.connection.id }

        return grouped.keys.compactMap { id in
            guard let connection = appModel.connections.first(where: { $0.id == id }) else { return nil }
            let serverTabs = grouped[id] ?? []
            return ServerGroup(
                connection: connection,
                databaseGroups: databaseGroups(for: serverTabs),
                totalTabCount: serverTabs.count
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 42))
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

        return VStack(alignment: .leading, spacing: 18) {
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
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(group.databaseGroups) { databaseGroup in
                        databaseSectionView(databaseGroup, serverID: serverID)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    isActiveServer ? heroAccentColor.opacity(0.35) : Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.06),
                    lineWidth: isActiveServer ? 1.6 : 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 18, y: 10)
    }

    private func serverHeader(for connection: SavedConnection) -> some View {
        let displayName = connection.connectionName.isEmpty ? connection.host : connection.connectionName
        let initials = displayName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()

        return HStack(spacing: 12) {
            Circle()
                .fill(connection.color.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initials.isEmpty ? "DB" : String(initials.prefix(2)))
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
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(databaseGroup.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        if let title = section.title {
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                            ForEach(section.tabs) { tab in
                                TabPreviewCard(
                                    tab: tab,
                                    isActive: tab.id == activeTabId,
                                    isFocused: tab.id == focusedTabId,
                                    isDropTarget: tab.id == dropTargetTabId,
                                    onSelect: { onSelectTab(tab.id) },
                                    onClose: { onCloseTab(tab.id) }
                                )
                                .onTapGesture { focusedTabId = tab.id }
                                .focusEffectDisabled(true)
                                .onDrag {
                                    draggingTabId = tab.id
                                    return NSItemProvider(object: tab.id.uuidString as NSString)
                                } preview: { EmptyView() }
#if os(macOS)
                                .onDrop(of: [UTType.plainText], delegate: TabOverviewDropDelegate(
                                    targetTabID: tab.id,
                                    isTrailingPlaceholder: false,
                                    appModel: appModel,
                                    draggingTabId: $draggingTabId,
                                    dropTargetTabId: $dropTargetTabId
                                ))
#endif
                            }
                        }
                        .onAppear {
                            updateColumnCount(for: section.tabs.count)
                        }
                    }
                }
            }
        }
    }

    private func updateColumnCount(for tabCount: Int) {
        columnCount = max(1, min(4, tabCount))
    }

    private func collapseAll() {
        collapsedServers = Set(groupedTabs.map(\.connection.id))
        collapsedDatabases = []
    }

    private func expandAll() {
        collapsedServers = []
        collapsedDatabases = []
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

    private var activeConnectionID: UUID? {
        tabs.first(where: { $0.id == activeTabId })?.connection.id
    }

    private func databaseGroups(for tabs: [WorkspaceTab]) -> [DatabaseGroup] {
        guard !tabs.isEmpty else { return [] }

        let grouped = Dictionary(grouping: tabs) { databaseKey(for: $0) }
        return grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.named(let l), .named(let r)):
                return l.lowercased() < r.lowercased()
            case (.named, .none):
                return true
            case (.none, .named):
                return false
            case (.none, .none):
                return true
            }
        }.map { key in
            let tabs = grouped[key] ?? []
            return DatabaseGroup(
                key: key,
                sections: sections(for: tabs),
                totalTabCount: tabs.count
            )
        }
    }

    private func sections(for tabs: [WorkspaceTab]) -> [TabSection] {
        guard !tabs.isEmpty else { return [] }

        let queries = tabs.filter { $0.kind == .query }
        let diagrams = tabs.filter { $0.kind == .diagram }
        let structures = tabs.filter { $0.kind == .structure }

        var sections: [TabSection] = []
        if !queries.isEmpty {
            sections.append(TabSection(id: "queries", title: "Queries", tabs: queries))
        }
        if !diagrams.isEmpty {
            sections.append(TabSection(id: "diagrams", title: "Diagrams", tabs: diagrams))
        }
        if !structures.isEmpty {
            sections.append(TabSection(id: "structures", title: "Structure", tabs: structures))
        }
        return sections
    }

    private enum DatabaseKey: Hashable {
        case named(String)
        case none
    }

    private func databaseKey(for tab: WorkspaceTab) -> DatabaseKey {
        guard let name = databaseName(for: tab) else { return .none }
        return .named(name)
    }

    private func databaseName(for tab: WorkspaceTab) -> String? {
        if let session = appModel.sessionManager.activeSessions.first(where: { $0.id == tab.connectionSessionID }),
           let selected = session.selectedDatabaseName,
           !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selected
        }
        let trimmed = tab.connection.database.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func databaseIdentifier(for key: DatabaseKey, serverID: UUID) -> String {
        switch key {
        case .named(let name): return "\(serverID.uuidString)::\(name.lowercased())"
        case .none: return "\(serverID.uuidString)::__none"
        }
    }

    private func activeDatabaseName(for serverID: UUID) -> String? {
        appModel.sessionManager.activeSessions.first(where: { $0.connection.id == serverID })?.selectedDatabaseName?.lowercased()
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

    private struct TabSection: Identifiable {
        let id: String
        let title: String?
        let tabs: [WorkspaceTab]
    }
}

private struct TabPreviewCard: View {
    @ObservedObject var tab: WorkspaceTab
    let isActive: Bool
    let isFocused: Bool
    let isDropTarget: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        let container = RoundedRectangle(cornerRadius: 24, style: .continuous)
        VStack(spacing: 0) {
            previewSection

            VStack(alignment: .leading, spacing: 14) {
                headerSection
                Divider()
                footerMetrics
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(focusRing)
        .clipShape(container)
        .shadow(color: cardShadow, radius: isFocused ? 16 : 9, y: isFocused ? 10 : 6)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var previewSection: some View {
        previewContent
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
            .frame(height: 156)
            .background(previewBackground.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)))
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            statusIndicator

            VStack(alignment: .leading, spacing: 4) {
                Text(tabTitle)
                    .font(.system(size: 16, weight: .semibold))
                Text(tabSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var footerMetrics: some View {
        HStack(alignment: .center, spacing: 14) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                Label(metric.text, systemImage: metric.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(metric.color)
            }
            Spacer(minLength: 0)
        }
    }

    private var metrics: [Metric] {
        switch tab.kind {
        case .query:
            return queryMetrics
        case .diagram:
            return diagramMetrics
        case .structure:
            return structureMetrics
        }
    }

    private var queryMetrics: [Metric] {
        guard let query = tab.query else { return [] }
        var items: [Metric] = []

        if let event = query.messages.last(where: { $0.severity != .debug }) {
            items.append(Metric(icon: "clock.arrow.circlepath", text: relativeDescription(for: event.timestamp), color: Color.secondary))
        }

        let rows = query.rowProgress.displayCount
        if rows > 0 {
            items.append(Metric(icon: "tablecells", text: "\(formattedNumber(rows)) rows", color: Color.secondary))
        }

        let status = tabStatus
        items.append(Metric(icon: status.icon, text: status.text, color: status.color))

        return items
    }

    private var diagramMetrics: [Metric] {
        guard let diagram = tab.diagram else { return [Metric(icon: tabStatus.icon, text: tabStatus.text, color: tabStatus.color)] }
        var items: [Metric] = []
        items.append(Metric(icon: "square.grid.2x2.fill", text: "\(diagram.nodes.count) node\(diagram.nodes.count == 1 ? "" : "s")", color: Color.secondary))
        switch diagram.loadSource {
        case .live(let date):
            items.append(Metric(icon: "clock.arrow.circlepath", text: relativeDescription(for: date), color: Color.secondary))
        case .cache(let date):
            items.append(Metric(icon: "archivebox.fill", text: "Cached \(relativeDescription(for: date))", color: Color.secondary))
        }
        items.append(Metric(icon: tabStatus.icon, text: tabStatus.text, color: tabStatus.color))
        return items
    }

    private var structureMetrics: [Metric] {
        guard let editor = tab.structureEditor else { return [Metric(icon: tabStatus.icon, text: tabStatus.text, color: tabStatus.color)] }
        return [
            Metric(icon: "tablecells", text: "\(editor.columns.count) column\(editor.columns.count == 1 ? "" : "s")", color: Color.secondary),
            Metric(icon: tabStatus.icon, text: tabStatus.text, color: tabStatus.color)
        ]
    }

    private func relativeDescription(for date: Date) -> String {
        let value = TabPreviewCard.relativeFormatter.localizedString(for: date, relativeTo: Date())
        return value.capitalized
    }

    private var statusIndicator: some View {
        Circle()
            .fill(tabStatus.color.opacity(isHovering ? 0.9 : 0.75))
            .frame(width: 10, height: 10)
    }

    private var tabStatus: (icon: String, text: String, color: Color) {
        switch tab.kind {
        case .query:
            guard let query = tab.query else { return ("clock", "Not executed yet", Color.secondary) }
            if query.isExecuting {
                return ("bolt.fill", "Running", themeManager.accentColor)
            }
            if let message = query.errorMessage, !message.isEmpty {
                return ("exclamationmark.triangle.fill", "Last run failed", .orange)
            }
            if query.hasExecutedAtLeastOnce {
                return ("checkmark.circle.fill", "Last run succeeded", .green)
            }
            return ("clock", "Not executed yet", Color.secondary)
        case .diagram:
            if let diagram = tab.diagram {
                if diagram.isLoading {
                    return ("hourglass", "Loading diagram", themeManager.accentColor)
                }
                if let error = diagram.errorMessage, !error.isEmpty {
                    return ("exclamationmark.triangle.fill", "Diagram error", .orange)
                }
                return ("chart.xyaxis.line", "Diagram ready", Color.secondary)
            }
            return ("circle", "No diagram data", Color.secondary.opacity(0.45))
        case .structure:
            if let editor = tab.structureEditor {
                if editor.isApplying {
                    return ("hammer.fill", "Applying changes…", themeManager.accentColor)
                }
                if editor.isLoading {
                    return ("arrow.triangle.2.circlepath", "Refreshing", themeManager.accentColor)
                }
                if let error = editor.lastError, !error.isEmpty {
                    return ("exclamationmark.triangle.fill", "Last update failed", .orange)
                }
                if let success = editor.lastSuccessMessage, !success.isEmpty {
                    return ("checkmark.circle.fill", success, .green)
                }
                return ("tablecells", "Structure ready", Color.secondary)
            }
            return ("circle", "No structure data", Color.secondary.opacity(0.45))
        }
    }

    private var tabTitle: String {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled" : title
    }

    private var tabSubtitle: String {
        switch tab.kind {
        case .query:
            let connection = tab.connection
            let display = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
            let host = connection.host
            return display.isEmpty ? host : display
        case .diagram:
            return "Diagram"
        case .structure:
            return "Table Structure"
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch tab.kind {
        case .query:
            if let query = tab.query {
                QueryTabPreview(query: query)
            } else {
                EmptyPreviewPlaceholder(message: "Query unavailable")
            }
        case .diagram:
            if let diagram = tab.diagram {
                DiagramTabPreview(diagram: diagram)
            } else {
                EmptyPreviewPlaceholder(message: "Diagram unavailable")
            }
        case .structure:
            if let editor = tab.structureEditor {
                StructureTabPreview(editor: editor)
            } else {
                EmptyPreviewPlaceholder(message: "Structure unavailable")
            }
        }
    }

    private var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.18),
                Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(isFocused ? 0.18 : 0.12) : Color.white)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                isDropTarget ? themeManager.accentColor : Color.primary.opacity(isFocused ? 0.18 : 0.06),
                lineWidth: isDropTarget ? 2.6 : (isFocused ? 1.4 : 1)
            )
    }

    private var focusRing: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(themeManager.accentColor.opacity(isFocused ? 0.38 : 0), lineWidth: 2.8)
    }

    private var cardShadow: Color {
        Color.black.opacity(colorScheme == .dark ? (isFocused ? 0.55 : 0.45) : (isFocused ? 0.2 : 0.1))
    }

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private struct Metric {
        let icon: String
        let text: String
        let color: Color
    }
}

private struct EmptyPreviewPlaceholder: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(12)
    }
}

private struct QueryTabPreview: View {
    @ObservedObject var query: QueryEditorState

    private var trimmedSQL: String {
        let trimmed = query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    private var status: (icon: String, text: String, color: Color) {
        if query.isExecuting {
            return ("bolt.fill", "Running", Color.accentColor)
        }

        if let error = query.errorMessage, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Last run failed", .orange)
        }

        if query.hasExecutedAtLeastOnce {
            return ("checkmark.circle.fill", "\(formattedRowCount) rows", .green)
        }

        return ("clock", "Not executed yet", .secondary)
    }

    private var formattedRowCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let value = query.rowProgress.displayCount
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if trimmedSQL.isEmpty {
                Text("Empty query")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(trimmedSQL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
            }

            Label(status.text, systemImage: status.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

private struct DiagramTabPreview: View {
    @ObservedObject var diagram: SchemaDiagramViewModel

    private var status: (icon: String, text: String, color: Color) {
        if diagram.isLoading {
            return ("hourglass", "Loading…", Color.accentColor)
        }
        if let error = diagram.errorMessage, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Diagram error", .orange)
        }
        return ("chart.xyaxis.line", "\(diagram.nodes.count) table\(diagram.nodes.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(diagram.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Label(status.text, systemImage: status.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status.color)

            if let message = diagram.statusMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

private struct StructureTabPreview: View {
    @ObservedObject var editor: TableStructureEditorViewModel

    private var status: (icon: String, text: String, color: Color) {
        if editor.isApplying {
            return ("hammer.fill", "Applying changes…", Color.accentColor)
        }
        if editor.isLoading {
            return ("arrow.triangle.2.circlepath", "Refreshing…", Color.accentColor)
        }
        if let error = editor.lastError, !error.isEmpty {
            return ("exclamationmark.triangle.fill", "Last update failed", .orange)
        }
        if let message = editor.lastSuccessMessage, !message.isEmpty {
            return ("checkmark.circle.fill", message, .green)
        }
        return ("tablecells", "\(editor.columns.count) column\(editor.columns.count == 1 ? "" : "s")", .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(editor.schemaName).\(editor.tableName)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Label(status.text, systemImage: status.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status.color)

            if !editor.indexes.isEmpty {
                Text("\(editor.indexes.count) index\(editor.indexes.count == 1 ? "" : "es") configured")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

#if os(macOS)
private struct TabOverviewDropDelegate: DropDelegate {
    let targetTabID: UUID?
    let isTrailingPlaceholder: Bool
    let appModel: AppModel
    @Binding var draggingTabId: UUID?
    @Binding var dropTargetTabId: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggingTabId != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingTabId else { return }
        Task { @MainActor in
            if isTrailingPlaceholder {
                let count = appModel.tabManager.tabs.count
                guard count > 0 else { return }
                let destinationIndex = count - 1
                appModel.tabManager.moveTab(id: draggingID, to: destinationIndex)
                dropTargetTabId = nil
            } else if let targetID = targetTabID,
                      targetID != draggingID,
                      let targetIndex = appModel.tabManager.index(of: targetID) {
                appModel.tabManager.moveTab(id: draggingID, to: targetIndex)
                dropTargetTabId = targetID
            }
        }
    }

    func dropExited(info: DropInfo) {
        if isTrailingPlaceholder {
            dropTargetTabId = nil
        } else if dropTargetTabId == targetTabID {
            dropTargetTabId = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTabId = nil
        dropTargetTabId = nil
        return true
    }
}
#endif
