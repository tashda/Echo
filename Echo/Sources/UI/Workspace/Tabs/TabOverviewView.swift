import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct TabOverviewView: View {
    let tabs: [WorkspaceTab]
    let activeTabId: UUID?
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appModel: AppModel

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
    private let gridSpacing: CGFloat = 16

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
        .background(themeManager.windowBackground)
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

    private var header: some View {
        HStack(spacing: 12) {
            Text("Tab Overview")
                .font(.title3.weight(.semibold))

            Spacer()

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
        .padding(.horizontal, 24)
        .padding(.top, 20)
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
        let grouped = Dictionary(grouping: tabs) { tab in
            tab.connection.id
        }

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
                    VStack(alignment: .leading, spacing: 10) {
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
                                .onTapGesture {
                                    focusedTabId = tab.id
                                }
                                .focusEffectDisabled(true)
                                .onDrag {
                                    draggingTabId = tab.id
                                    return NSItemProvider(object: tab.id.uuidString as NSString)
                                } preview: {
                                    EmptyView()
                                }
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

    private func databaseIdentifier(for key: DatabaseKey, serverID: UUID) -> String {
        switch key {
        case .named(let name):
            return "\(serverID.uuidString)|\(name.lowercased())"
        case .none:
            return "\(serverID.uuidString)|__none"
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

    private func databaseGroups(for tabs: [WorkspaceTab]) -> [DatabaseGroup] {
        guard !tabs.isEmpty else { return [] }

        var grouped: [DatabaseKey: [WorkspaceTab]] = [:]
        for tab in tabs {
            grouped[databaseKey(for: tab), default: []].append(tab)
        }

        let orderedDatabaseKeys = grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (.named(left), .named(right)):
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            case (.named, .none):
                return true
            case (.none, .named):
                return false
            case (.none, .none):
                return true
            }
        }

        return orderedDatabaseKeys.map { key in
            let matchingTabs = grouped[key] ?? []
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                statusIndicator

                VStack(alignment: .leading, spacing: 2) {
                    Text(tabTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(tabSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            previewContent
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(focusRing)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        switch tab.kind {
        case .query:
            if tab.query?.isExecuting == true {
                return .green
            }
            return .blue
        case .diagram:
            return .purple
        case .structure:
            return .orange
        }
    }

    private var tabTitle: String {
        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled" : title
    }

    private var tabSubtitle: String {
        switch tab.kind {
        case .query:
            return "Query Editor"
        case .diagram:
            return "Diagram"
        case .structure:
            return "Structure Editor"
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.primary.opacity(isFocused ? 0.08 : (isHovering ? 0.05 : 0.03)))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                isDropTarget ? Color.accentColor.opacity(0.55) : Color.primary.opacity(isFocused ? 0.25 : 0.08),
                lineWidth: isDropTarget ? 2 : 1
            )
    }

    private var focusRing: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.accentColor.opacity(isFocused ? 0.32 : 0), lineWidth: 2.4)
    }
}

#if os(macOS)
private struct EmptyPreviewPlaceholder: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(12)
    }
}
#else
private struct EmptyPreviewPlaceholder: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(12)
    }
}
#endif

private struct QueryTabPreview: View {
    @ObservedObject var query: QueryEditorState

    private var trimmedSQL: String {
        let trimmed = query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    private var status: (icon: String, text: String, color: Color) {
        if query.isExecuting {
            return ("play.fill", "Running…", .accentColor)
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
                    .foregroundStyle(.tertiary)
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
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DiagramTabPreview: View {
    @ObservedObject var diagram: SchemaDiagramViewModel

    private var status: (icon: String, text: String, color: Color) {
        if diagram.isLoading {
            return ("hourglass", "Loading…", .accentColor)
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
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StructureTabPreview: View {
    @ObservedObject var editor: TableStructureEditorViewModel

    private var status: (icon: String, text: String, color: Color) {
        if editor.isApplying {
            return ("hammer.fill", "Applying changes…", .accentColor)
        }
        if editor.isLoading {
            return ("arrow.triangle.2.circlepath", "Refreshing…", .accentColor)
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
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
