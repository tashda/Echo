import SwiftUI

/// Database Explorer – hierarchical object list rendered in the explorer sidebar.
struct DatabaseObjectBrowserView: View {
    let database: DatabaseInfo
    let connection: SavedConnection
    @Binding var searchText: String
    @Binding var selectedSchemaName: String?
    @Binding var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType>
    @Binding var expandedObjectIDs: Set<String>
    let coordinateSpaceName: String
    let scrollTo: (String, UnitPoint) -> Void

    @EnvironmentObject private var appModel: AppModel

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedSearchText.isEmpty }

    private var totalFilteredObjectCount: Int {
        SchemaObjectInfo.ObjectType.allCases.reduce(into: 0) { result, type in
            result += objects(for: type).count
        }
    }

    private var filteredSchemas: [SchemaInfo] {
        if let selectedSchemaName {
            return database.schemas.filter { $0.name == selectedSchemaName }
        }
        return database.schemas
    }

    private func objects(for type: SchemaObjectInfo.ObjectType) -> [SchemaObjectInfo] {
        filteredSchemas
            .flatMap { schema in
                schema.objects.filter { object in
                    object.type == type && matchesSearch(object)
                }
            }
            .sorted { lhs, rhs in
                lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
            }
    }

    private func matchesSearch(_ object: SchemaObjectInfo) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return object.name.localizedCaseInsensitiveContains(query) ||
            object.schema.localizedCaseInsensitiveContains(query) ||
            object.fullName.localizedCaseInsensitiveContains(query)
    }

    private func displayName(for object: SchemaObjectInfo) -> String {
        if selectedSchemaName == nil {
            return object.fullName
        }
        return object.name
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
        if isSearching && totalFilteredObjectCount == 0 {
            SearchEmptyStateView(query: searchText)
        } else {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(SchemaObjectInfo.ObjectType.allCases, id: \.self) { objectType in
                    let objects = objects(for: objectType)

                    Section {
                        if expandedObjectGroups.contains(objectType) {
                            ForEach(objects, id: \.id) { object in
                                DatabaseObjectRow(
                                    object: object,
                                    displayName: displayName(for: object),
                                    connection: connection,
                                    showColumns: object.type == .table || object.type == .view || object.type == .materializedView,
                                    isExpanded: expansionBinding(for: object.id),
                                    onTriggerTableTap: object.type == .trigger ? { tableName in revealTable(fullName: tableName) } : nil
                                )
                                .environmentObject(appModel)
                                .id(object.id)
                            }
                        }
                    } header: {
                        StickyHeader(
                            title: objectType.pluralDisplayName,
                            count: objects.count,
                            isExpanded: expandedObjectGroups.contains(objectType),
                            coordinateSpaceName: coordinateSpaceName
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if expandedObjectGroups.contains(objectType) {
                                    expandedObjectGroups.remove(objectType)
                                } else {
                                    expandedObjectGroups.insert(objectType)
                                }
                            }
                            if !expandedObjectGroups.contains(objectType) {
                                scrollTo("header-\(objectType.rawValue)", .top)
                            }
                        }
                    }
                    .id("header-\(objectType.rawValue)")
                }
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

// MARK: - Sticky Header

private struct StickyHeader: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let coordinateSpaceName: String
    let onToggle: () -> Void

    @State private var isPinned = false

    var body: some View {
        let cornerRadius: CGFloat = isPinned ? 9 : 4

        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background {
            if isPinned && isExpanded {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color.primary.opacity(0.40))
                    .fill(.ultraThickMaterial)
            } else {
                Color.clear
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if isPinned && isExpanded {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
        .shadow(color: (isPinned && isExpanded) ? .black.opacity(0.16) : .clear, radius: 10, x: 0, y: 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .background(
            GeometryReader { proxy in
                let minY = proxy.frame(in: .named(coordinateSpaceName)).minY
                DispatchQueue.main.async {
                    let pinned = minY <= 0.5
                    if pinned != isPinned {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isPinned = pinned
                        }
                    }
                }
                return Color.clear
            }
        )
    }
}

// MARK: - Database Object Row

private struct DatabaseObjectRow: View {
    let object: SchemaObjectInfo
    let displayName: String
    let connection: SavedConnection
    let showColumns: Bool
    @Binding var isExpanded: Bool
    let onTriggerTableTap: ((String) -> Void)?

    @EnvironmentObject private var appModel: AppModel
    @State private var isHovered = false

    private var canExpand: Bool {
        showColumns && !object.columns.isEmpty
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
                    .foregroundStyle(.blue)

                Text(displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if showColumns && !object.columns.isEmpty {
                    Text("\(object.columns.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            }

            if object.type == .trigger {
                triggerMetadata
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(highlightBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canExpand else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu { contextMenuContent }
    }

    @ViewBuilder
    private var triggerMetadata: some View {
        HStack(spacing: 6) {
            if let action = object.triggerAction, !action.isEmpty {
                Text(action)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            if let table = object.triggerTable, !table.isEmpty {
                Button {
                    onTriggerTableTap?(table)
                } label: {
                    Text(table)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, 24)
    }

    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isHovered || isExpanded ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var columnsList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(object.columns, id: \.name) { column in
                HStack(spacing: 8) {
                    Spacer().frame(width: 24)
                    Image(systemName: column.isPrimaryKey ? "key.fill" : "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(column.isPrimaryKey ? .yellow : .secondary)
                    Text(column.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(column.dataType)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .frame(minWidth: 60, alignment: .trailing)
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.bottom, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Query Data") { queryObjectData() }
        Button("View Structure") { viewObjectStructure() }
        if object.type == .table {
            Button("Insert Row") { insertRowIntoTable() }
        }
    }

    private func queryObjectData() {
        let sql = "SELECT * FROM \(object.fullName) LIMIT 100;"
        Task { @MainActor in
            do {
                _ = try await appModel.executeQuery(sql)
            } catch {
                print("Query failed: \(error)")
            }
        }
    }

    private func viewObjectStructure() {
        Task { @MainActor in
            guard let session = appModel.sessionManager.sessionForConnection(connection.id) else { return }
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type
                )
                print(definition)
            } catch {
                print("Structure inspection failed: \(error)")
            }
        }
    }

    private func insertRowIntoTable() {
        guard object.type == .table else { return }
        let columnNames = object.columns.map { "\"\($0.name)\"" }.joined(separator: ", ")
        let values = object.columns.map { _ in "?" }.joined(separator: ", ")
        let sql = "INSERT INTO \(object.fullName) (\(columnNames)) VALUES (\(values));"
        Task { @MainActor in
            do {
                _ = try await appModel.executeUpdate(sql)
            } catch {
                print("Insert failed: \(error)")
            }
        }
    }
}
}
