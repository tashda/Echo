import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private struct HoveredExplorerRowIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct SetHoveredExplorerRowIDKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: @Sendable (String?) -> Void = { _ in }
}

private extension EnvironmentValues {
    var hoveredExplorerRowID: String? {
        get { self[HoveredExplorerRowIDKey.self] }
        set { self[HoveredExplorerRowIDKey.self] = newValue }
    }

    var setHoveredExplorerRowID: @Sendable (String?) -> Void {
        get { self[SetHoveredExplorerRowIDKey.self] }
        set { self[SetHoveredExplorerRowIDKey.self] = newValue }
    }
}

/// Database Explorer – hierarchical object list rendered in the explorer sidebar.
struct DatabaseObjectBrowserView: View {
    let database: DatabaseInfo
    let connection: SavedConnection
    @Binding var searchText: String
    @Binding var selectedSchemaName: String?
    @Binding var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType>
    @Binding var expandedObjectIDs: Set<String>
    @Binding var pinnedObjectIDs: Set<String>
    @Binding var isPinnedSectionExpanded: Bool
    let scrollTo: (String, UnitPoint) -> Void
    
    @EnvironmentObject private var appModel: AppModel
    @State private var snapshotCache = ExplorerSnapshotCache()
    @State private var hoveredRowID: String?

    private var supportedObjectTypes: [SchemaObjectInfo.ObjectType] {
        SchemaObjectInfo.ObjectType.supported(for: connection.databaseType)
    }
    
    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var normalizedSearchQuery: String? {
        let trimmed = trimmedSearchText
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }
    
    private var isSearching: Bool { normalizedSearchQuery != nil }
    
    private func displayName(for object: SchemaObjectInfo) -> String {
        if selectedSchemaName == nil {
            return object.fullName
        }
        return object.name
    }
    
    private func shouldShowColumns(for object: SchemaObjectInfo) -> Bool {
        object.type == .table || object.type == .view || object.type == .materializedView
    }
    
    private func isPinned(_ object: SchemaObjectInfo) -> Bool {
        pinnedObjectIDs.contains(object.id)
    }
    
    private func togglePin(for object: SchemaObjectInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if pinnedObjectIDs.contains(object.id) {
                pinnedObjectIDs.remove(object.id)
            } else {
                pinnedObjectIDs.insert(object.id)
                isPinnedSectionExpanded = true
            }
        }
    }
    
    private func expansionBinding(for objectID: String) -> Binding<Bool> {
        Binding(
            get: { expandedObjectIDs.contains(objectID) },
            set: { newValue in
                if newValue {
                    expandedObjectIDs.insert(objectID)
                } else {
                    expandedObjectIDs.remove(objectID)
                }
            }
        )
    }
    
    private func revealTable(fullName: String) {
        guard let target = database.schemas
            .flatMap({ $0.objects.filter { $0.type == .table } })
            .first(where: { $0.fullName == fullName }) else { return }
        
        if let selected = selectedSchemaName {
            if selected != target.schema {
                selectedSchemaName = nil
            }
        }
        
        expandedObjectGroups.insert(.table)
        expandedObjectIDs.insert(target.id)
        
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollTo(target.id, UnitPoint(x: 0.5, y: 0.2))
            }
        }
    }
    
    var body: some View {
        let input = SnapshotInput(
            database: database,
            normalizedQuery: normalizedSearchQuery,
            selectedSchemaName: selectedSchemaName,
            pinnedIDs: pinnedObjectIDs,
            supportedTypes: supportedObjectTypes
        )
        let snapshot = snapshotCache.data
        let groupedObjects = snapshot.grouped
        let pinnedList = snapshot.pinned
        let pinnedIDSet = pinnedObjectIDs
        
        return Group {
            if isSearching && snapshot.filteredCount == 0 {
                SearchEmptyStateView(query: searchText)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !pinnedList.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isPinnedSectionExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isPinnedSectionExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    Text("PINNED")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("\(pinnedList.count)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary.opacity(0.8))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.primary.opacity(0.06), in: Capsule())
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if isPinnedSectionExpanded {
                                ForEach(pinnedList, id: \.id) { object in
                                    DatabaseObjectRow(
                                        object: object,
                                        displayName: displayName(for: object),
                                        connection: connection,
                                        showColumns: shouldShowColumns(for: object),
                                        isExpanded: expansionBinding(for: object.id),
                                        isPinned: true,
                                        onTogglePin: { togglePin(for: object) },
                                        onTriggerTableTap: object.type == .trigger ? { tableName in revealTable(fullName: tableName) } : nil
                                    )
                                    .environmentObject(appModel)
                                    .id("pinned-\(object.id)")
                                }
                            }
                        }
                        .id("header-pinned")
                    }
                    
                    ForEach(supportedObjectTypes, id: \.self) { objectType in
                        let objects = groupedObjects[objectType] ?? []
                        
                        let headerID = "header-\(objectType.rawValue)"
                        let isExpanded = expandedObjectGroups.contains(objectType)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if expandedObjectGroups.contains(objectType) {
                                        expandedObjectGroups.remove(objectType)
                                    } else {
                                        expandedObjectGroups.insert(objectType)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(objectType.pluralDisplayName.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("\(objects.count)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary.opacity(0.8))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.primary.opacity(0.06), in: Capsule())
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if isExpanded {
                                ForEach(objects, id: \.id) { object in
                                    DatabaseObjectRow(
                                        object: object,
                                        displayName: displayName(for: object),
                                        connection: connection,
                                        showColumns: shouldShowColumns(for: object),
                                        isExpanded: expansionBinding(for: object.id),
                                        isPinned: pinnedIDSet.contains(object.id),
                                        onTogglePin: { togglePin(for: object) },
                                        onTriggerTableTap: object.type == .trigger ? { tableName in revealTable(fullName: tableName) } : nil
                                    )
                                    .equatable()
                                    .environmentObject(appModel)
                                    .id(object.id)
                                }
                            }
                        }
                        .id(headerID)
                    }
                }
                .environment(\.hoveredExplorerRowID, hoveredRowID)
                .environment(\.setHoveredExplorerRowID, { value in
                    if hoveredRowID != value {
                        hoveredRowID = value
                    }
                })
                .onHover { hovering in
                    if !hovering {
                        hoveredRowID = nil
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .onAppear {
            snapshotCache.update(with: input)
            if ConnectionDebug.isEnabled {
                let groupedTotals = snapshotCache.data.grouped.mapValues { $0.count }
                let totalObjects = snapshotCache.data.grouped.values.reduce(0) { $0 + $1.count }
                ConnectionDebug.log("[ExplorerSidebar] Snapshot initialised for database=\(database.name) search='\(searchText)' schema=\(selectedSchemaName ?? "<all>") objectTotals=\(groupedTotals) pinnedCount=\(snapshotCache.data.pinned.count) totalObjects=\(totalObjects)")
            }
        }
        .onChange(of: input) { _, newValue in
            snapshotCache.update(with: newValue)
            if ConnectionDebug.isEnabled {
                let groupedTotals = snapshotCache.data.grouped.mapValues { $0.count }
                let totalObjects = snapshotCache.data.grouped.values.reduce(0) { $0 + $1.count }
                ConnectionDebug.log("[ExplorerSidebar] Snapshot updated for database=\(database.name) search='\(searchText)' schema=\(selectedSchemaName ?? "<all>") objectTotals=\(groupedTotals) pinnedCount=\(snapshotCache.data.pinned.count) totalObjects=\(totalObjects)")
            }
        }
    }

    // MARK: - Search Empty State
    
private struct SearchEmptyStateView: View {
        let query: String
        
        private var formattedQuery: String {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "your search" }
            return "\"\(trimmed)\""
        }
        
        var body: some View {
            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text("Nothing found for \(formattedQuery)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Try adjusting your filters or search terms.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Database Object Row

    private struct DatabaseObjectRow: View, Equatable {
        let object: SchemaObjectInfo
        let displayName: String
        let connection: SavedConnection
        let showColumns: Bool
        @Binding var isExpanded: Bool
        let isPinned: Bool
        let onTogglePin: () -> Void
        let onTriggerTableTap: ((String) -> Void)?
        
        @EnvironmentObject private var appModel: AppModel
        @Environment(\.hoveredExplorerRowID) private var hoveredExplorerRowID
        @Environment(\.setHoveredExplorerRowID) private var setHoveredExplorerRowID
        @State private var hoveredColumnID: String?

        private var isHovered: Bool {
            hoveredExplorerRowID == object.id
        }

        private var canExpand: Bool {
            showColumns && !object.columns.isEmpty
        }
        
        private var accentColor: Color {
            appModel.useServerColorAsAccent ? connection.color : Color.accentColor
        }
        
        private var iconName: String {
            switch object.type {
            case .table:
                return "tablecells"
            case .view:
                return "eye"
            case .materializedView:
                return "eye.fill"
            case .function:
                return "function"
            case .trigger:
                return "bolt"
            case .procedure:
                return "gearshape"
            }
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                rowContent

                if isExpanded && canExpand {
                    columnsList
                }
            }
        }

        static func == (lhs: DatabaseObjectRow, rhs: DatabaseObjectRow) -> Bool {
            lhs.object.id == rhs.object.id
                && lhs.displayName == rhs.displayName
                && lhs.showColumns == rhs.showColumns
                && lhs.isExpanded == rhs.isExpanded
                && lhs.isPinned == rhs.isPinned
        }
        
        private var rowContent: some View {
            VStack(alignment: .leading, spacing: object.type == .trigger ? 6 : 0) {
                HStack(spacing: 8) {
                    if canExpand {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    } else {
                        Spacer().frame(width: 12)
                    }
                    
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor)
                    
                    Text(displayName)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .contentShape(Rectangle())

                    Spacer()

                    if showColumns && !object.columns.isEmpty {
                        Text("\(object.columns.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.12), in: Capsule())
                    }
                }
                
                if object.type == .trigger {
                    triggerMetadata
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(highlightBackground)
            .contentShape(Rectangle())
            .onTapGesture {
                guard canExpand else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            .onHover { hovering in
                if hovering {
                    if hoveredExplorerRowID != object.id {
                        setHoveredExplorerRowID(object.id)
                    }
                } else if isHovered {
                    setHoveredExplorerRowID(nil)
                }
            }
            .contextMenu { contextMenuContent }
            .onDisappear {
                if isHovered {
                    setHoveredExplorerRowID(nil)
                }
            }
        }
        
        @ViewBuilder
        private var triggerMetadata: some View {
            HStack(spacing: 6) {
                if let action = object.triggerAction, !action.isEmpty {
                    Text(action)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
                if let table = object.triggerTable, !table.isEmpty {
                    Button {
                        onTriggerTableTap?(table)
                    } label: {
                        Text(table)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.leading, 24)
        }
        
        private var highlightBackground: some View {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accentColor.opacity(0.12))
                .opacity(isHovered || isExpanded ? 1 : 0)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.08), value: isHovered)
                .animation(.easeOut(duration: 0.18), value: isExpanded)
        }
        
        private var columnsList: some View {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(object.columns, id: \.name) { (column: ColumnInfo) in
                    HStack(spacing: 8) {
                        let (iconName, iconColor): (String, Color) = {
                            if column.isPrimaryKey {
                                return ("key.fill", accentColor)
                            }
                            if column.foreignKey != nil {
                                return ("arrow.turn.down.right", accentColor)
                            }
                            return ("circle.fill", Color.secondary)
                        }()
                        
                        Image(systemName: iconName)
                            .font(.system(size: iconName == "circle.fill" ? 8 : 10))
                            .foregroundStyle(iconColor)
                        
                        Text(column.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer(minLength: 0)
                        
                        Text(formatDataType(column.dataType))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 12)
                    .background(
                        Group {
                            if hoveredColumnID == column.name {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(accentColor.opacity(0.08))
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .padding(.leading, 36)
                    .contentShape(Rectangle())
#if os(macOS)
                    .onHover { hovering in
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            if hovering {
                                hoveredColumnID = column.name
                            } else if hoveredColumnID == column.name {
                                hoveredColumnID = nil
                            }
                        }
                    }
#endif
                    .contextMenu {
                        Button("Copy Name") {
                            copyColumnName(column)
                        }
                        Button("Rename Column…") {
                            openStructureEditor(for: column)
                        }
                        Button("Drop Column", role: .destructive) {
                            openStructureEditor(for: column, preferDrop: true)
                        }
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
            .onDisappear {
                hoveredColumnID = nil
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        }
        
        private func formatDataType(_ dataType: String) -> String {
            var formatted = dataType
            
            // Replace "with time zone" with "tz"
            if formatted.contains("with time zone") {
                formatted = formatted.replacingOccurrences(of: " with time zone", with: "tz")
            }
            
            // Remove "without time zone"
            if formatted.contains("without time zone") {
                formatted = formatted.replacingOccurrences(of: " without time zone", with: "")
            }
            
            return formatted
        }
        
        private func copyColumnName(_ column: ColumnInfo) {
            let name = column.name
#if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(name, forType: .string)
#else
            UIPasteboard.general.string = name
#endif
        }
        
        private func openStructureEditor(for column: ColumnInfo, preferDrop: Bool = false) {
            Task { @MainActor in
                guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
                appModel.openStructureTab(for: session, object: object, focus: .columns)
                if preferDrop {
                    // Future enhancement: surface drop column affordance once editor supports deep linking.
                }
            }
        }
        
    private var contextMenuContent: some View {
        let generalItems = computeGeneralMenuItems()
        let scriptActions = scriptActionsForCurrentContext()
        let administrativeItems = computeAdministrativeMenuItems()
        return buildContextMenu(
            generalItems: generalItems,
            scriptActions: scriptActions,
            administrativeItems: administrativeItems
        )
    }

    @ViewBuilder
    private func buildContextMenu(
        generalItems: [ContextMenuActionItem],
        scriptActions: [ScriptAction],
        administrativeItems: [ContextMenuActionItem]
    ) -> some View {
        ForEach(generalItems) { item in
            Button(role: item.role) {
                item.action()
            } label: {
                Label(item.title, systemImage: item.systemImage)
            }
        }

        if !scriptActions.isEmpty {
            Divider()
            Menu("Script as", systemImage: "scroll") {
                ForEach(scriptActions, id: \.identifier) { action in
                    Button {
                        performScriptAction(action)
                    } label: {
                        Label(scriptTitle(for: action), systemImage: scriptSystemImage(for: action))
                    }
                }
            }
        }

        if !administrativeItems.isEmpty {
            Divider()
            ForEach(administrativeItems) { item in
                Button(role: item.role) {
                    item.action()
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
        }
    }

    private struct ContextMenuActionItem: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let role: ButtonRole?
        let action: () -> Void

        init(
            id: String? = nil,
            title: String,
            systemImage: String,
            role: ButtonRole?,
            action: @escaping () -> Void
        ) {
            self.id = id ?? title
            self.title = title
            self.systemImage = systemImage
            self.role = role
            self.action = action
        }
    }
        
        private enum ScriptAction {
            case create
            case createOrReplace
            case alter
            case alterTable
            case drop
            case dropIfExists
            case select
            case selectLimited(Int)
            case execute
            
            var identifier: String {
                switch self {
                case .create: return "create"
                case .createOrReplace: return "createOrReplace"
                case .alter: return "alter"
                case .alterTable: return "alterTable"
                case .drop: return "drop"
                case .dropIfExists: return "dropIfExists"
                case .select: return "select"
                case .selectLimited(let limit): return "selectLimited_\(limit)"
                case .execute: return "execute"
                }
            }
        }
        
        private func computeGeneralMenuItems() -> [ContextMenuActionItem] {
            var items: [ContextMenuActionItem] = []
            
            items.append(
                ContextMenuActionItem(
                    id: "newQuery",
                    title: "New Query",
                    systemImage: "doc.badge.plus",
                    role: nil,
                    action: { openNewQueryTab() }
                )
            )
            
            if supportsDataPreview {
                items.append(
                    ContextMenuActionItem(
                        id: "openData",
                        title: "Open Data",
                        systemImage: "tablecells",
                        role: nil,
                        action: { openDataPreview() }
                    )
                )
            }
            
            items.append(
                ContextMenuActionItem(
                    id: "pinToggle",
                    title: isPinned ? "Unpin" : "Pin",
                    systemImage: isPinned ? "pin.slash" : "pin",
                    role: nil,
                    action: { onTogglePin() }
                )
            )
            
            items.append(
                ContextMenuActionItem(
                    id: "viewStructure",
                    title: "View Structure",
                    systemImage: "square.stack.3d.up",
                    role: nil,
                    action: { openStructureTab() }
                )
            )
            
            if supportsDiagram {
                items.append(
                    ContextMenuActionItem(
                        id: "showDiagram",
                        title: "Show Diagram",
                        systemImage: "rectangle.connected.to.line.below",
                        role: nil,
                        action: { openRelationsDiagram() }
                    )
                )
            }
            
            return items
        }
        private func computeAdministrativeMenuItems() -> [ContextMenuActionItem] {
            var items: [ContextMenuActionItem] = []
            
            switch connection.databaseType {
            case .postgresql, .mysql, .microsoftSQL:
                items.append(renameMenuItem)
                if supportsTruncateTable {
                    items.append(
                        ContextMenuActionItem(
                            id: "truncateTable",
                            title: "Truncate Table",
                            systemImage: "scissors",
                            role: .destructive,
                            action: { initiateTruncate() }
                        )
                    )
                }
                items.append(dropMenuItem)
                
            case .sqlite:
                items.append(renameMenuItem)
                items.append(dropMenuItem)
            }
            
            return items
        }
        
        private var renameMenuItem: ContextMenuActionItem {
            ContextMenuActionItem(
                id: "renameObject",
                title: connection.databaseType == .sqlite ? "Rename (Limited)" : "Rename",
                systemImage: "textformat.alt",
                role: nil,
                action: { initiateRename() }
            )
        }
        
        private var dropMenuItem: ContextMenuActionItem {
            ContextMenuActionItem(
                id: "dropObject",
                title: "Drop",
                systemImage: "trash",
                role: .destructive,
                action: { initiateDrop(includeIfExists: false) }
            )
        }
        
        private var supportsDataPreview: Bool {
            switch object.type {
            case .table, .view, .materializedView:
                return true
            case .function, .trigger, .procedure:
                return false
            }
        }
        
        private var supportsDiagram: Bool {
            object.type == .table
        }
        
        private var supportsTruncateTable: Bool {
            guard object.type == .table else { return false }
            switch connection.databaseType {
            case .postgresql, .mysql, .microsoftSQL:
                return true
            case .sqlite:
                return false
            }
        }
        
        private func scriptActionsForCurrentContext() -> [ScriptAction] {
            switch connection.databaseType {
            case .postgresql:
                var actions: [ScriptAction] = [.create]
                if supportsCreateOrReplaceInPostgres {
                    actions.append(.createOrReplace)
                }
                actions.append(.dropIfExists)
                if shouldIncludeSelectScript || object.type == .function || object.type == .procedure {
                    actions.append(.select)
                    if shouldIncludeSelectScript {
                        actions.append(.selectLimited(1000))
                    }
                }
                if object.type == .function || object.type == .procedure {
                    actions.append(.execute)
                }
                return actions
                
            case .mysql:
                var actions: [ScriptAction] = [.create]
                if supportsCreateOrReplaceInMySQL {
                    actions.append(.createOrReplace)
                }
                if object.type == .table {
                    actions.append(.alterTable)
                } else {
                    actions.append(.alter)
                }
                actions.append(.drop)
                if shouldIncludeSelectScript {
                    actions.append(.select)
                    actions.append(.selectLimited(1000))
                }
                if object.type == .function || object.type == .procedure {
                    actions.append(.execute)
                }
                return actions
                
            case .sqlite:
                var actions: [ScriptAction] = [.create, .drop]
                if shouldIncludeSelectScript {
                    actions.append(contentsOf: [.select, .selectLimited(1000)])
                }
                return actions
                
            case .microsoftSQL:
                var actions: [ScriptAction] = [.create, .alter, .dropIfExists]
                if object.type == .function || object.type == .procedure {
                    actions.append(.execute)
                } else if shouldIncludeSelectScript {
                    actions.append(contentsOf: [.select, .selectLimited(1000)])
                }
                return actions
            }
        }
        
        private var supportsCreateOrReplaceInPostgres: Bool {
            switch object.type {
            case .table:
                return false
            default:
                return true
            }
        }
        
        private var supportsCreateOrReplaceInMySQL: Bool {
            object.type == .view
        }
        
        private var shouldIncludeSelectScript: Bool {
            switch object.type {
            case .table, .view, .materializedView:
                return true
            case .function, .trigger, .procedure:
                return false
            }
        }
        
        private func scriptTitle(for action: ScriptAction) -> String {
            switch action {
            case .create:
                return "CREATE"
            case .createOrReplace:
                return "CREATE OR REPLACE"
            case .alterTable:
                return "ALTER TABLE"
            case .alter:
                return "ALTER"
            case .drop:
                return "DROP"
            case .dropIfExists:
                return "DROP IF EXISTS"
            case .select:
                return "SELECT"
            case .selectLimited(let limit):
                return "SELECT \(limit)"
            case .execute:
                return connection.databaseType == .microsoftSQL ? "SELECT / EXEC" : "EXECUTE"
            }
        }
        
        private func scriptSystemImage(for action: ScriptAction) -> String {
            switch action {
            case .create:
                return "plus.rectangle.on.rectangle"
            case .createOrReplace:
                return "arrow.triangle.2.circlepath"
            case .alter, .alterTable:
                return "wrench"
            case .drop:
                return "trash"
            case .dropIfExists:
                return "trash.slash"
            case .select:
                return "text.magnifyingglass"
            case .selectLimited:
                return "text.magnifyingglass"
            case .execute:
                return "play.circle"
            }
        }
        
        private func performScriptAction(_ action: ScriptAction) {
            switch action {
            case .create:
                if object.type == .table {
                    openCreateTableScript()
                } else {
                    openCreateDefinition(insertOrReplace: false)
                }
            case .createOrReplace:
                openCreateDefinition(insertOrReplace: true)
            case .alter:
                openAlterStatement()
            case .alterTable:
                openAlterTableStatement()
            case .drop:
                openDropStatement(includeIfExists: false)
            case .dropIfExists:
                openDropStatement(includeIfExists: true)
            case .select:
                openSelectScript(limit: nil)
            case .selectLimited(let limit):
                openSelectScript(limit: limit)
            case .execute:
                openExecuteScript()
            }
        }
        
        private func openNewQueryTab() {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let sql = "-- Query for \(qualified)\n"
            Task { @MainActor in
                appModel.openQueryTab(for: session, presetQuery: sql)
            }
        }
        
        private func openDataPreview() {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            appModel.openDataPreviewTab(
                for: session,
                object: object,
                sqlBuilder: { limit, offset in
                    selectStatement(limit: limit, offset: offset)
                }
            )
        }
        
        private func openStructureTab() {
            Task { @MainActor in
                guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
                appModel.openStructureTab(for: session, object: object)
            }
        }
        
        private func openRelationsDiagram() {
            guard supportsDiagram else { return }
            Task { @MainActor in
                guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
                appModel.openDiagramTab(for: session, object: object)
            }
        }
        
        private func openCreateDefinition(insertOrReplace: Bool) {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            Task {
                do {
                    let definition = try await session.session.getObjectDefinition(
                        objectName: object.name,
                        schemaName: object.schema,
                        objectType: object.type
                    )
                    let adjusted = insertOrReplace ? applyCreateOrReplace(to: definition) : definition
                    await MainActor.run {
                        appModel.openQueryTab(for: session, presetQuery: adjusted)
                    }
                } catch {
                    await MainActor.run {
                        appModel.lastError = DatabaseError.from(error)
                    }
                }
            }
        }
        
        private func openCreateTableScript() {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            Task {
                do {
                    let details = try await session.session.getTableStructureDetails(
                        schema: object.schema,
                        table: object.name
                    )
                    let script = makeCreateTableScript(details: details)
                    await MainActor.run {
                        appModel.openQueryTab(for: session, presetQuery: script)
                    }
                } catch {
                    await MainActor.run {
                        appModel.lastError = DatabaseError.from(error)
                    }
                }
            }
        }
        
        private func applyCreateOrReplace(to definition: String) -> String {
            guard let range = definition.range(of: "CREATE", options: [.caseInsensitive]) else {
                return definition
            }
            let snippet = definition[range]
            if snippet.lowercased().contains("create or replace") {
                return definition
            }
            return definition.replacingCharacters(in: range, with: "CREATE OR REPLACE")
        }
        
        private func openAlterStatement() {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let statement: String
            switch connection.databaseType {
            case .mysql:
                switch object.type {
                case .function, .procedure:
                    statement = "ALTER FUNCTION \(qualified)\n    -- Update characteristics here;\n"
                case .trigger:
                    statement = "ALTER TRIGGER \(qualified)\n    -- Update trigger definition here;\n"
                default:
                    statement = "ALTER \(objectTypeKeyword()) \(qualified)\n    -- Provide ALTER clauses here;\n"
                }
            case .microsoftSQL:
                statement = """
            ALTER \(objectTypeKeyword()) \(qualified)
            -- Update definition here.
            GO
            """
            case .postgresql, .sqlite:
                statement = """
            -- ALTER is not directly supported for this object. Consider using CREATE OR REPLACE.
            """
            }
            openScriptTab(with: statement)
        }
        
        private func openAlterTableStatement() {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let statement: String
            switch connection.databaseType {
            case .postgresql, .mysql:
                statement = """
            ALTER TABLE \(qualified)
                ADD COLUMN new_column_name data_type;
            """
            case .microsoftSQL:
                statement = """
            ALTER TABLE \(qualified)
                ADD new_column_name data_type;
            """
            case .sqlite:
                statement = """
            ALTER TABLE \(qualified)
                RENAME COLUMN old_column TO new_column;
            """
            }
            openScriptTab(with: statement)
        }
        
        private func openDropStatement(includeIfExists: Bool) {
            let statement = dropStatement(includeIfExists: includeIfExists)
            openScriptTab(with: statement)
        }
        
        private func openSelectScript(limit: Int? = nil) {
            let sql: String
            if object.type == .function || object.type == .procedure {
                sql = executeStatement()
            } else {
                sql = selectStatement(limit: limit)
            }
            openScriptTab(with: sql)
        }
        
        private func openExecuteScript() {
            let sql = executeStatement()
            openScriptTab(with: sql)
        }
        
        private func initiateTruncate() {
#if os(macOS)
            if object.type == .table {
                Task { await presentTruncatePrompt() }
                return
            }
#endif
            let statement = truncateStatement()
            openScriptTab(with: statement)
        }
        
        private func initiateRename() {
#if os(macOS)
            Task { await presentRenamePrompt() }
#else
            if let template = renameStatement() {
                openScriptTab(with: template)
            }
#endif
        }
        
#if os(macOS)
        @MainActor
        private func presentRenamePrompt() async {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            
            let alert = NSAlert()
            alert.icon = NSImage(size: .zero)
            alert.messageText = "Rename \(objectTypeDisplayName())"
            alert.alertStyle = .informational
            alert.informativeText = ""
            applyAppearance(to: alert)
            
            let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            
            let message = NSMutableAttributedString(string: "Enter a new name for the \(objectTypeDisplayName().lowercased()) ", attributes: [
                .font: baseFont
            ])
            message.append(NSAttributedString(string: object.fullName, attributes: [
                .font: boldFont
            ]))
            message.append(NSAttributedString(string: ".", attributes: [
                .font: baseFont
            ]))
            
            let messageLabel = NSTextField(labelWithAttributedString: message)
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            messageLabel.lineBreakMode = .byWordWrapping
            messageLabel.maximumNumberOfLines = 0
            messageLabel.preferredMaxLayoutWidth = 320
            messageLabel.alignment = .left
            
            let textField = NSTextField(string: object.name)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
            
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.spacing = 8
            stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
            stack.addArrangedSubview(messageLabel)
            stack.addArrangedSubview(textField)
            stack.setHuggingPriority(.defaultHigh, for: .vertical)
            stack.setHuggingPriority(.defaultLow, for: .horizontal)
            
            alert.accessoryView = stack
            alert.window.initialFirstResponder = textField
            textField.selectText(nil)
            
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }
            
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty, newName != object.name else { return }
            
            guard let sql = renameStatement(newName: newName) else {
                if let template = renameStatement() {
                    openScriptTab(with: template)
                }
                return
            }
            
            appModel.sessionManager.setActiveSession(session.id)
            appModel.selectedConnectionID = session.connection.id
            
            Task {
                do {
                    _ = try await appModel.executeUpdate(sql)
                    await appModel.refreshDatabaseStructure(
                        for: session.id,
                        scope: .selectedDatabase,
                        databaseOverride: session.selectedDatabaseName
                    )
                } catch {
                    await MainActor.run {
                        appModel.lastError = DatabaseError.from(error)
                    }
                }
            }
        }
#endif
        
        private func initiateDrop(includeIfExists: Bool) {
#if os(macOS)
            if object.type == .table {
                Task { await presentDropPrompt(includeIfExists: includeIfExists) }
                return
            }
#endif
            let statement = dropStatement(includeIfExists: includeIfExists)
            openScriptTab(with: statement)
        }
        
#if os(macOS)
        @MainActor
        private func presentDropPrompt(includeIfExists: Bool) async {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            
            let alert = NSAlert()
            alert.icon = NSImage(size: .zero)
            alert.messageText = "Drop \(objectTypeDisplayName())"
            alert.alertStyle = .warning
            alert.informativeText = ""
            applyAppearance(to: alert)
            
            let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            
            let message = NSMutableAttributedString()
            message.append(NSAttributedString(string: "Are you sure you want to drop the \(objectTypeDisplayName().lowercased()) ", attributes: [
                .font: baseFont
            ]))
            message.append(NSAttributedString(string: object.fullName, attributes: [
                .font: boldFont
            ]))
            message.append(NSAttributedString(string: "?\nThis action cannot be undone.", attributes: [
                .font: baseFont
            ]))
            
            let messageLabel = NSTextField(labelWithAttributedString: message)
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            messageLabel.lineBreakMode = .byWordWrapping
            messageLabel.maximumNumberOfLines = 0
            messageLabel.preferredMaxLayoutWidth = 320
            messageLabel.alignment = .left
            
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.spacing = 6
            stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
            stack.addArrangedSubview(messageLabel)
            stack.setHuggingPriority(.required, for: .vertical)
            stack.setHuggingPriority(.required, for: .horizontal)
            
            alert.accessoryView = stack
            
            let dropButton = alert.addButton(withTitle: "Drop")
            if #available(macOS 11.0, *) {
                dropButton.hasDestructiveAction = true
            }
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }
            
            let statement = dropStatement(includeIfExists: includeIfExists)
            
            appModel.sessionManager.setActiveSession(session.id)
            appModel.selectedConnectionID = session.connection.id
            
            Task {
                do {
                    _ = try await appModel.executeUpdate(statement)
                    if isPinned {
                        await MainActor.run {
                            onTogglePin()
                        }
                    }
                    await appModel.refreshDatabaseStructure(
                        for: session.id,
                        scope: .selectedDatabase,
                        databaseOverride: session.selectedDatabaseName
                    )
                } catch {
                    await MainActor.run {
                        appModel.lastError = DatabaseError.from(error)
                    }
                }
            }
        }
        
        @MainActor
        private func presentTruncatePrompt() async {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            
            let alert = NSAlert()
            alert.icon = NSImage(size: .zero)
            alert.messageText = "Truncate \(objectTypeDisplayName())"
            alert.alertStyle = .warning
            alert.informativeText = ""
            applyAppearance(to: alert)
            
            let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            
            let message = NSMutableAttributedString()
            message.append(NSAttributedString(string: "Are you sure you want to truncate the \(objectTypeDisplayName().lowercased()) ", attributes: [
                .font: baseFont
            ]))
            message.append(NSAttributedString(string: object.fullName, attributes: [
                .font: boldFont
            ]))
            message.append(NSAttributedString(string: "?\nThis action cannot be undone.", attributes: [
                .font: baseFont
            ]))
            
            let messageLabel = NSTextField(labelWithAttributedString: message)
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            messageLabel.lineBreakMode = .byWordWrapping
            messageLabel.maximumNumberOfLines = 0
            messageLabel.preferredMaxLayoutWidth = 320
            messageLabel.alignment = .left
            
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.spacing = 6
            stack.alignment = .leading
            stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
            stack.addArrangedSubview(messageLabel)
            stack.setHuggingPriority(.required, for: .vertical)
            stack.setHuggingPriority(.required, for: .horizontal)
            
            alert.accessoryView = stack
            
            let truncateButton = alert.addButton(withTitle: "Truncate")
            if #available(macOS 11.0, *) {
                truncateButton.hasDestructiveAction = true
            }
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }
            
            let statement = truncateStatement()
            
            appModel.sessionManager.setActiveSession(session.id)
            appModel.selectedConnectionID = session.connection.id
            
            Task {
                do {
                    _ = try await appModel.executeUpdate(statement)
                    await appModel.refreshDatabaseStructure(
                        for: session.id,
                        scope: .selectedDatabase,
                        databaseOverride: session.selectedDatabaseName
                    )
                } catch {
                    await MainActor.run {
                        appModel.lastError = DatabaseError.from(error)
                    }
                }
            }
        }
#endif
        
        private func openScriptTab(with sql: String) {
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            Task { @MainActor in
                appModel.openQueryTab(for: session, presetQuery: sql)
            }
        }
        
        private func makeCreateTableScript(details: TableStructureDetails) -> String {
            let qualifiedTable = qualifiedName(schema: object.schema, name: object.name)
            
            var definitionLines = details.columns.map(columnDefinition)
            
            if let primaryKey = details.primaryKey {
                definitionLines.append(primaryKeyDefinition(primaryKey))
            }
            
            definitionLines.append(contentsOf: details.uniqueConstraints.map(uniqueConstraintDefinition))
            definitionLines.append(contentsOf: details.foreignKeys.map(foreignKeyDefinition))
            
            let body: String
            if definitionLines.isEmpty {
                body = ""
            } else {
                body = definitionLines.joined(separator: ",\n    ")
            }
            
            var script = "CREATE TABLE \(qualifiedTable)"
            if body.isEmpty {
                script += " (\n);\n"
            } else {
                script += " (\n    \(body)\n);"
            }
            
            let indexStatements = details.indexes
                .compactMap { indexStatement(for: $0, tableName: qualifiedTable) }
            
            if !indexStatements.isEmpty {
                script += "\n\n" + indexStatements.joined(separator: "\n")
            }
            
            return script
        }
        
        private func columnDefinition(_ column: TableStructureDetails.Column) -> String {
            var parts: [String] = [
                "\(quoteIdentifier(column.name)) \(column.dataType)"
            ]
            
            if let generated = generatedClause(for: column.generatedExpression) {
                parts.append(generated)
            }
            
            if let defaultClause = defaultClause(for: column.defaultValue) {
                parts.append(defaultClause)
            }
            
            if !column.isNullable {
                parts.append("NOT NULL")
            }
            
            return parts.joined(separator: " ")
        }
        
        private func defaultClause(for value: String?) -> String? {
            guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                return nil
            }
            if raw.uppercased().hasPrefix("DEFAULT") {
                return raw
            }
            return "DEFAULT \(raw)"
        }
        
        private func generatedClause(for expression: String?) -> String? {
            guard let raw = expression?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                return nil
            }
            if raw.uppercased().hasPrefix("GENERATED") {
                return raw
            }
            return "GENERATED ALWAYS AS (\(raw))"
        }
        
        private func primaryKeyDefinition(_ primaryKey: TableStructureDetails.PrimaryKey) -> String {
            let columns = primaryKey.columns
                .map { quoteIdentifier($0) }
                .joined(separator: ", ")
            return "CONSTRAINT \(quoteIdentifier(primaryKey.name)) PRIMARY KEY (\(columns))"
        }
        
        private func uniqueConstraintDefinition(_ constraint: TableStructureDetails.UniqueConstraint) -> String {
            let columns = constraint.columns
                .map { quoteIdentifier($0) }
                .joined(separator: ", ")
            return "CONSTRAINT \(quoteIdentifier(constraint.name)) UNIQUE (\(columns))"
        }
        
        private func foreignKeyDefinition(_ foreignKey: TableStructureDetails.ForeignKey) -> String {
            let columns = foreignKey.columns
                .map { quoteIdentifier($0) }
                .joined(separator: ", ")
            let referencedColumns = foreignKey.referencedColumns
                .map { quoteIdentifier($0) }
                .joined(separator: ", ")
            let referencedTable = qualifiedName(
                schema: foreignKey.referencedSchema,
                name: foreignKey.referencedTable
            )
            
            var clause = "CONSTRAINT \(quoteIdentifier(foreignKey.name)) FOREIGN KEY (\(columns)) REFERENCES \(referencedTable) (\(referencedColumns))"
            
            if let onUpdate = foreignKey.onUpdate?.trimmingCharacters(in: .whitespacesAndNewlines),
               !onUpdate.isEmpty {
                clause += " ON UPDATE \(onUpdate)"
            }
            if let onDelete = foreignKey.onDelete?.trimmingCharacters(in: .whitespacesAndNewlines),
               !onDelete.isEmpty {
                clause += " ON DELETE \(onDelete)"
            }
            
            return clause
        }
        
        private func indexStatement(for index: TableStructureDetails.Index, tableName: String) -> String? {
            let sortedColumns = index.columns.sorted { $0.position < $1.position }
            guard !sortedColumns.isEmpty else { return nil }
            
            let columnClauses = sortedColumns.map { column in
                let sortKeyword = column.sortOrder == .descending ? "DESC" : "ASC"
                return "\(quoteIdentifier(column.name)) \(sortKeyword)"
            }.joined(separator: ", ")
            
            var statement = "CREATE "
            if index.isUnique {
                statement += "UNIQUE "
            }
            statement += "INDEX \(quoteIdentifier(index.name)) ON \(tableName) (\(columnClauses))"
            
            if let filter = index.filterCondition?.trimmingCharacters(in: .whitespacesAndNewlines),
               !filter.isEmpty {
                if filter.uppercased().hasPrefix("WHERE") {
                    statement += " \(filter)"
                } else {
                    statement += " WHERE \(filter)"
                }
            }
            
            statement += ";"
            return statement
        }
        
        private func selectStatement(limit: Int?, offset: Int = 0) -> String {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let columns = object.columns.isEmpty ? ["*"] : object.columns.map { quoteIdentifier($0.name) }
            let columnLines = columns.joined(separator: ",\n    ")
            
            switch connection.databaseType {
            case .microsoftSQL:
                var statement = "SELECT\n    \(columnLines)\nFROM \(qualified)"
                if let limit {
                    statement += "\nORDER BY (SELECT NULL)\nOFFSET \(offset) ROWS\nFETCH NEXT \(limit) ROWS ONLY"
                }
                statement += ";"
                return statement
            case .postgresql, .mysql, .sqlite:
                var statement = "SELECT\n    \(columnLines)\nFROM \(qualified)"
                if let limit {
                    statement += "\nLIMIT \(limit)"
                    if offset > 0 {
                        statement += "\nOFFSET \(offset)"
                    }
                } else if offset > 0 {
                    statement += "\nOFFSET \(offset)"
                }
                statement += ";"
                return statement
            }
        }
        
        private func executeStatement() -> String {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            switch connection.databaseType {
            case .postgresql:
                if object.type == .procedure {
                    return "CALL \(qualified)(/* arguments */);"
                } else {
                    return "SELECT * FROM \(qualified)(/* arguments */);"
                }
            case .mysql:
                if object.type == .procedure {
                    return "CALL \(qualified)(/* arguments */);"
                } else {
                    return "SELECT \(qualified)(/* arguments */);"
                }
            case .microsoftSQL:
                if object.type == .function {
                    return "SELECT * FROM \(qualified)(/* arguments */);"
                } else {
                    return "EXEC \(qualified) /* arguments */;"
                }
            case .sqlite:
                return "-- Programmable object execution is not supported in SQLite."
            }
        }
        
        private func truncateStatement() -> String {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            switch connection.databaseType {
            case .postgresql, .mysql, .microsoftSQL:
                return "TRUNCATE TABLE \(qualified);"
            case .sqlite:
                return "-- TRUNCATE TABLE is not supported in SQLite."
            }
        }
        
        private func renameStatement(newName: String? = nil) -> String? {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = "<new_name>"
            let effectiveName = (trimmedName?.isEmpty ?? true) ? fallbackName : trimmedName!
            let quotedNewName = quoteIdentifier(effectiveName)
            
            switch connection.databaseType {
            case .postgresql:
                switch object.type {
                case .table:
                    return "ALTER TABLE \(qualified) RENAME TO \(quotedNewName);"
                case .view:
                    return "ALTER VIEW \(qualified) RENAME TO \(quotedNewName);"
                case .materializedView:
                    return "ALTER MATERIALIZED VIEW \(qualified) RENAME TO \(quotedNewName);"
                case .function:
                    return trimmedName == nil
                    ? "ALTER FUNCTION \(qualified)(/* arg_types */) RENAME TO \(quotedNewName);"
                    : nil
                case .procedure:
                    return trimmedName == nil
                    ? "ALTER PROCEDURE \(qualified)(/* arg_types */) RENAME TO \(quotedNewName);"
                    : nil
                case .trigger:
                    return "ALTER TRIGGER \(quoteIdentifier(object.name)) ON \(triggerTargetName()) RENAME TO \(quotedNewName);"
                }
                
            case .mysql:
                switch object.type {
                case .table, .view:
                    let destination = qualifiedDestinationName(effectiveName)
                    return "RENAME TABLE \(qualified) TO \(destination);"
                case .trigger:
                    return "RENAME TRIGGER \(qualified) TO \(quotedNewName);"
                case .function:
                    return trimmedName == nil
                    ? """
                -- MySQL cannot rename functions directly.
                -- Drop and recreate the function with the desired name.
                """
                    : nil
                case .procedure:
                    return trimmedName == nil
                    ? """
                -- MySQL cannot rename procedures directly.
                -- Drop and recreate the procedure with the desired name.
                """
                    : nil
                case .materializedView:
                    return "-- Materialized views are not supported in MySQL."
                }
                
            case .sqlite:
                switch object.type {
                case .table:
                    return "ALTER TABLE \(qualified) RENAME TO \(quotedNewName);"
                case .view:
                    return """
                -- SQLite cannot rename views directly.
                -- Drop and recreate the view with the desired name.
                """
                case .trigger, .function, .procedure, .materializedView:
                    return "-- Renaming is not supported for this object in SQLite."
                }
                
            case .microsoftSQL:
                let escaped = effectiveName.replacingOccurrences(of: "'", with: "''")
                return "EXEC sp_rename '\(qualifiedForStoredProcedures())', '\(escaped)';"
            }
        }
        
        private func dropStatement(includeIfExists: Bool) -> String {
            let keyword = objectTypeKeyword()
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let ifExists = includeIfExists ? dropIfExistsClause() : ""
            
            switch connection.databaseType {
            case .postgresql:
                switch object.type {
                case .trigger:
                    return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(quoteIdentifier(object.name)) ON \(triggerTargetName());"
                case .function, .procedure:
                    return "DROP FUNCTION \(includeIfExists ? "IF EXISTS " : "")\(qualified)(/* arg_types */);"
                default:
                    return "DROP \(keyword) \(ifExists)\(qualified);"
                }
            case .mysql:
                switch object.type {
                case .trigger:
                    return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(qualified);"
                default:
                    return "DROP \(keyword) \(includeIfExists ? "IF EXISTS " : "")\(qualified);"
                }
            case .sqlite:
                return "DROP \(keyword) \(ifExists)\(qualified);"
            case .microsoftSQL:
                switch object.type {
                case .trigger:
                    return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(qualified) ON \(triggerTargetName());"
                default:
                    return "DROP \(keyword) \(ifExists)\(qualified);"
                }
            }
        }
        
        private func dropIfExistsClause() -> String {
            switch connection.databaseType {
            case .postgresql, .mysql, .microsoftSQL, .sqlite:
                return "IF EXISTS "
            }
        }
        
        private func qualifiedDestinationName(_ newName: String) -> String {
            let schema = object.schema.trimmingCharacters(in: .whitespacesAndNewlines)
            let quotedNewName = quoteIdentifier(newName)
            guard !schema.isEmpty, connection.databaseType != .sqlite else {
                return quotedNewName
            }
            return "\(quoteIdentifier(schema)).\(quotedNewName)"
        }
        
        private func objectTypeKeyword() -> String {
            switch object.type {
            case .table:
                return "TABLE"
            case .view:
                return "VIEW"
            case .materializedView:
                return "MATERIALIZED VIEW"
            case .function:
                return "FUNCTION"
            case .procedure:
                return "PROCEDURE"
            case .trigger:
                return "TRIGGER"
            }
        }

        private func objectTypeDisplayName() -> String {
            switch object.type {
            case .table:
                return "Table"
            case .view:
                return "View"
            case .materializedView:
                return "Materialized View"
            case .function:
                return "Function"
            case .procedure:
                return "Procedure"
            case .trigger:
                return "Trigger"
            }
        }
        
        @MainActor
        private func applyAppearance(to alert: NSAlert) {
            let scheme = ThemeManager.shared.effectiveColorScheme
            if scheme == .dark {
                alert.window.appearance = NSAppearance(named: .darkAqua)
            } else {
                alert.window.appearance = NSAppearance(named: .aqua)
            }
        }
        
        private func qualifiedName(schema: String, name: String) -> String {
            let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSchema.isEmpty || connection.databaseType == .sqlite {
                return quoteIdentifier(name)
            }
            return "\(quoteIdentifier(trimmedSchema)).\(quoteIdentifier(name))"
        }
        
        private func qualifiedForStoredProcedures() -> String {
            let trimmedSchema = object.schema.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSchema.isEmpty || connection.databaseType == .sqlite {
                return object.name
            }
            return "\(trimmedSchema).\(object.name)"
        }
        
        private func quoteIdentifier(_ identifier: String) -> String {
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            switch connection.databaseType {
            case .mysql:
                let escaped = trimmed.replacingOccurrences(of: "`", with: "``")
                return "`\(escaped)`"
            case .microsoftSQL:
                let escaped = trimmed.replacingOccurrences(of: "]", with: "]]")
                return "[\(escaped)]"
            default:
                let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
        }
        
        private func triggerTargetName() -> String {
            guard let triggerTable = object.triggerTable, !triggerTable.isEmpty else {
                return qualifiedName(schema: object.schema, name: "<table_name>")
            }
            if triggerTable.contains(".") {
                let parts = triggerTable.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    return qualifiedName(schema: String(parts[0]), name: String(parts[1]))
                }
            }
            return qualifiedName(schema: object.schema, name: triggerTable)
        }
    }
}

private struct SnapshotInput: Equatable {
    let database: DatabaseInfo
    let normalizedQuery: String?
    let selectedSchemaName: String?
    let pinnedIDs: Set<String>
    let supportedTypes: [SchemaObjectInfo.ObjectType]
}

private struct SnapshotData: Equatable {
    static let empty = SnapshotData(grouped: [:], pinned: [], filteredCount: 0)
    let grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]]
    let pinned: [SchemaObjectInfo]
    let filteredCount: Int
}

private struct ExplorerSnapshotCache {
    private(set) var data: SnapshotData = .empty
    private var lastInput: SnapshotInput?
    
    mutating func update(with input: SnapshotInput) {
        if let last = lastInput, last == input {
            return
        }
        lastInput = input
        let newData = ExplorerSnapshotCache.buildData(from: input)
        if newData != data {
            data = newData
        }
    }
    
    private static func buildData(from input: SnapshotInput) -> SnapshotData {
        let supportedSet = Set(input.supportedTypes)
        let pinnedIDs = input.pinnedIDs
        let normalizedQuery = input.normalizedQuery
        
        let schemas: [SchemaInfo]
        if let selected = input.selectedSchemaName, !selected.isEmpty {
            schemas = input.database.schemas.filter { $0.name == selected }
        } else {
            schemas = input.database.schemas
        }
        
        var grouped: [SchemaObjectInfo.ObjectType: [SchemaObjectInfo]] = [:]
        var pinnedList: [SchemaObjectInfo] = []
        var filteredCount = 0
        
        for schema in schemas {
            for object in schema.objects {
                guard supportedSet.contains(object.type) else { continue }
                if let query = normalizedQuery, !query.isEmpty, !objectMatchesQuery(object, normalizedQuery: query) {
                    continue
                }
                grouped[object.type, default: []].append(object)
                filteredCount += 1
                if pinnedIDs.contains(object.id) {
                    pinnedList.append(object)
                }
            }
        }
        
        for type in grouped.keys {
            grouped[type]?.sort { lhs, rhs in
                lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
            }
        }
        
        pinnedList.sort { lhs, rhs in
            lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
        
        return SnapshotData(grouped: grouped, pinned: pinnedList, filteredCount: filteredCount)
    }
    
    private static func objectMatchesQuery(_ object: SchemaObjectInfo, normalizedQuery: String) -> Bool {
        let query = normalizedQuery
        if object.name.lowercased().contains(query) { return true }
        if object.schema.lowercased().contains(query) { return true }
        return object.fullName.lowercased().contains(query)
    }
}
